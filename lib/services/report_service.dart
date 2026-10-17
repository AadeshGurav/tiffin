import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/logging.dart';
import '../data/store.dart';
import '../domain/ledger.dart';
import '../domain/member.dart';
import '../domain/menu.dart';
import '../domain/ops.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import 'expense_service.dart';
import 'settings_service.dart';
import 'xlsx_writer.dart';

/// Builds the admin's `.xlsx` report, in the language of whoever exports it.
///
/// Export only, on purpose: a spreadsheet loses types, ids and referential
/// integrity, so reading one back would be a route to corrupt balances. Moving
/// data between projects is the backup file's job — this one is for people to
/// read, print and pivot.
class ReportService {
  ReportService(this._store, this._settings, this._expenses);

  final Store _store;
  final SettingsService _settings;
  final ExpenseService _expenses;
  final _log = log('report');

  /// [start]/[end] are inclusive local dates; null means "everything".
  Future<List<int>> build({
    required AppText t,
    DateTime? start,
    DateTime? end,
    Set<ReportSection> sections = ReportSection.all,
  }) async {
    final settings = await _settings.read();
    final zone = _zoneOf(settings.localTimezone);
    final members = (await _store.cached(_store.col(Col.members)))
        .map(Member.fromJson)
        .toList();
    final nameById = {for (final m in members) m.id: m.name};
    String nameOf(String id) => nameById[id] ?? id;

    // Dates are formatted in the canteen's own timezone — the report has to
    // agree with the meal windows the scans were judged against.
    String at(DateTime utc) => DateFormat.yMd(t.localeName)
        .add_Hm()
        .format(tz.TZDateTime.from(utc.toUtc(), zone));
    String day(DateTime d) => DateFormat.yMd(t.localeName).format(d);

    bool inRange(DateTime when) =>
        (start == null || !when.isBefore(start)) &&
        (end == null || !when.isAfter(end));
    Future<List<Json>> all(String col) => _store.fresh(_store.col(col));

    final sheets = <Sheet>[];

    if (sections.contains(ReportSection.summary)) {
      final profit = await _expenses.summary(start: start, end: end);
      sheets.add(Sheet(t.reportSheetSummary,
          headers: [t.reportColFigure, t.reportColValue])
        ..add([t.reportGenerated, at(DateTime.now().toUtc())])
        ..add([t.reportTimezone, settings.localTimezone])
        ..add([
          t.reportRangeFrom,
          start == null ? t.reportRangeBeginning : day(start)
        ])
        ..add([t.reportRangeTo, end == null ? t.reportRangeToday : day(end)])
        ..add([t.reportSheetMembers, members.length])
        ..add([t.reportRevenue, profit.revenue])
        ..add([t.reportSheetExpenses, profit.expenses])
        ..add([t.reportProfit, profit.profit]));
    }

    if (sections.contains(ReportSection.members)) {
      final sheet = Sheet(t.reportSheetMembers, headers: [
        t.reportColId,
        t.reportColType,
        t.reportColName,
        t.reportColClass,
        t.reportColRoll,
        t.reportColStaffId,
        t.reportColQr,
        t.reportColStatus,
        t.reportColAdded,
      ]);
      for (final m in members) {
        sheet.add([
          m.id,
          t.memberTypeLabel(m.type),
          m.name,
          m.className,
          m.rollNumber,
          m.staffId,
          m.qrCodeId,
          t.statusLabel(m.status),
          day(m.createdAt),
        ]);
      }
      sheets.add(sheet);
    }

    if (sections.contains(ReportSection.balances)) {
      final sheet = Sheet(t.reportSheetBalances, headers: [
        t.reportColId,
        t.reportColName,
        t.mealLunch,
        t.mealBreakfast,
        t.mealBrunch,
        t.reportColTotal,
        t.reportColStatus,
      ]);
      for (final m in members) {
        final b = m.balances;
        sheet.add([
          m.id,
          m.name,
          b.lunch,
          b.breakfast,
          b.brunch,
          b.lunch + b.breakfast + b.brunch,
          t.statusLabel(m.status),
        ]);
      }
      sheets.add(sheet);
    }

    if (sections.contains(ReportSection.scans)) {
      final scans = (await all(Col.scans)).map(ScanRecord.fromJson).toList()
        ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      final sheet = Sheet(t.reportSheetScans, headers: [
        t.reportColWhen,
        t.reportColMember,
        t.reportColMeal,
        t.reportColOnGrace,
        t.reportColReversed,
        t.reportColReversedBy,
      ]);
      for (final s in scans.where((s) => inRange(s.scannedAt))) {
        sheet.add([
          at(s.scannedAt),
          s.memberName,
          t.mealLabel(s.mealType),
          t.yesNo(s.viaGrace),
          t.yesNo(s.reversed),
          s.reversedBy,
        ]);
      }
      sheets.add(sheet);
    }

    if (sections.contains(ReportSection.topups)) {
      final topups = (await all(Col.topups)).map(Topup.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final sheet = Sheet(t.reportSheetTopups, headers: [
        t.reportColWhen,
        t.reportColMember,
        t.mealLunch,
        t.mealBreakfast,
        t.mealBrunch,
        t.reportColAmount,
        t.reportColMethod,
        t.reportColStatus,
        t.reportColReversed,
        t.reportColBy,
      ]);
      for (final x in topups.where((x) => inRange(x.createdAt))) {
        sheet.add([
          at(x.createdAt),
          nameOf(x.memberId),
          x.lunchUnits,
          x.breakfastUnits,
          x.brunchUnits,
          x.amount,
          t.paymentMethodLabel(x.paymentMethod),
          t.paymentStatusLabel(x.paymentStatus),
          t.yesNo(x.reversed),
          x.createdBy,
        ]);
      }
      sheets.add(sheet);
    }

    if (sections.contains(ReportSection.refunds)) {
      final refunds = (await all(Col.refunds)).map(Refund.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final sheet = Sheet(t.reportSheetRefunds, headers: [
        t.reportColWhen,
        t.reportColMember,
        t.mealLunch,
        t.mealBreakfast,
        t.mealBrunch,
        t.reportColAmount,
        t.reportColReason,
        t.reportColBy,
      ]);
      for (final r in refunds.where((r) => inRange(r.createdAt))) {
        sheet.add([
          at(r.createdAt),
          nameOf(r.memberId),
          r.lunchUnits,
          r.breakfastUnits,
          r.brunchUnits,
          r.refundAmount,
          r.reason,
          r.processedBy,
        ]);
      }
      sheets.add(sheet);
    }

    if (sections.contains(ReportSection.expenses)) {
      final expenses = (await all(Col.expenses)).map(Expense.fromJson).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final sheet = Sheet(t.reportSheetExpenses, headers: [
        t.reportColDate,
        t.reportColCategory,
        t.reportColDescription,
        t.reportColAmount,
        t.reportColBy,
      ]);
      for (final e in expenses.where((e) => inRange(e.date))) {
        sheet.add(
            [day(e.date), e.category, e.description, e.amount, e.createdBy]);
      }
      sheets.add(sheet);
    }

    if (sections.contains(ReportSection.menu)) {
      final entries = (await all(Col.menu)).map(MenuEntry.fromJson).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final sheet = Sheet(t.reportSheetMenu, headers: [
        t.reportColDate,
        t.reportColMeal,
        t.reportColCategory,
        t.reportColPlates,
        t.reportColItems,
        t.reportColBy,
      ]);
      for (final e in entries.where((e) => inRange(e.date))) {
        sheet.add([
          day(e.date),
          t.mealLabel(e.mealType),
          e.category,
          e.headcount,
          e.items.join(', '),
          e.createdBy,
        ]);
      }
      sheets.add(sheet);
    }

    // A workbook with no tabs is a file Excel refuses to open, so an
    // all-deselected export becomes an honest summary rather than a bad file.
    if (sheets.isEmpty) {
      sheets.add(Sheet(t.reportSheetSummary,
          headers: [t.reportColFigure, t.reportColValue])
        ..add([t.reportGenerated, at(DateTime.now().toUtc())])
        ..add([t.reportColValue, t.reportNoSections]));
    }

    _log.info('report_built sheets=${sheets.length}');
    return const XlsxWriter().build(sheets);
  }

  /// Suggested filename, dated so successive exports don't overwrite.
  String fileName({DateTime? now}) =>
      'tiffin-report-${DateFormat('yyyy-MM-dd').format(now ?? DateTime.now())}'
      '.xlsx';

  tz.Location _zoneOf(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      // A report is not worth failing over a bad zone; UTC and carry on.
      _log.warning('unknown timezone "$name", formatting in UTC');
      return tz.UTC;
    }
  }
}

/// The tabs an export can include.
enum ReportSection {
  summary,
  members,
  balances,
  scans,
  topups,
  refunds,
  expenses,
  menu;

  static const all = <ReportSection>{
    summary,
    members,
    balances,
    scans,
    topups,
    refunds,
    expenses,
    menu,
  };

  String label(AppText t) => switch (this) {
        ReportSection.summary => t.reportSheetSummary,
        ReportSection.members => t.reportSheetMembers,
        ReportSection.balances => t.reportSheetBalances,
        ReportSection.scans => t.reportSheetScans,
        ReportSection.topups => t.reportSheetTopups,
        ReportSection.refunds => t.reportSheetRefunds,
        ReportSection.expenses => t.reportSheetExpenses,
        ReportSection.menu => t.reportSheetMenu,
      };
}
