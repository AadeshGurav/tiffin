import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors.dart';
import '../../core/logging.dart';
import '../../data/store.dart';
import '../../domain/ledger.dart';
import '../../domain/member.dart';
import 'billing_service.dart';
import '../people/member_service.dart';
import '../scanning/qr_service.dart';
import '../system/settings_service.dart';

/// Top-ups & billing (PRD §6.3). The amount is always computed from the
/// configured unit prices, never typed in. The UPI QR is rendered on demand
/// from the stored record rather than kept as a file, so any phone can show it.
class TopupService {
  TopupService(this._store, this._settings, this._billing, this._qr);

  final Store _store;
  final SettingsService _settings;
  final BillingService _billing;
  final QrService _qr;
  final _log = log('topup');

  CollectionReference<Json> get _col => _store.col(Col.topups);

  Future<List<Topup>> list({String? memberId, int limit = 200}) async {
    Query<Json> q =
        _col.orderBy('createdAt', descending: true).limit(limit.clamp(1, 1000));
    if (memberId != null) q = q.where('memberId', isEqualTo: memberId);
    return (await _store.fresh(q)).map(Topup.fromJson).toList();
  }

  Future<Topup> getById(String id) async {
    final row = await _store.cachedDoc(_col.doc(id)) ??
        await _store.freshDoc(_col.doc(id));
    if (row == null) throw const NotFoundException(ErrorCode.topupNotFound);
    return Topup.fromJson(row);
  }

  Future<Topup> create(TopupDraft draft) async {
    final units = draft.units;
    // A negative top-up would debit units while billing a negative amount.
    if (units.byMeal.values.any((n) => n < 0)) {
      throw const ValidationException(ErrorCode.negativeUnits);
    }
    if (draft.isAllZero) {
      throw const ValidationException(ErrorCode.topupNeedsUnits);
    }
    final memberRow =
        await _store.cachedDoc(_store.doc(Col.members, draft.memberId));
    if (memberRow == null) {
      throw const NotFoundException(ErrorCode.memberNotFound);
    }
    final member = Member.fromJson(memberRow);

    final settings = await _settings.read();
    // Only meals on sale can be bought; a retired one is refunded, not sold.
    for (final id in units.anytime.keys) {
      if (settings.anytimeMeal(id)?.active != true) {
        throw ValidationException(ErrorCode.unknownMeal, {'meal': id});
      }
    }
    final amount = units.byMeal.entries
        .fold(0.0, (total, e) => total + e.value * settings.priceOf(e.key));

    final topup = Topup(
      id: _store.newId(Col.topups),
      memberId: draft.memberId,
      lunchUnits: draft.lunchUnits,
      breakfastUnits: draft.breakfastUnits,
      brunchUnits: draft.brunchUnits,
      anytimeUnits: {
        for (final e in units.anytime.entries)
          if (e.value != 0) e.key: e.value,
      },
      amount: amount,
      paymentMethod: draft.paymentMethod,
      // Cash settles now; UPI is pending until the admin confirms receipt.
      paymentStatus:
          draft.paymentMethod == PaymentMethod.cash ? 'confirmed' : 'pending',
      hasBill: true,
      hasUpiQr:
          draft.paymentMethod == PaymentMethod.upi && settings.upiId.isNotEmpty,
      createdBy: draft.createdBy,
      createdAt: DateTime.now().toUtc(),
      balancesAfter: member.balances + units,
    );

    final b = _store.batch()
      ..set(_col.doc(topup.id), topup.toJson()..remove('id'))
      ..update(_store.doc(Col.members, member.id),
          MemberService.balanceDelta(units));
    await _store.commit(b, 'topups.create ${topup.id}');
    _log.info('credited member_id=${member.id} topup_id=${topup.id} '
        'amount=${amount.toStringAsFixed(2)} '
        'method=${draft.paymentMethod.wire} by=${draft.createdBy}');
    return topup;
  }

  Future<void> confirmPayment(String topupId) async {
    await getById(topupId);
    await _store.commit(
        _store.batch()
          ..update(_col.doc(topupId), {'paymentStatus': 'confirmed'}),
        'topups.confirm');
    _log.info('payment_confirmed topup_id=$topupId');
  }

  /// Takes back the units a top-up credited and flags the record — kept for
  /// audit, never deleted (PRD §6.3). Refuses when some of those units are
  /// already spent: that's a refund, not a reversal.
  Future<ReversalResult> reverse(String topupId, String reversedBy) async {
    final Topup topup;
    try {
      topup = await getById(topupId);
    } on NotFoundException {
      return const ReversalResult(ReversalCode.topupNotFound);
    }
    if (topup.reversed) {
      return const ReversalResult(ReversalCode.topupAlreadyReversed);
    }
    final memberRow =
        await _store.cachedDoc(_store.doc(Col.members, topup.memberId));
    if (memberRow == null) {
      return const ReversalResult(ReversalCode.memberNotFound);
    }
    final balances = Member.fromJson(memberRow).balances;
    if (topup.units.byMeal.entries.any((e) => balances[e.key] < e.value)) {
      return const ReversalResult(ReversalCode.topupUnitsUsed);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final b = _store.batch()
      ..update(_col.doc(topupId), {
        'reversed': true,
        'reversedAt': now,
        'reversedBy': reversedBy,
      })
      ..update(_store.doc(Col.members, topup.memberId),
          MemberService.balanceDelta(topup.units, sign: -1));
    await _store.commit(b, 'topups.reverse $topupId');
    _log.info('reversed topup_id=$topupId by=$reversedBy');
    return const ReversalResult(ReversalCode.topupReversed);
  }

  Future<Uint8List> upiQr(String topupId) async {
    final topup = await getById(topupId);
    final settings = await _settings.read();
    final uri = _billing.upiPaymentUri(
      amount: topup.amount,
      note: 'Canteen topup ${topup.id}',
      upiId: settings.upiId,
      upiPayeeName: settings.upiPayeeName,
    );
    if (uri == null) throw const NotFoundException(ErrorCode.topupNotFound);
    return _qr.renderPng(uri);
  }
}
