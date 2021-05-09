import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/analysis_options/analysis_options_provider.dart';
// ignore: implementation_imports
import 'package:analyzer/src/context/builder.dart';
// ignore: implementation_imports
import 'package:analyzer/src/context/context_root.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/driver.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/file_state.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

import '../analyzers/lint_analyzer/anti_patterns/patterns_factory.dart';
import '../analyzers/lint_analyzer/lint_analyzer.dart';
import '../analyzers/lint_analyzer/metrics/metrics_list/cyclomatic_complexity/cyclomatic_complexity_metric.dart';
import '../analyzers/lint_analyzer/metrics/metrics_list/number_of_parameters_metric.dart';
import '../analyzers/lint_analyzer/parserd_config.dart';
import '../analyzers/lint_analyzer/rules/rules_factory.dart';
import '../config_builder/models/analysis_options.dart';
import '../config_builder/models/config.dart';
import '../config_builder/models/deprecated_option.dart';
import '../utils/exclude_utils.dart';
import '../utils/yaml_utils.dart';
import 'analyzer_plugin_utils.dart';

// TODO const _codeMetricsId = 'code-metrics';

const _defaultSkippedFolders = ['.dart_tool/**', 'packages/**'];

class MetricsAnalyzerPlugin extends ServerPlugin {
  static const _analyzer = LintAnalyzer();

  final _configs = <AnalysisDriverGeneric, ParsedConfig>{};

  var _filesFromSetPriorityFilesRequest = <String>[];

  @override
  String get contactInfo =>
      'https://github.com/dart-code-checker/dart-code-metrics/issues';

  @override
  List<String> get fileGlobsToAnalyze => const ['*.dart'];

  @override
  String get name => 'Dart Code Metrics';

  @override
  String get version => '1.0.0-alpha.0';

  MetricsAnalyzerPlugin(ResourceProvider provider) : super(provider);

  @override
  void contentChanged(String path) {
    super.driverForPath(path)?.addFile(path);
  }

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final rootPath = contextRoot.root;
    final root = ContextRoot(
      rootPath,
      contextRoot.exclude,
      pathContext: resourceProvider.pathContext,
    )..optionsFilePath = contextRoot.optionsFile;

    final contextBuilder = ContextBuilder(resourceProvider, sdkManager, null)
      ..analysisDriverScheduler = analysisDriverScheduler
      ..byteStore = byteStore
      ..performanceLog = performanceLog
      ..fileContentOverlay = FileContentOverlay();

    final workspace = ContextBuilder.createWorkspace(
      resourceProvider: resourceProvider,
      options: ContextBuilderOptions(),
      rootPath: rootPath,
    );

    final dartDriver = contextBuilder.buildDriver(root, workspace);

    final options = _readOptions(dartDriver);
    if (options == null) {
      return dartDriver;
    }

    _configs[dartDriver] = ParsedConfig(
      prepareExcludes(
        [
          ..._defaultSkippedFolders,
          ...options.excludePatterns,
        ],
        rootPath,
      ),
      getRulesById(options.rules),
      getPatternsById(options.antiPatterns),
      [],
      [
        CyclomaticComplexityMetric(config: options.metrics),
        NumberOfParametersMetric(config: options.metrics),
      ],
      prepareExcludes(options.excludeForMetricsPatterns, rootPath),
      options.metrics,
    );

    final deprecations = checkConfigDeprecatedOptions(
      _configs[dartDriver]!,
      deprecatedOptions,
      contextRoot.optionsFile!,
    );
    if (deprecations.isNotEmpty) {
      channel.sendNotification(plugin.AnalysisErrorsParams(
        contextRoot.optionsFile!,
        deprecations.map((deprecation) => deprecation.error).toList(),
      ).toNotification());
    }

    runZonedGuarded(
      () {
        dartDriver.results.listen((analysisResult) {
          _processResult(dartDriver, analysisResult);
        });
      },
      (e, stackTrace) {
        channel.sendNotification(
          plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
              .toNotification(),
        );
      },
    );

