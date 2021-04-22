import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:source_span/source_span.dart';

import '../../models/context_message.dart';
import '../../models/entity_type.dart';
import '../../models/metric_documentation.dart';
import '../../models/scoped_class_declaration.dart';
import '../../models/scoped_function_declaration.dart';
import '../../utils/metric_utils.dart';
import '../function_metric.dart';
import '../metric_computation_result.dart';
import 'source_code_visitor.dart';

const _documentation = MetricDocumentation(
  name: 'Source lines of Code',
  shortName: 'SLOC',
  brief:
      'The approximate number of source code lines in a method, blank lines and comments are not counted.',
  measuredType: EntityType.methodEntity,
  examples: [],
);

/// Source lines of Code (SLOC)
///
/// This metric used to measure the size of a computer program by counting the
/// number of lines in the text of the program's source code. SLOC is typically
/// used to predict the amount of effort that will be required to develop a
/// program, as well as to estimate programming productivity or maintainability
/// once the software is produced.
class SourceLinesOfCodeMetric extends FunctionMetric<int> {
  static const String metricId = 'source-lines-of-code';

  SourceLinesOfCodeMetric({Map<String, Object> config = const {}})
      : super(
          id: metricId,
          documentation: _documentation,
          threshold: readThreshold<int>(config, metricId, 50),
          levelComputer: valueLevel,
        );

  @override
  MetricComputationResult<int> computeImplementation(
    Declaration node,
    Iterable<ScopedClassDeclaration> classDeclarations,
    Iterable<ScopedFunctionDeclaration> functionDeclarations,
    ResolvedUnitResult source,
  ) {
    final visitor = SourceCodeVisitor(source.lineInfo);
    node.visitChildren(visitor);

    return MetricComputationResult(
      value: visitor.linesWithCode.length,
      context: _context(node, visitor.linesWithCode, source),
    );
  }

  @override
  String commentMessage(String nodeType, int value, int threshold) {
    final exceeds =
        value > threshold ? ', exceeds the maximum of $threshold allowed' : '';
    final lines = '$value source ${value == 1 ? 'line' : 'lines'} of code';

    return 'This $nodeType has $lines$exceeds.';
  }

  @override
  String? recommendationMessage(String nodeType, int value, int threshold) =>
      (value > threshold)
          ? 'Consider breaking this $nodeType up into smaller parts.'
          : null;

  Iterable<ContextMessage> _context(
    Declaration node,
    Iterable<int> linesWithCode,
    ResolvedUnitResult source,
  ) =>
      linesWithCode.map((lineIndex) {
        final lineStartLocation = SourceLocation(
          source.unit?.lineInfo?.getOffsetOfLine(lineIndex) ?? 0,
          sourceUrl: source.path,
          line: lineIndex,
          column: 0,
        );

        return ContextMessage(
          message: 'line contains source code',
          location: SourceSpan(lineStartLocation, lineStartLocation, ''),
        );
      }).toList()
        ..sort((a, b) => a.location.start.compareTo(b.location.start));
}
