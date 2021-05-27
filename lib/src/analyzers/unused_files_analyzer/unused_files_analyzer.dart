import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart';

import '../../../config.dart';
import '../../../reporters.dart';
import '../../utils/exclude_utils.dart';
import 'models/unused_files_file_report.dart';
import 'reporters/reporter_factory.dart';
import 'unused_files_config.dart';
import 'unused_files_visitor.dart';

class UnusedFilesAnalyzer {
  const UnusedFilesAnalyzer();

  Reporter? getReporter({
    required Config config,
    required String name,
    required IOSink output,
    required String reportFolder,
  }) =>
      reporter(
        config: config,
        name: name,
        output: output,
        reportFolder: reportFolder,
      );

  Future<Iterable<UnusedFilesFileReport>> runCliAnalysis(
    Iterable<String> folders,
    String rootFolder,
    UnusedFilesConfig config,
  ) async {
    final collection = AnalysisContextCollection(
      includedPaths:
          folders.map((path) => normalize(join(rootFolder, path))).toList(),
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final filePaths = folders
        .expand((directory) => Glob('$directory/**.dart')
            .listFileSystemSync(
              const LocalFileSystem(),
              root: rootFolder,
              followLinks: false,
            )
            .whereType<File>()
            .where((entity) => !isExcluded(
                  relative(entity.path, from: rootFolder),
                  config.globalExcludes,
                ))
            .map((entity) => entity.path))
        .toList();

    final unusedFiles = filePaths.toSet();

    for (final filePath in filePaths) {
      final normalized = normalize(absolute(filePath));

      final analysisContext = collection.contextFor(normalized);
      final unit =
          await analysisContext.currentSession.getResolvedUnit2(normalized);

      if (unit is ResolvedUnitResult) {
        final visitor = UnusedFilesVisitor(filePath);
        unit.unit?.visitChildren(visitor);

        unusedFiles.removeAll(visitor.paths);
      }
    }

    return unusedFiles.map((path) {
      final relativePath = relative(path, from: rootFolder);

      return UnusedFilesFileReport(
        path: path,
        relativePath: relativePath,
      );
    });
  }
}