    return dartDriver;
  }

  @override
  Future<plugin.AnalysisSetContextRootsResult> handleAnalysisSetContextRoots(
    plugin.AnalysisSetContextRootsParams parameters,
  ) async {
    final result = await super.handleAnalysisSetContextRoots(parameters);
    // The super-call adds files to the driver, so we need to prioritize them so they get analyzed.
    _updatePriorityFiles();

    return result;
  }

  @override
  Future<plugin.AnalysisSetPriorityFilesResult> handleAnalysisSetPriorityFiles(
    plugin.AnalysisSetPriorityFilesParams parameters,
  ) async {
    _filesFromSetPriorityFilesRequest = parameters.files;
    _updatePriorityFiles();

    return plugin.AnalysisSetPriorityFilesResult();
  }

  @override
  Future<plugin.EditGetFixesResult> handleEditGetFixes(
    plugin.EditGetFixesParams parameters,
  ) async {
    try {
      final driver = driverForPath(parameters.file) as AnalysisDriver;
      // ignore: deprecated_member_use
      final analysisResult = await driver.getResult(parameters.file);

      final fixes = _check(driver, analysisResult)
          .where((fix) =>
              fix.error.location.file == parameters.file &&
              fix.error.location.offset <= parameters.offset &&
              parameters.offset <=
                  fix.error.location.offset + fix.error.location.length &&
              fix.fixes.isNotEmpty)
          .toList();

      return plugin.EditGetFixesResult(fixes);
    } on Exception catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );

      return plugin.EditGetFixesResult([]);
    }
  }

  void _processResult(
    AnalysisDriver driver,
    ResolvedUnitResult analysisResult,
  ) {
    try {
      if (analysisResult.unit != null) {
        final fixes = _check(driver, analysisResult);

        channel.sendNotification(plugin.AnalysisErrorsParams(
          analysisResult.path!,
          fixes.map((fix) => fix.error).toList(),
        ).toNotification());
      } else {
        channel.sendNotification(
          plugin.AnalysisErrorsParams(analysisResult.path!, [])
              .toNotification(),
        );
      }
    } on Exception catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );
    }
  }

  Iterable<plugin.AnalysisErrorFixes> _check(
    AnalysisDriver driver,
    ResolvedUnitResult analysisResult,
  ) {
    final result = <plugin.AnalysisErrorFixes>[];
    final config = _configs[driver];

    if (config != null) {
      // ignore: deprecated_member_use
      final root = driver.contextRoot?.root;

      final report = _analyzer.runPluginAnalysis(analysisResult, config, root!);

      if (report != null) {
        result.addAll([
          ...report.issues
              .map((issue) =>
                  codeIssueToAnalysisErrorFixes(issue, analysisResult))
              .toList(),
          ...report.antiPatternCases
              .map(designIssueToAnalysisErrorFixes)
              .toList(),
          // ...report.functions.map((key, value) => null),
          // TODO
        ]);
      }

      // ignore: deprecated_member_use
      if (analysisResult.path == driver.contextRoot?.optionsFilePath) {
        final deprecations = checkConfigDeprecatedOptions(
          config,
          deprecatedOptions,
          analysisResult.path ?? '',
        );

        result.addAll(deprecations);
      }
    }

    return result;
  }

  Config? _readOptions(AnalysisDriver driver) {
    // ignore: deprecated_member_use
    final optionsPath = driver.contextRoot?.optionsFilePath;
    if (optionsPath != null && optionsPath.isNotEmpty) {
      final file = resourceProvider.getFile(optionsPath);
      if (file.exists) {
        return Config.fromAnalysisOptions(
          AnalysisOptions(yamlMapToDartMap(
            AnalysisOptionsProvider(driver.sourceFactory)
                .getOptionsFromFile(file),
          )),
        );
      }
    }

    return null;
  }

  /// AnalysisDriver doesn't fully resolve files that are added via `addFile`; they need to be either explicitly requested
  /// via `getResult`/etc, or added to `priorityFiles`.
  ///
  /// This method updates `priorityFiles` on the driver to include:
  ///
  /// - Any files prioritized by the analysis server via [handleAnalysisSetPriorityFiles]
  /// - All other files the driver has been told to analyze via addFile (in [ServerPlugin.handleAnalysisSetContextRoots])
  ///
  /// As a result, [_processResult] will get called with resolved units, and thus all of our diagnostics
  /// will get run on all files in the repo instead of only the currently open/edited ones!
  void _updatePriorityFiles() {
    final filesToFullyResolve = {
      // Ensure these go first, since they're actually considered priority; ...
      ..._filesFromSetPriorityFilesRequest,

      // ... all other files need to be analyzed, but don't trump priority
      for (final driver2 in driverMap.values)
        ...(driver2 as AnalysisDriver).addedFiles,
    };

    // From ServerPlugin.handleAnalysisSetPriorityFiles
    final filesByDriver = <AnalysisDriverGeneric, List<String>>{};
    for (final file in filesToFullyResolve) {
      final contextRoot = contextRootContaining(file);
      if (contextRoot != null) {
        // TODO(dkrutskikh): Which driver should we use if there is no context root?
        final driver = driverMap[contextRoot]!;
        filesByDriver.putIfAbsent(driver, () => <String>[]).add(file);
      }
    }
    filesByDriver.forEach((driver, files) {
      driver.priorityFiles = files;
    });
  }
}
