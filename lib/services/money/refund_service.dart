import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors.dart';
import '../../core/logging.dart';
import '../../data/store.dart';
import '../../domain/ledger.dart';
import '../../domain/member.dart';
import '../people/member_service.dart';
import '../system/settings_service.dart';

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
    final units = draft.units;
    // A negative refund would credit units (and record a negative payout).
    if (units.byMeal.values.any((n) => n < 0)) {
      throw const ValidationException(ErrorCode.negativeUnits);
    }
    if (draft.isAllZero) {
      throw const ValidationException(ErrorCode.refundNeedsUnits);
    }
    final memberRow =
        await _store.cachedDoc(_store.doc(Col.members, draft.memberId));
    if (memberRow == null) {
      throw const NotFoundException(ErrorCode.memberNotFound);
    }
    final balances = Member.fromJson(memberRow).balances;
    final settings = await _settings.read();
    // A retired meal is still refundable: that is what retiring keeps open.
    for (final id in units.anytime.keys) {
      if (settings.anytimeMeal(id) == null) {
        throw ValidationException(ErrorCode.unknownMeal, {'meal': id});
      }
    }
    for (final e in units.byMeal.entries) {
      _rejectOverRefund(
          e.key, e.value, balances[e.key], settings.anytimeMeal(e.key)?.name);
    }

    final refund = Refund(
      id: _store.newId(Col.refunds),
      memberId: draft.memberId,
      lunchUnits: draft.lunchUnits,
      breakfastUnits: draft.breakfastUnits,
      brunchUnits: draft.brunchUnits,
      anytimeUnits: {
        for (final e in units.anytime.entries)
          if (e.value != 0) e.key: e.value,
      },
      refundAmount: units.byMeal.entries
          .fold(0.0, (total, e) => total + e.value * settings.priceOf(e.key)),
      reason: draft.reason,
      processedBy: draft.processedBy,
      createdAt: DateTime.now().toUtc(),
    );
    final b = _store.batch()
      ..set(_col.doc(refund.id), refund.toJson()..remove('id'))
      ..update(_store.doc(Col.members, draft.memberId),
          MemberService.balanceDelta(units, sign: -1));
    await _store.commit(b, 'refunds.create ${refund.id}');
    _log.info('created member_id=${draft.memberId} refund_id=${refund.id} '
        'amount=${refund.refundAmount.toStringAsFixed(2)} '
        'by=${draft.processedBy}');
    return refund;
  }

  /// Only meals actually being refunded are checked: a meal running on grace
  /// (below zero) must not block refunding another one.
  /// [mealName] names an anytime meal in the message (the phone showing it
  /// may not have the catalogue at hand).
  void _rejectOverRefund(
      String meal, int requested, int available, String? mealName) {
    if (requested > 0 && requested > available) {
      throw ValidationException(ErrorCode.refundExceedsBalance, {
        'requested': requested,
        'meal': meal,
        'available': available,
        if (mealName != null) 'mealName': mealName,
      });
    }
  }
}
