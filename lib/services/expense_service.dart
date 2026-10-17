import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../data/store.dart';
import '../domain/ops.dart';
import 'scan_service.dart' show ymd;

/// Expense logging + a revenue-vs-expense summary (PRD §6.6). Revenue is
/// confirmed top-ups in range.
///
/// ponytail: summary sums documents client-side. Fine at one canteen's scale;
/// switch to Firestore aggregate queries if a year's top-ups reach ~10k.
class ExpenseService {
  ExpenseService(this._store);

  final Store _store;
  final _log = log('expense');

  CollectionReference<Json> get _col => _store.col(Col.expenses);

  Future<Expense> add(ExpenseDraft draft) async {
    if (draft.amount < 0) {
      throw const ValidationException(ErrorCode.expenseAmountNegative);
    }
    final id = _store.newId(Col.expenses);
    await _store.commit(
        _store.batch()..set(_col.doc(id), draft.toJson()), 'expenses.add');
    _log.info('logged category=${draft.category} '
        'amount=${draft.amount.toStringAsFixed(2)} by=${draft.createdBy}');
    return Expense.fromJson({...draft.toJson(), 'id': id});
  }

  Future<List<Expense>> list({DateTime? start, DateTime? end}) async {
    Query<Json> q = _col;
    if (start != null) q = q.where('date', isGreaterThanOrEqualTo: ymd(start));
    if (end != null) q = q.where('date', isLessThanOrEqualTo: ymd(end));
    return (await _store.fresh(q)).map(Expense.fromJson).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<ProfitSummary> summary({DateTime? start, DateTime? end}) async {
    Query<Json> topups =
        _store.col(Col.topups).where('paymentStatus', isEqualTo: 'confirmed');
    if (start != null) {
      topups = topups.where('createdAt',
          isGreaterThanOrEqualTo: start.toUtc().toIso8601String());
    }
    if (end != null) {
      topups = topups.where('createdAt',
          isLessThanOrEqualTo: end.toUtc().toIso8601String());
    }
    final revenue = (await _store.fresh(topups))
        .where((t) => t['reversed'] != true)
        .fold<double>(0, (total, t) => total + (t['amount'] as num).toDouble());
    final spend = (await list(start: start, end: end))
        .fold<double>(0, (total, e) => total + e.amount);
    return ProfitSummary(
        revenue: revenue, expenses: spend, profit: revenue - spend);
  }
}
