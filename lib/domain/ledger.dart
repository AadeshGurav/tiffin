import 'member.dart';

/// Scan, top-up and refund models — the unit ledger (PRD §5–§6). Plain,
/// JSON-serializable, shared by host and client.

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------

/// The outcome the counter operator acts on immediately (PRD §6.4). Mirrors
/// v1's `ScanResult` including the exact `rejected_*` discriminators.
enum ScanOutcome {
  accepted,
  rejectedUnknownCode,
  rejectedInactive,
  rejectedNoMealWindow,
  rejectedAlreadyScanned,
  rejectedZeroBalance;

  static ScanOutcome fromWire(String v) => ScanOutcome.values.firstWhere(
        (o) => o.wire == v,
        orElse: () => throw ArgumentError('Unknown scan outcome: $v'),
      );

  String get wire => switch (this) {
        ScanOutcome.accepted => 'accepted',
        ScanOutcome.rejectedUnknownCode => 'rejected_unknown_code',
        ScanOutcome.rejectedInactive => 'rejected_inactive',
        ScanOutcome.rejectedNoMealWindow => 'rejected_no_meal_window',
        ScanOutcome.rejectedAlreadyScanned => 'rejected_already_scanned',
        ScanOutcome.rejectedZeroBalance => 'rejected_zero_balance',
      };

  bool get isAccepted => this == ScanOutcome.accepted;
}

class ScanResult {
  const ScanResult({
    required this.outcome,
    this.scanId,
    this.memberName,
    this.memberType,
    this.meal,
    this.remainingBalance,
    this.viaGrace = false,
    this.memberCategory,
    this.plannedCount,
    this.servedCount,
  });

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        outcome: ScanOutcome.fromWire(j['outcome'] as String),
        scanId: j['scanId'] as String?,
        memberName: j['memberName'] as String?,
        memberType: j['memberType'] as String?,
        meal: j['mealType'] as String?,
        remainingBalance: j['remainingBalance'] as int?,
        viaGrace: j['viaGrace'] as bool? ?? false,
        memberCategory: j['memberCategory'] as String?,
        plannedCount: j['plannedCount'] as int?,
        servedCount: j['servedCount'] as int?,
      );

  final ScanOutcome outcome;
  final String? scanId;
  final String? memberName;
  final String? memberType;

  /// A meal id (ADR 0009): a built-in's wire name or an anytime meal's id.
  final String? meal;
  final int? remainingBalance;
  final bool viaGrace;

  /// The scanned member's serving group, and the planned vs served plate count
  /// for that group / meal / today. Set only on an accepted scan when a menu
  /// entry with a headcount exists.
  final String? memberCategory;
  final int? plannedCount;
  final int? servedCount;

  /// This scan has met or passed the planned plate count for its category.
  bool get headcountReached =>
      plannedCount != null &&
      plannedCount! > 0 &&
      servedCount != null &&
      servedCount! >= plannedCount!;

  Map<String, dynamic> toJson() => {
        'outcome': outcome.wire,
        'scanId': scanId,
        'memberName': memberName,
        'memberType': memberType,
        'mealType': meal,
        'remainingBalance': remainingBalance,
        'viaGrace': viaGrace,
        'memberCategory': memberCategory,
        'plannedCount': plannedCount,
        'servedCount': servedCount,
      };
}

/// A stored scan row (PRD §8) — backs the admin scan log and reversal.
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.meal,
    required this.scannedAt,
    required this.result,
    required this.viaGrace,
    required this.reversed,
    this.reversedAt,
    this.reversedBy,
    this.memberCategory,
  });

  factory ScanRecord.fromJson(Map<String, dynamic> j) => ScanRecord(
        id: j['id'] as String,
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String,
        meal: j['mealType'] as String,
        scannedAt: DateTime.parse(j['scannedAt'] as String),
        result: j['result'] as String,
        viaGrace: j['viaGrace'] as bool,
        reversed: j['reversed'] as bool,
        reversedAt: j['reversedAt'] == null
            ? null
            : DateTime.parse(j['reversedAt'] as String),
        reversedBy: j['reversedBy'] as String?,
        memberCategory: j['memberCategory'] as String?,
      );

  final String id;
  final String memberId;
  final String memberName;

  /// A meal id (ADR 0009). Unknown ids parse; the label falls back to the id.
  final String meal;
  final DateTime scannedAt;
  final String result;
  final bool viaGrace;
  final bool reversed;
  final DateTime? reversedAt;
  final String? reversedBy;
  final String? memberCategory;

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'mealType': meal,
        'scannedAt': scannedAt.toUtc().toIso8601String(),
        'result': result,
        'viaGrace': viaGrace,
        'reversed': reversed,
        'reversedAt': reversedAt?.toUtc().toIso8601String(),
        'reversedBy': reversedBy,
        'memberCategory': memberCategory,
      };
}

