@TestOn('vm')
import 'package:ansicolor/ansicolor.dart';
import 'package:dart_code_metrics/src/metrics/maximum_nesting_level/maximum_nesting_level_metric.dart';
import 'package:dart_code_metrics/src/metrics/number_of_methods_metric.dart';
import 'package:dart_code_metrics/src/metrics/number_of_parameters_metric.dart';
import 'package:dart_code_metrics/src/models/entity_type.dart';
import 'package:dart_code_metrics/src/models/file_report.dart';
import 'package:dart_code_metrics/src/models/issue.dart';
import 'package:dart_code_metrics/src/models/metric_documentation.dart';
import 'package:dart_code_metrics/src/models/metric_value.dart';
import 'package:dart_code_metrics/src/models/metric_value_level.dart';
import 'package:dart_code_metrics/src/models/replacement.dart';
import 'package:dart_code_metrics/src/models/report.dart';
import 'package:dart_code_metrics/src/models/severity.dart';
import 'package:dart_code_metrics/src/obsoleted/config/config.dart';
import 'package:dart_code_metrics/src/obsoleted/reporters/console_reporter.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import '../../stubs_builders.dart';
import '../stubs_builders.dart';

void main() {
  group('ConsoleReporter.report report about', () {
    const fullPath = '/home/developer/work/project/example.dart';

    late ConsoleReporter _reporter;
    late ConsoleReporter _verboseReporter;

    setUp(() {
      ansiColorDisabled = false;
      _reporter = ConsoleReporter();
      _verboseReporter = ConsoleReporter(reportAll: true);
    });

    test('files without any records', () async {
      final report = await _reporter.report([]);
      final verboseReport = (await _verboseReporter.report([])).toList();

      expect(report, isEmpty);
      expect(verboseReport, isEmpty);
    });

    group('component', () {
      test('without methods', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{
              'class': buildComponentRecordStub(metrics: const [
                MetricValue<int>(
                  metricsId: NumberOfMethodsMetric.metricId,
                  documentation: MetricDocumentation(
                    name: '',
                    shortName: '',
                    brief: '',
                    measuredType: EntityType.classEntity,
                    examples: [],
                  ),
                  value: 0,
                  level: MetricValueLevel.none,
                  comment: '',
                ),
              ]),
            }),
            functions: Map.unmodifiable(<String, Report>{}),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = await _reporter.report(records);
        final verboseReport = (await _verboseReporter.report(records)).toList();

        expect(report, isEmpty);
        expect(verboseReport, hasLength(3));
        expect(
          verboseReport[1],
          contains('number of methods: \x1B[38;5;7m0\x1B[0m'),
        );
      });

      test('with a lot of methods', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{
              'class': buildComponentRecordStub(metrics: const [
                MetricValue<int>(
                  metricsId: NumberOfMethodsMetric.metricId,
                  documentation: MetricDocumentation(
                    name: '',
                    shortName: '',
                    brief: '',
                    measuredType: EntityType.classEntity,
                    examples: [],
                  ),
                  value: 20,
                  level: MetricValueLevel.warning,
                  comment: '',
                ),
              ]),
            }),
            functions: Map.unmodifiable(<String, Report>{}),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = (await _reporter.report(records)).toList();

        expect(report, hasLength(3));
        expect(report[1], contains('number of methods: \x1B[38;5;3m20\x1B[0m'));
      });
    });

    group('function', () {
      test('with long body', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{}),
            functions: Map.unmodifiable(<String, Report>{
              'function': buildFunctionRecordStub(
                metrics: [
                  buildMetricValueStub<int>(
                    id: linesOfExecutableCodeKey,
                    value: 150,
                    level: MetricValueLevel.alarm,
                  ),
                ],
              ),
            }),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = (await _reporter.report(records)).toList();

        expect(report, hasLength(3));
        expect(
          report[1],
          contains('lines of executable code: \x1B[38;5;1m150\x1B[0m'),
        );
      });

      test('with short body', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{}),
            functions: Map.unmodifiable(<String, Report>{
              'function': buildFunctionRecordStub(
                metrics: [
                  buildMetricValueStub<int>(
                    id: linesOfExecutableCodeKey,
                    value: 5,
                  ),
                ],
              ),
            }),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = await _reporter.report(records);
        final verboseReport = (await _verboseReporter.report(records)).toList();

        expect(report, isEmpty);
        expect(verboseReport, hasLength(3));
        expect(
          verboseReport[1],
          contains('lines of executable code: \x1B[38;5;7m5\x1B[0m'),
        );
      });

      test('without arguments', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{}),
            functions: Map.unmodifiable(<String, Report>{
              'function': buildFunctionRecordStub(
                metrics: [
                  buildMetricValueStub<int>(
                    id: NumberOfParametersMetric.metricId,
                    value: 0,
                  ),
                ],
              ),
            }),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = await _reporter.report(records);
        final verboseReport = (await _verboseReporter.report(records)).toList();

        expect(report, isEmpty);
        expect(verboseReport, hasLength(3));
        expect(
          verboseReport[1],
          contains('number of arguments: \x1B[38;5;7m0\x1B[0m'),
        );
      });

      test('with a lot of arguments', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{}),
            functions: Map.unmodifiable(<String, Report>{
              'function': buildFunctionRecordStub(
                metrics: [
                  buildMetricValueStub<int>(
                    id: NumberOfParametersMetric.metricId,
                    value: 10,
                    level: MetricValueLevel.alarm,
                  ),
                ],
              ),
            }),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = (await _reporter.report(records)).toList();

        expect(report, hasLength(3));
        expect(
          report[1],
          contains('number of arguments: \x1B[38;5;1m10\x1B[0m'),
        );
      });

      test('with low nested level', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{}),
            functions: Map.unmodifiable(<String, Report>{
              'function': buildFunctionRecordStub(
                metrics: const [
                  MetricValue<int>(
                    metricsId: MaximumNestingLevelMetric.metricId,
                    documentation: MetricDocumentation(
                      name: '',
                      shortName: '',
                      brief: '',
                      measuredType: EntityType.classEntity,
                      examples: [],
                    ),
                    value: 2,
                    level: MetricValueLevel.none,
                    comment: '',
                  ),
                ],
              ),
            }),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = await _reporter.report(records);
        final verboseReport = (await _verboseReporter.report(records)).toList();

        expect(report, isEmpty);
        expect(verboseReport, hasLength(3));
        expect(
          verboseReport[1],
          contains('nesting level: \x1B[38;5;7m2\x1B[0m'),
        );
      });

      test('with high nested level', () async {
        final records = [
          FileReport(
            path: fullPath,
            relativePath: 'example.dart',
            classes: Map.unmodifiable(<String, Report>{}),
            functions: Map.unmodifiable(<String, Report>{
              'function': buildFunctionRecordStub(
                metrics: const [
                  MetricValue<int>(
                    metricsId: MaximumNestingLevelMetric.metricId,
                    documentation: MetricDocumentation(
                      name: '',
                      shortName: '',
                      brief: '',
                      measuredType: EntityType.classEntity,
                      examples: [],
                    ),
                    value: 7,
                    level: MetricValueLevel.warning,
                    comment: '',
                  ),
                ],
              ),
            }),
            issues: const [],
            antiPatternCases: const [],
          ),
        ];

        final report = (await _reporter.report(records)).toList();

        expect(report, hasLength(3));
        expect(
          report[1],
          contains('nesting level: \x1B[38;5;3m7\x1B[0m'),
        );
      });
    });

    test('with design issues', () async {
      final records = [
        FileReport(
          path: fullPath,
          relativePath: 'example.dart',
          classes: Map.unmodifiable(<String, Report>{}),
          functions: Map.unmodifiable(<String, Report>{}),
          issues: const [],
          antiPatternCases: [
            Issue(
              ruleId: 'patternId1',
              documentation: Uri.parse('https://docu.edu/patternId1.html'),
              location: SourceSpanBase(
                SourceLocation(
                  1,
                  sourceUrl: Uri.parse(fullPath),
                  line: 2,
                  column: 3,
                ),
                SourceLocation(6, sourceUrl: Uri.parse(fullPath)),
                'issue',
              ),
              severity: Severity.none,
              message: 'first issue message',
              verboseMessage: 'recommendation',
            ),
          ],
        ),
      ];

      final report = (await _reporter.report(records)).toList();

      expect(report, hasLength(3));
      expect(
        report[1],
        equals(
          '\x1B[38;5;3mDesign  \x1B[0mfirst issue message : 2:3 : patternId1 https://docu.edu/patternId1.html',
        ),
      );
    });

    test('with style severity issues', () async {
      final records = [
        FileReport(
          path: fullPath,
          relativePath: 'example.dart',
          classes: Map.unmodifiable(<String, Report>{}),
          functions: Map.unmodifiable(<String, Report>{}),
          issues: [
            Issue(
              ruleId: 'ruleId1',
              documentation: Uri.parse('https://docu.edu/ruleId1.html'),
              severity: Severity.style,
              location: SourceSpanBase(
                SourceLocation(
                  1,
                  sourceUrl: Uri.parse(fullPath),
                  line: 2,
                  column: 3,
                ),
                SourceLocation(6, sourceUrl: Uri.parse(fullPath)),
                'issue',
              ),
              message: 'first issue message',
              suggestion: const Replacement(
                comment: 'correction comment',
                replacement: 'correction',
              ),
            ),
          ],
          antiPatternCases: const [],
        ),
      ];

      final report = (await _reporter.report(records)).toList();

      expect(report, hasLength(3));
      expect(
        report[1],
        equals(
          '\x1B[38;5;4mStyle   \x1B[0mfirst issue message : 2:3 : ruleId1 https://docu.edu/ruleId1.html',
        ),
      );
    });
  });
}
