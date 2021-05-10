// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:io';

import 'package:dart_code_metrics/metrics_analyzer.dart';
import 'package:dart_code_metrics/reporters.dart';
import 'package:dart_code_metrics/src/config_builder/config_builder.dart';

Future<void> main() async {
  // Get some folder you would like to analyze
  const foldersToAnalyze = ['lib', 'test'];

  // Root folder path is used to resolve relative file paths
  const rootFolder = 'projectRoot';

  // First of all config has to be created for a checker
  const config = Config(
    excludePatterns: ['test/resources/**'],
    excludeForMetricsPatterns: ['test/**'],
    metrics: {
      'maximum-nesting-level': '5',
      'number-of-methods': '10',
    },
    rules: {
      'double-literal-format': {},
      'newline-before-return': {'severity': 'info'},
    },
    antiPatterns: {'long-method': {}},
  );

  final lintConfig = ConfigBuilder.getLintConfig(config, rootFolder);

  final result = await const LintAnalyzer()
      .runCliAnalysis(foldersToAnalyze, rootFolder, lintConfig);

  // Now runner.results() contains some insights about analyzed code. Let's report it!
  // For a simple example we would report results to terminal

  // Now the reporter itself
  final reporter = LintConsoleReporter(stdout);

  // Now pass collected analysis reports from runner to reporter and that's it
  await reporter.report(result);

  // There is also JsonReporter for making machine-readable reports
  // HtmlReporter produces fancy html-documents with bells and whistles
  // And CodeClimateReporter produces reports that are widely understood by various CI tools
  // If none of these fits your case you can always access raw analysis info via results() method of runner and process it any way you see fit
}
