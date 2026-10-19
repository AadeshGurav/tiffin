import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../data/store.dart';
import '../domain/member.dart';
import 'qr_service.dart';

/// Member CRUD, credit and QR reprint (PRD §6.1). Members are kept warm in the
/// local cache, so every read here is instant and works offline.
class MemberService {
  MemberService(this._store, this._qr);

  final Store _store;
  final QrService _qr;
  final _log = log('member');

  static const defaultCategory = 'Normal';

  CollectionReference<Json> get _col => _store.col(Col.members);

  Future<List<Member>> list({String? type, String? status}) async {
    Query<Json> q = _col;
    if (type != null) q = q.where('type', isEqualTo: type);
    if (status != null) q = q.where('status', isEqualTo: status);
    return (await _store.cached(q)).map(Member.fromJson).toList();
  }

  Future<Member> getById(String id) async {
    final row = await _store.cachedDoc(_col.doc(id));
    if (row == null) throw const NotFoundException(ErrorCode.memberNotFound);
    return Member.fromJson(row);
  }

  Future<Member?> getByQrCode(String qrCodeId) async {
    final rows =
        await _store.cached(_col.where('qrCodeId', isEqualTo: qrCodeId));
    return rows.isEmpty ? null : Member.fromJson(rows.first);
  }

  /// The QR id is 12 random hex characters (48 bits); a collision among one
  /// canteen's members is not a realistic event, so there is no retry loop.
  Future<Member> create(MemberDraft draft) async {
    _validateTypeSpecific(
        draft.type, draft.className, draft.rollNumber, draft.staffId);
    final now = DateTime.now().toUtc();
    final member = Member(
      id: _store.newId(Col.members),
      type: draft.type,
      name: draft.name,
      className: draft.className,
      rollNumber: draft.rollNumber,
      staffId: draft.staffId,
      qrCodeId: _qr.generateCodeId(),
      balances: draft.balances,
      graceAllowanceOverride: draft.graceAllowanceOverride,
      status: 'active',
      category: _cleanCategory(draft.category),
      createdAt: now,
      updatedAt: now,
    );
    final b = _store.batch()..set(_col.doc(member.id), _stored(member));
    await _store.commit(b, 'members.create');
    _log.info('created member_id=${member.id} type=${draft.type}');
    return member;
  }

  /// Migrate paper records in one call (PRD §6.1). Each row is independent —
  /// one bad row doesn't fail the rest.
  Future<BulkResult> createBulk(List<MemberDraft> drafts) async {
    final created = <Member>[];
    final failed = <BulkFailure>[];
    for (var i = 0; i < drafts.length; i++) {
      try {
        created.add(await create(drafts[i]));
      } on AppException catch (e) {
        failed.add(BulkFailure(index: i, name: drafts[i].name, error: e));
      }
    }
    _log.info('bulk_created count=${created.length} failed=${failed.length}');
    return BulkResult(created: created, failed: failed);
  }

  Future<Member> update(String id, MemberPatch patch) async {
    final existing = await getById(id);

    // Type is editable (PRD §6.1). When it flips, the fields that don't apply
    // to the new type are cleared so a converted member isn't left carrying a
    // stale staff id or class/roll.
    final newType = patch.type ?? existing.type;
    final className =
        newType == 'staff' ? null : (patch.className ?? existing.className);
    final rollNumber =
        newType == 'staff' ? null : (patch.rollNumber ?? existing.rollNumber);
    final staffId =
        newType == 'student' ? null : (patch.staffId ?? existing.staffId);
    _validateTypeSpecific(newType, className, rollNumber, staffId);

    final changes = <String, dynamic>{
      'type': newType,
      'name': patch.name ?? existing.name,
      'className': className,
      'rollNumber': rollNumber,
      'staffId': staffId,
      if (patch.status != null) 'status': patch.status,
      if (patch.category != null) 'category': _cleanCategory(patch.category!),
      if (patch.touchesGrace) 'graceAllowanceOverride': patch.graceValue,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final b = _store.batch()..update(_col.doc(id), changes);
    await _store.commit(b, 'members.update');
    _log.info('updated member_id=$id');
    return getById(id);
  }

  /// Only for a member with no history — otherwise it would orphan scan /
  /// top-up / refund rows (PRD §6.1). Asks the server, because history isn't
  /// all kept in the cache; offline it falls back to what the cache knows.
  Future<void> delete(String id) async {
    await getById(id);
    for (final c in const [Col.scans, Col.topups, Col.refunds]) {
      final rows = await _store
          .fresh(_store.col(c).where('memberId', isEqualTo: id).limit(1));
      if (rows.isNotEmpty) {
        throw const ConflictException(ErrorCode.memberHasHistory);
      }
    }
    await _store.commit(_store.batch()..delete(_col.doc(id)), 'members.delete');
    _log.warning('deleted member_id=$id');
  }

  /// Admin credit primitive — add units, no bill (PRD §6.1). Increments, so
  /// credits made on two offline phones both land.
  Future<Member> credit(String id, UnitCounts units) async {
    await getById(id);
    final b = _store.batch()..update(_col.doc(id), balanceDelta(units));
    await _store.commit(b, 'members.credit');
    _log.info('credited member_id=$id lunch=+${units.lunch} '
        'breakfast=+${units.breakfast} brunch=+${units.brunch}');
    return getById(id);
  }

  Future<List<int>> renderQr(String id) async =>
      _qr.renderPng((await getById(id)).qrCodeId);

  /// Field updates that add [units] to a member's balances. Shared by
  /// top-ups, refunds and scans so there is one spelling of "change a
  /// balance", and it is always an increment.
  static Map<String, dynamic> balanceDelta(UnitCounts units, {int sign = 1}) =>
      {
        if (units.lunch != 0)
          'balances.lunch': FieldValue.increment(sign * units.lunch),
        if (units.breakfast != 0)
          'balances.breakfast': FieldValue.increment(sign * units.breakfast),
        if (units.brunch != 0)
          'balances.brunch': FieldValue.increment(sign * units.brunch),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

  static Json _stored(Member m) => m.toJson()..remove('id');

  void _validateTypeSpecific(
    String type,
    String? className,
    String? rollNumber,
    String? staffId,
  ) {
    if (type != 'student' && type != 'staff') {
      throw ValidationException(ErrorCode.memberUnknownType, {'type': type});
    }
    if (type == 'student' && (staffId?.isNotEmpty ?? false)) {
      throw const ValidationException(ErrorCode.memberStudentHasStaffId);
    }
    if (type == 'staff' &&
        ((className?.isNotEmpty ?? false) ||
            (rollNumber?.isNotEmpty ?? false))) {
      throw const ValidationException(ErrorCode.memberStaffHasClass);
    }
  }

  /// A blank category falls back to the default so a scan always counts
  /// against some group.
  String _cleanCategory(String c) =>
      c.trim().isEmpty ? defaultCategory : c.trim();
}

/// Result of a partial-success bulk operation.
class BulkResult {
  const BulkResult({required this.created, required this.failed});

  final List<Member> created;
  final List<BulkFailure> failed;
}

class BulkFailure {
  const BulkFailure(
      {required this.index, required this.name, required this.error});

  final int index;
  final String name;
  final AppException error;
}
