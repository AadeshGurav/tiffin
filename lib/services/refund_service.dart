import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../data/store.dart';
import '../domain/ledger.dart';
import '../domain/member.dart';
import 'member_service.dart';
import 'settings_service.dart';

/// Refunds (PRD §6.7). Keeps the unit ledger accurate and records what, when
/// and why; the payout itself happens outside the app. The amount comes from
/// the configured prices, never typed in.
class RefundService {
  RefundService(this._store, this._settings);

  final Store _store;
  final SettingsService _settings;
  final _log = log('refund');

  CollectionReference<Json> get _col => _store.col(Col.refunds);

  Future<List<Refund>> list({String? memberId}) async {
    Query<Json> q = _col.orderBy('createdAt', descending: true);
    if (memberId != null) q = q.where('memberId', isEqualTo: memberId);
    return (await _store.fresh(q)).map(Refund.fromJson).toList();
  }

  Future<Refund> create(RefundDraft draft) async {
    if (draft.isAllZero) {
      throw const ValidationException(ErrorCode.refundNeedsUnits);
    }
    final memberRow =
        await _store.cachedDoc(_store.doc(Col.members, draft.memberId));
    if (memberRow == null) {
      throw const NotFoundException(ErrorCode.memberNotFound);
    }
    final balances = Member.fromJson(memberRow).balances;
    _rejectOverRefund('lunch', draft.lunchUnits, balances.lunch);
    _rejectOverRefund('breakfast', draft.breakfastUnits, balances.breakfast);
    _rejectOverRefund('brunch', draft.brunchUnits, balances.brunch);

    final prices = (await _settings.read()).unitPrices;
    final refund = Refund(
      id: _store.newId(Col.refunds),
      memberId: draft.memberId,
      lunchUnits: draft.lunchUnits,
      breakfastUnits: draft.breakfastUnits,
      brunchUnits: draft.brunchUnits,
      refundAmount: draft.lunchUnits * prices.lunch +
          draft.breakfastUnits * prices.breakfast +
          draft.brunchUnits * prices.brunch,
      reason: draft.reason,
      processedBy: draft.processedBy,
      createdAt: DateTime.now().toUtc(),
    );
    final b = _store.batch()
      ..set(_col.doc(refund.id), refund.toJson()..remove('id'))
      ..update(
          _store.doc(Col.members, draft.memberId),
          MemberService.balanceDelta(
              UnitCounts(
                lunch: draft.lunchUnits,
                breakfast: draft.breakfastUnits,
                brunch: draft.brunchUnits,
              ),
              sign: -1));
    await _store.commit(b, 'refunds.create ${refund.id}');
    _log.info('created member_id=${draft.memberId} refund_id=${refund.id} '
        'amount=${refund.refundAmount.toStringAsFixed(2)} '
        'by=${draft.processedBy}');
    return refund;
  }

  void _rejectOverRefund(String meal, int requested, int available) {
    if (requested > available) {
      throw ValidationException(ErrorCode.refundExceedsBalance,
          {'requested': requested, 'meal': meal, 'available': available});
    }
  }
}
