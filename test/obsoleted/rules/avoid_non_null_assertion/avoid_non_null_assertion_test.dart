@TestOn('vm')
import 'package:dart_code_metrics/src/models/severity.dart';
import 'package:dart_code_metrics/src/obsoleted/rules/avoid_non_null_assertion_rule.dart';
import 'package:test/test.dart';

import '../../../helpers/file_resolver.dart';
import '../../../helpers/rule_test_helper.dart';

const _examplePath =
    'test/obsoleted/rules/avoid_non_null_assertion/examples/example.dart';

void main() {
  group('AvoidNonNullAssertion', () {
    test('initialization', () async {
      final unit = await FileResolver.resolve(_examplePath);
      final issues = AvoidNonNullAssertionRule().check(unit);

      RuleTestHelper.verifyInitialization(
        issues: issues,
        ruleId: 'avoid-non-null-assertion',
        severity: Severity.warning,
      );
    });

    test('reports about found issues', () async {
      final unit = await FileResolver.resolve(_examplePath);
      final issues = AvoidNonNullAssertionRule().check(unit);

      RuleTestHelper.verifyIssues(
        issues: issues,
        startOffsets: [70, 208, 208, 460],
        startLines: [7, 15, 15, 27],
        startColumns: [5, 5, 5, 5],
        endOffsets: [76, 215, 222, 467],
        locationTexts: [
          'field!',
          'object!',
          'object!.field!',
          'object!',
        ],
        messages: [
          'Avoid using non null assertion.',
          'Avoid using non null assertion.',
          'Avoid using non null assertion.',
          'Avoid using non null assertion.',
        ],
      );
    });
  });
}