/// Why a reversal did or didn't happen. The UI words it (CLAUDE.md §13).
enum ReversalCode {
  scanReversed,
  scanNotFound,
  scanAlreadyReversed,
  scanWindowExpired,
  topupReversed,
  topupNotFound,
  topupAlreadyReversed,
  topupUnitsUsed,
  memberNotFound,
}

class ReversalResult {
  const ReversalResult(this.code,
      {this.restored, this.meal, this.windowMinutes});

  final ReversalCode code;

  /// Units put back, for [ReversalCode.scanReversed].
  final int? restored;
  final String? meal;

  /// The configured window, for [ReversalCode.scanWindowExpired].
  final int? windowMinutes;

  bool get success =>
      code == ReversalCode.scanReversed || code == ReversalCode.topupReversed;
}

// ---------------------------------------------------------------------------
// Top-up
// ---------------------------------------------------------------------------

/// `{mealId: units}` from a stored `anytimeUnits` map; absent reads as none.
Map<String, int> anytimeUnitsFromJson(Object? j) => {
      for (final e in (j as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    };

enum PaymentMethod {
  cash,
  upi;

  static PaymentMethod fromWire(String v) =>
      PaymentMethod.values.firstWhere((p) => p.name == v,
          orElse: () => throw ArgumentError('Unknown payment method: $v'));
  String get wire => name;
}

/// A top-up request (PRD §6.3). Amount is never in the request — the host
/// computes it from `settings.unitPrices`.
class TopupDraft {
  const TopupDraft({
    required this.memberId,
    this.lunchUnits = 0,
    this.breakfastUnits = 0,
    this.brunchUnits = 0,
    this.anytimeUnits = const {},
    required this.paymentMethod,
    required this.createdBy,
  });

  factory TopupDraft.fromJson(Map<String, dynamic> j) => TopupDraft(
        memberId: j['memberId'] as String,
        lunchUnits: (j['lunchUnits'] as num?)?.toInt() ?? 0,
        breakfastUnits: (j['breakfastUnits'] as num?)?.toInt() ?? 0,
        brunchUnits: (j['brunchUnits'] as num?)?.toInt() ?? 0,
        anytimeUnits: anytimeUnitsFromJson(j['anytimeUnits']),
        paymentMethod: PaymentMethod.fromWire(j['paymentMethod'] as String),
        createdBy: j['createdBy'] as String,
      );

  final String memberId;
  final int lunchUnits;
  final int breakfastUnits;
  final int brunchUnits;

  /// Units of anytime meals, by meal id (ADR 0009 §4).
  final Map<String, int> anytimeUnits;
  final PaymentMethod paymentMethod;
  final String createdBy;

  UnitCounts get units => UnitCounts(
      lunch: lunchUnits,
      breakfast: breakfastUnits,
      brunch: brunchUnits,
      anytime: anytimeUnits);

  bool get isAllZero => units.isAllZero;

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'lunchUnits': lunchUnits,
        'breakfastUnits': breakfastUnits,
        'brunchUnits': brunchUnits,
        if (anytimeUnits.isNotEmpty) 'anytimeUnits': anytimeUnits,
        'paymentMethod': paymentMethod.wire,
        'createdBy': createdBy,
      };
}

class Topup {
  const Topup({
    required this.id,
    required this.memberId,
    required this.lunchUnits,
    required this.breakfastUnits,
    required this.brunchUnits,
    this.anytimeUnits = const {},
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.hasBill = false,
    this.hasUpiQr = false,
    required this.createdBy,
    required this.createdAt,
    this.reversed = false,
    this.reversedAt,
    this.reversedBy,
    this.balancesAfter,
  });

  factory Topup.fromJson(Map<String, dynamic> j) => Topup(
        id: j['id'] as String,
        memberId: j['memberId'] as String,
        lunchUnits: j['lunchUnits'] as int,
        breakfastUnits: j['breakfastUnits'] as int,
        brunchUnits: j['brunchUnits'] as int,
        anytimeUnits: anytimeUnitsFromJson(j['anytimeUnits']),
        amount: (j['amount'] as num).toDouble(),
        paymentMethod: PaymentMethod.fromWire(j['paymentMethod'] as String),
        paymentStatus: j['paymentStatus'] as String,
        hasBill: j['hasBill'] as bool? ?? false,
        hasUpiQr: j['hasUpiQr'] as bool? ?? false,
        createdBy: j['createdBy'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        reversed: j['reversed'] as bool? ?? false,
        reversedAt: j['reversedAt'] == null
            ? null
            : DateTime.parse(j['reversedAt'] as String),
        reversedBy: j['reversedBy'] as String?,
        balancesAfter: j['balancesAfter'] == null
            ? null
            : UnitCounts.fromJson(j['balancesAfter'] as Map<String, dynamic>),
      );

  final String id;
  final String memberId;
  final int lunchUnits;
  final int breakfastUnits;
  final int brunchUnits;

  /// Units of anytime meals, by meal id; absent on pre-0009 records.
  final Map<String, int> anytimeUnits;
  final double amount;
  final PaymentMethod paymentMethod;
  final String paymentStatus; // 'pending' | 'confirmed'
  final bool hasBill;
  final bool hasUpiQr;
  final String createdBy;
  final DateTime createdAt;
  final bool reversed;
  final DateTime? reversedAt;
  final String? reversedBy;

  /// The member's balances right after this top-up — printed on the bill.
  final UnitCounts? balancesAfter;

  UnitCounts get units => UnitCounts(
      lunch: lunchUnits,
      breakfast: breakfastUnits,
      brunch: brunchUnits,
      anytime: anytimeUnits);

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        // The flat built-in fields stay: older builds read them as non-null
        // ints, so a Tea-only top-up still parses there (ADR 0009 §4).
        'lunchUnits': lunchUnits,
        'breakfastUnits': breakfastUnits,
        'brunchUnits': brunchUnits,
        if (anytimeUnits.isNotEmpty) 'anytimeUnits': anytimeUnits,
        'amount': amount,
        'paymentMethod': paymentMethod.wire,
        'paymentStatus': paymentStatus,
        'hasBill': hasBill,
        'hasUpiQr': hasUpiQr,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'reversed': reversed,
        'reversedAt': reversedAt?.toUtc().toIso8601String(),
        'reversedBy': reversedBy,
        'balancesAfter': balancesAfter?.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Refund
// ---------------------------------------------------------------------------

class RefundDraft {
  const RefundDraft({
    required this.memberId,
    this.lunchUnits = 0,
    this.breakfastUnits = 0,
    this.brunchUnits = 0,
    this.anytimeUnits = const {},
    this.reason,
    required this.processedBy,
  });

  factory RefundDraft.fromJson(Map<String, dynamic> j) => RefundDraft(
        memberId: j['memberId'] as String,
        lunchUnits: (j['lunchUnits'] as num?)?.toInt() ?? 0,
        breakfastUnits: (j['breakfastUnits'] as num?)?.toInt() ?? 0,
        brunchUnits: (j['brunchUnits'] as num?)?.toInt() ?? 0,
        anytimeUnits: anytimeUnitsFromJson(j['anytimeUnits']),
        reason: j['reason'] as String?,
        processedBy: j['processedBy'] as String,
      );

  final String memberId;
  final int lunchUnits;
  final int breakfastUnits;
  final int brunchUnits;

  /// Units of anytime meals, by meal id (ADR 0009 §4).
  final Map<String, int> anytimeUnits;
  final String? reason;
  final String processedBy;

  UnitCounts get units => UnitCounts(
      lunch: lunchUnits,
      breakfast: breakfastUnits,
      brunch: brunchUnits,
      anytime: anytimeUnits);

  bool get isAllZero => units.isAllZero;

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'lunchUnits': lunchUnits,
        'breakfastUnits': breakfastUnits,
        'brunchUnits': brunchUnits,
        if (anytimeUnits.isNotEmpty) 'anytimeUnits': anytimeUnits,
        'reason': reason,
        'processedBy': processedBy,
      };
}

class Refund {
  const Refund({
    required this.id,
    required this.memberId,
    required this.lunchUnits,
    required this.breakfastUnits,
    required this.brunchUnits,
    this.anytimeUnits = const {},
    required this.refundAmount,
    this.reason,
    required this.processedBy,
    required this.createdAt,
  });

  factory Refund.fromJson(Map<String, dynamic> j) => Refund(
        id: j['id'] as String,
        memberId: j['memberId'] as String,
        lunchUnits: j['lunchUnits'] as int,
        breakfastUnits: j['breakfastUnits'] as int,
        brunchUnits: j['brunchUnits'] as int,
        anytimeUnits: anytimeUnitsFromJson(j['anytimeUnits']),
        refundAmount: (j['refundAmount'] as num).toDouble(),
        reason: j['reason'] as String?,
        processedBy: j['processedBy'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  final String id;
  final String memberId;
  final int lunchUnits;
  final int breakfastUnits;
  final int brunchUnits;

  /// Units of anytime meals, by meal id; absent on pre-0009 records.
  final Map<String, int> anytimeUnits;
  final double refundAmount;
  final String? reason;
  final String processedBy;
  final DateTime createdAt;

  UnitCounts get units => UnitCounts(
      lunch: lunchUnits,
      breakfast: breakfastUnits,
      brunch: brunchUnits,
      anytime: anytimeUnits);

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        // Flat built-in fields kept for older builds, as on top-ups.
        'lunchUnits': lunchUnits,
        'breakfastUnits': breakfastUnits,
        'brunchUnits': brunchUnits,
        if (anytimeUnits.isNotEmpty) 'anytimeUnits': anytimeUnits,
        'refundAmount': refundAmount,
        'reason': reason,
        'processedBy': processedBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
