import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/services/people/member_service.dart';

/// Balances carry anytime-meal keys next to the three built-ins (ADR 0009 §3).
void main() {
  test('a pre-0009 balance map reads exactly as before', () {
    final u = UnitCounts.fromJson({'lunch': 3, 'breakfast': 1, 'brunch': 0});
    expect((u.lunch, u.breakfast, u.brunch), (3, 1, 0));
    expect(u.anytime, isEmpty);
    expect(u.toJson(), {'lunch': 3, 'breakfast': 1, 'brunch': 0});
  });

  test('an anytime key round-trips; a missing key reads 0', () {
    final u = UnitCounts.fromJson(
        {'lunch': 1, 'breakfast': 0, 'brunch': 0, 'mtea00001': 12});
    expect(u['mtea00001'], 12);
    expect(u['lunch'], 1);
    expect(u['mjuice001'], 0);
    expect(UnitCounts.fromJson(u.toJson())['mtea00001'], 12);
    expect(u.byMeal, {'lunch': 1, 'mtea00001': 12});
    expect(u.total, 13);
  });

  test('+ adds built-ins and anytime keys; single and isAllZero', () {
    final sum = const UnitCounts(lunch: 1, anytime: {'mtea00001': 2}) +
        UnitCounts.single('mtea00001', 3) +
        UnitCounts.single('mjuice001') +
        UnitCounts.single('brunch');
    expect(
        sum.byMeal, {'lunch': 1, 'brunch': 1, 'mtea00001': 5, 'mjuice001': 1});
    expect(const UnitCounts(anytime: {'mtea00001': 0}).isAllZero, isTrue);
    expect(UnitCounts.single('mtea00001').isAllZero, isFalse);
  });

  test('balanceDelta writes one increment per non-zero meal', () {
    final d = MemberService.balanceDelta(
        const UnitCounts(lunch: 2, anytime: {'mtea00001': 1}),
        sign: -1);
    expect(d.keys, containsAll(['balances.lunch', 'balances.mtea00001']));
    expect(d.keys, isNot(contains('balances.breakfast')));
  });

  test('balanceDelta refuses an id that is not a safe field path', () {
    expect(
        () => MemberService.balanceDelta(const UnitCounts(anytime: {'a.b': 1})),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.unknownMeal)));
  });
}
