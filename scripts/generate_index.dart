import 'dart:convert';
import 'dart:io';

const String _defaultSchemaPath =
    '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/index.files.schema.v1.json';

void main(List<String> args) async {
  final parsed = _parseArgs(args);

  if (parsed.showHelp) {
    _printUsage();
    exit(0);
  }

  final folderArg = parsed.folder;
  final outputArg = parsed.output;
  final schemaArg = parsed.schema ?? _defaultSchemaPath;
  final perFolder = parsed.perFolder;
  final topLevelOnly = parsed.topLevelOnly;
  final remove = parsed.remove;
  final excludeMatcher = _buildExcludeMatcher(parsed.excludes);

  if (folderArg == null || outputArg == null) {
    stderr.writeln('Error: both --folder and --output are required.');
    _printUsage();
    exit(64);
  }

  final folder = Directory(folderArg);
  if (!folder.existsSync()) {
    stderr.writeln('Error: folder does not exist: $folderArg');
    exit(66);
  }

  final folderAbs = _normalizePath(folder.absolute.path);
  if (remove) {
    if (perFolder) {
      final outputRoot = _resolveOutputRootDirectory(
        outputArg,
        createIfMissing: false,
      );
      final removed = topLevelOnly
          ? await _removeTopLevelIndexes(
              sourceRoot: folder,
              outputRoot: outputRoot,
              rootAbs: folderAbs,
            )
          : await _removePerFolderIndexes(
              sourceRoot: folder,
              outputRoot: outputRoot,
              rootAbs: folderAbs,
            );
      stdout.writeln(
        'Removed $removed index.json files under ${outputRoot.path}',
      );
      return;
    }

    final outputFile = _resolveOutputFile(outputArg);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
      stdout.writeln('Removed ${outputFile.path}');
    } else {
      stdout.writeln('No index file found at ${outputFile.path}');
    }
    return;
  }

  final schemaFile = File(schemaArg);
  if (!schemaFile.existsSync()) {
    stderr.writeln('Error: schema file does not exist: $schemaArg');
    exit(66);
  }

  final schemaJson = _readJsonObject(schemaFile);
  final schemaRef = _resolveSchemaRef(schemaJson);

  if (perFolder) {
    final outputRoot = _resolveOutputRootDirectory(outputArg);
    final generated = topLevelOnly
        ? await _generateTopLevelIndexes(
            sourceRoot: folder,
            outputRoot: outputRoot,
            rootAbs: folderAbs,
            schemaArg: schemaArg,
            schemaJson: schemaJson,
            schemaRef: schemaRef,
            excludeMatcher: excludeMatcher,
          )
        : await _generatePerFolderIndexes(
            sourceRoot: folder,
            outputRoot: outputRoot,
            rootAbs: folderAbs,
            schemaArg: schemaArg,
            schemaJson: schemaJson,
            schemaRef: schemaRef,
            excludeMatcher: excludeMatcher,
          );
    stdout.writeln(
      'Generated $generated index.json files under ${outputRoot.path} (validated)',
    );
    return;
  }

  final outputFile = _resolveOutputFile(outputArg);
  final outputAbs = _normalizePath(outputFile.absolute.path);

  final files = await _collectRelativeFiles(
    sourceDir: folder,
    sourceAbs: folderAbs,
    excludedAbsolutePaths: {outputAbs},
    excludeMatcher: excludeMatcher,
  );

  final jsonMap = _buildIndexJson(schemaRef: schemaRef, files: files);

  _validateOrExit(data: jsonMap, schemaJson: schemaJson, schemaArg: schemaArg);

  if (!outputFile.parent.existsSync()) {
    outputFile.parent.createSync(recursive: true);
  }

  final encoder = const JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync('${encoder.convert(jsonMap)}\n');

  stdout.writeln(
    'Generated ${files.length} file entries in ${outputFile.path} (validated)',
  );
}

class _ParsedArgs {
  const _ParsedArgs({
    this.folder,
    this.output,
    this.schema,
    this.perFolder = false,
    this.topLevelOnly = false,
    this.remove = false,
    this.excludes = const [],
    this.showHelp = false,
  });

  final String? folder;
  final String? output;
  final String? schema;
  final bool perFolder;
  final bool topLevelOnly;
  final bool remove;
  final List<String> excludes;
  final bool showHelp;
}

_ParsedArgs _parseArgs(List<String> args) {
  String? folder;
  String? output;
  String? schema;
  var perFolder = false;
  var topLevelOnly = false;
  var remove = false;
  final excludes = <String>[];
  var showHelp = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }

    if (arg == '--folder' || arg == '-f') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: missing value for $arg');
        exit(64);
      }
      folder = args[++i];
      continue;
    }

    if (arg == '--output' || arg == '-o') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: missing value for $arg');
        exit(64);
      }
      output = args[++i];
      continue;
    }

    if (arg == '--schema' || arg == '-s') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: missing value for $arg');
        exit(64);
      }
      schema = args[++i];
      continue;
    }

    if (arg == '--per-folder' || arg == '-p') {
      perFolder = true;
      continue;
    }

    if (arg == '--top-level-only' || arg == '-t') {
      topLevelOnly = true;
      perFolder = true;
      continue;
    }

    if (arg == '--remove' || arg == '-r') {
      remove = true;
      continue;
    }

    if (arg.startsWith('--exclude=')) {
      _addExcludeValues(excludes, arg.substring('--exclude='.length));
      continue;
    }

    if (arg.startsWith('-x=')) {
      _addExcludeValues(excludes, arg.substring('-x='.length));
      continue;
    }

    if (arg == '--exclude' || arg == '-x') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: missing value for $arg');
        exit(64);
      }
      i++;
      while (i < args.length) {
        final value = args[i];
        if (value.startsWith('-')) {
          i--;
          break;
        }
        _addExcludeValues(excludes, value);
        i++;
      }
      continue;
    }

    stderr.writeln('Error: unknown argument: $arg');
    _printUsage();
    exit(64);
  }

  return _ParsedArgs(
    folder: folder,
    output: output,
    schema: schema,
    perFolder: perFolder,
    topLevelOnly: topLevelOnly,
    remove: remove,
    excludes: excludes,
    showHelp: showHelp,
  );
}

String _normalizePath(String path) {
  return path.replaceAll('\\', '/');
}

String _toRelativeFilePath(String fileAbs, String folderAbs) {
  final normalizedFolder = folderAbs.endsWith('/') ? folderAbs : '$folderAbs/';

  if (fileAbs.startsWith(normalizedFolder)) {
    return fileAbs.substring(normalizedFolder.length);
  }

  final fileUri = Uri.file(fileAbs);
  final folderUri = Uri.directory(normalizedFolder);
  return fileUri.pathSegments.isEmpty
      ? ''
      : Uri.decodeComponent(
          Uri(pathSegments: fileUri.pathSegments).path,
        ).replaceFirst(folderUri.path, '');
}

void _printUsage() {
  stdout.writeln('''
Generate an index JSON file containing all files under a folder.

Usage:
  dart run scripts/generate_index.dart --folder <path> --output <file|dir> [--schema <file>] [--per-folder] [--top-level-only] [--remove] [--exclude <pattern> ...]

Flags:
  -f, --folder   Folder to scan recursively
  -o, --output   Output JSON file path (or directory; writes index.json inside)
  -s, --schema   Schema JSON path (default: $_defaultSchemaPath)
  -p, --per-folder  Generate separate index.json in each folder recursively
  -t, --top-level-only  With --per-folder mode: generate one index.json per immediate child folder only
  -r, --remove   Remove index.json files using the selected mode instead of generating
  -x, --exclude  Exclude files. Default is contains match.
                 Use 'exact:<path>' for exact match.
                 Supports repeated, comma-separated, or multi-value usage.
                 Examples:
                 -x README.md -x exact:fonts/README.md
                 --exclude README.md,exact:fonts/README.md
                 --exclude README.md fonts/README.md
  -h, --help     Show help
''');
}

void _addExcludeValues(List<String> excludes, String raw) {
  for (final part in raw.split(',')) {
    final value = part.trim();
    if (value.isNotEmpty) {
      excludes.add(value);
    }
  }
}

String _resolveSchemaRef(Map<String, dynamic> schemaJson) {
  final schemaId = schemaJson[r'$id'];
  if (schemaId is String && schemaId.trim().isNotEmpty) {
    return schemaId;
  }
  return './index.files.schema.v1.json';
}

File _resolveOutputFile(String outputArg) {
  final trimmed = outputArg.trim();
  final entityType = FileSystemEntity.typeSync(trimmed, followLinks: true);

  if (entityType == FileSystemEntityType.directory) {
    final dirPath = _normalizePath(Directory(trimmed).path);
    return File('$dirPath/index.json');
  }

  if (trimmed.endsWith('/') || trimmed.endsWith(r'\')) {
    final clean = trimmed.replaceAll(RegExp(r'[\\/]+$'), '');
    final dir = Directory(clean);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final dirPath = _normalizePath(dir.path);
    return File('$dirPath/index.json');
  }

  return File(trimmed);
}

Directory _resolveOutputRootDirectory(
  String outputArg, {
  bool createIfMissing = true,
}) {
  final trimmed = outputArg.trim();
  final entityType = FileSystemEntity.typeSync(trimmed, followLinks: true);

  if (entityType == FileSystemEntityType.file) {
    stderr.writeln(
      'Error: --per-folder expects --output to be a directory, got file: $trimmed',
    );
    exit(64);
  }

  if (trimmed.endsWith('.json')) {
    stderr.writeln(
      'Error: --per-folder expects --output to be a directory, got: $trimmed',
    );
    exit(64);
  }

  final dir = Directory(trimmed);
  if (!dir.existsSync() && createIfMissing) {
    dir.createSync(recursive: true);
  }
  return dir;
}

Map<String, dynamic> _readJsonObject(File file) {
  final content = file.readAsStringSync();
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Error: schema root must be a JSON object: ${file.path}');
    exit(65);
  }
  return decoded;
}

List<String> _validateIndexAgainstSchema({
  required Map<String, Object> data,
  required Map<String, dynamic> schema,
}) {
  final errors = <String>[];

  final requiredKeys = (schema['required'] is List)
      ? (schema['required'] as List)
      : const [];
  for (final key in requiredKeys) {
    if (key is String && !data.containsKey(key)) {
      errors.add("Missing required property '$key'.");
    }
  }

  final properties = (schema['properties'] is Map<String, dynamic>)
      ? (schema['properties'] as Map<String, dynamic>)
      : const <String, dynamic>{};

  final additionalProperties = schema['additionalProperties'];
  if (additionalProperties == false) {
    for (final key in data.keys) {
      if (!properties.containsKey(key)) {
        errors.add("Unexpected property '$key'.");
      }
    }
  }

  final schemaVersionSchema =
      properties['schemaVersion'] is Map<String, dynamic>
      ? properties['schemaVersion'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final expectedSchemaVersion = schemaVersionSchema['const'];
  final actualSchemaVersion = data['schemaVersion'];
  if (expectedSchemaVersion != null &&
      actualSchemaVersion != expectedSchemaVersion) {
    errors.add(
      "schemaVersion must be $expectedSchemaVersion, got $actualSchemaVersion.",
    );
  }

  final generatedAt = data['generatedAt'];
  if (generatedAt != null) {
    if (generatedAt is! String || DateTime.tryParse(generatedAt) == null) {
      errors.add("generatedAt must be a valid date-time string.");
    }
  }

  final files = data['files'];
  if (files is! List) {
    errors.add("files must be an array.");
    return errors;
  }

  final filesSchema = properties['files'] is Map<String, dynamic>
      ? properties['files'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final minItems = filesSchema['minItems'];
  final maxItems = filesSchema['maxItems'];
  final uniqueItems = filesSchema['uniqueItems'] == true;
  final itemSchema = filesSchema['items'] is Map<String, dynamic>
      ? filesSchema['items'] as Map<String, dynamic>
      : const <String, dynamic>{};

  final itemRef = itemSchema[r'$ref'];
  Map<String, dynamic> resolvedItemSchema = itemSchema;
  if (itemRef is String && itemRef.startsWith(r'#/$defs/')) {
    final defName = itemRef.substring(r'#/$defs/'.length);
    final defs = (schema[r'$defs'] is Map<String, dynamic>)
        ? schema[r'$defs'] as Map<String, dynamic>
        : const <String, dynamic>{};
    if (defs[defName] is Map<String, dynamic>) {
      resolvedItemSchema = defs[defName] as Map<String, dynamic>;
    }
  }

  if (minItems is int && files.length < minItems) {
    errors.add("files must contain at least $minItems items.");
  }
  if (maxItems is int && files.length > maxItems) {
    errors.add("files must contain at most $maxItems items.");
  }

  if (uniqueItems) {
    final seen = <String>{};
    for (final item in files) {
      if (item is String) {
        if (!seen.add(item)) {
          errors.add("files contains duplicate entry '$item'.");
          break;
        }
      }
    }
  }

  final minLength = resolvedItemSchema['minLength'];
  final maxLength = resolvedItemSchema['maxLength'];
  final pattern = resolvedItemSchema['pattern'];
  final regex = pattern is String ? RegExp(pattern) : null;

  for (final item in files) {
    if (item is! String) {
      errors.add("files items must be strings.");
      continue;
    }
    if (minLength is int && item.length < minLength) {
      errors.add("files item '$item' is shorter than $minLength.");
    }
    if (maxLength is int && item.length > maxLength) {
      errors.add("files item '$item' is longer than $maxLength.");
    }
    if (regex != null && !regex.hasMatch(item)) {
      errors.add("files item '$item' does not match required path pattern.");
    }
  }

  return errors;
}

Map<String, Object> _buildIndexJson({
  required String schemaRef,
  required List<String> files,
}) {
  return <String, Object>{
    r'$schema': schemaRef,
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'files': files,
  };
}

void _validateOrExit({
  required Map<String, Object> data,
  required Map<String, dynamic> schemaJson,
  required String schemaArg,
}) {
  final validationErrors = _validateIndexAgainstSchema(
    data: data,
    schema: schemaJson,
  );
  if (validationErrors.isEmpty) return;

  stderr.writeln('Validation failed against schema: $schemaArg');
  for (final error in validationErrors) {
    stderr.writeln('- $error');
  }
  exit(65);
}

Future<List<String>> _collectRelativeFiles({
  required Directory sourceDir,
  required String sourceAbs,
  required Set<String> excludedAbsolutePaths,
  required _ExcludeMatcher excludeMatcher,
}) async {
  final files = <String>[];
  await for (final entity in sourceDir.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;

    final fileAbs = _normalizePath(entity.absolute.path);
    if (excludedAbsolutePaths.contains(fileAbs)) continue;

    final relative = _toRelativeFilePath(fileAbs, sourceAbs);
    if (excludeMatcher.matches(relative)) continue;
    files.add(relative);
  }
  files.sort();
  return files;
}

Future<int> _generatePerFolderIndexes({
  required Directory sourceRoot,
  required Directory outputRoot,
  required String rootAbs,
  required String schemaArg,
  required Map<String, dynamic> schemaJson,
  required String schemaRef,
  required _ExcludeMatcher excludeMatcher,
}) async {
  final sourceDirs = await _listDirectoriesRecursive(sourceRoot);
  final outputPathsBySourceDir = <String, String>{};

  for (final dir in sourceDirs) {
    final dirAbs = _normalizePath(dir.absolute.path);
    final relativeDir = _toRelativeDirPath(dirAbs, rootAbs);
    final outDirPath = relativeDir.isEmpty
        ? _normalizePath(outputRoot.path)
        : '${_normalizePath(outputRoot.path)}/$relativeDir';
    final outFilePath = _normalizePath('$outDirPath/index.json');
    outputPathsBySourceDir[dirAbs] = _normalizePath(
      File(outFilePath).absolute.path,
    );
  }

  final allOutputPaths = outputPathsBySourceDir.values.toSet();
  var generatedCount = 0;
  final encoder = const JsonEncoder.withIndent('  ');

  for (final dir in sourceDirs) {
    final dirAbs = _normalizePath(dir.absolute.path);
    final outPath = outputPathsBySourceDir[dirAbs]!;
    final outFile = File(outPath);

    final files = await _collectRelativeFiles(
      sourceDir: dir,
      sourceAbs: rootAbs,
      excludedAbsolutePaths: allOutputPaths,
      excludeMatcher: excludeMatcher,
    );

    // Skip empty folders because schema requires files.minItems >= 1.
    if (files.isEmpty) {
      continue;
    }

    final jsonMap = _buildIndexJson(schemaRef: schemaRef, files: files);
    _validateOrExit(
      data: jsonMap,
      schemaJson: schemaJson,
      schemaArg: schemaArg,
    );

    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    outFile.writeAsStringSync('${encoder.convert(jsonMap)}\n');
    generatedCount++;
  }

  return generatedCount;
}

Future<int> _removePerFolderIndexes({
  required Directory sourceRoot,
  required Directory outputRoot,
  required String rootAbs,
}) async {
  final sourceDirs = await _listDirectoriesRecursive(sourceRoot);
  final outputPaths = _buildOutputPathsForSourceDirs(
    sourceDirs: sourceDirs,
    outputRoot: outputRoot,
    rootAbs: rootAbs,
  );
  return _removeExistingFiles(outputPaths);
}

Future<int> _generateTopLevelIndexes({
  required Directory sourceRoot,
  required Directory outputRoot,
  required String rootAbs,
  required String schemaArg,
  required Map<String, dynamic> schemaJson,
  required String schemaRef,
  required _ExcludeMatcher excludeMatcher,
}) async {
  final sourceDirs = await _listTopLevelDirectories(sourceRoot);
  final outputPathsBySourceDir = <String, String>{};

  for (final dir in sourceDirs) {
    final dirAbs = _normalizePath(dir.absolute.path);
    final relativeDir = _toRelativeDirPath(dirAbs, rootAbs);
    final outDirPath = relativeDir.isEmpty
        ? _normalizePath(outputRoot.path)
        : '${_normalizePath(outputRoot.path)}/$relativeDir';
    final outFilePath = _normalizePath('$outDirPath/index.json');
    outputPathsBySourceDir[dirAbs] = _normalizePath(
      File(outFilePath).absolute.path,
    );
  }

  final allOutputPaths = outputPathsBySourceDir.values.toSet();
  var generatedCount = 0;
  final encoder = const JsonEncoder.withIndent('  ');

  for (final dir in sourceDirs) {
    final dirAbs = _normalizePath(dir.absolute.path);
    final outPath = outputPathsBySourceDir[dirAbs]!;
    final outFile = File(outPath);

    final files = await _collectRelativeFiles(
      sourceDir: dir,
      sourceAbs: rootAbs,
      excludedAbsolutePaths: allOutputPaths,
      excludeMatcher: excludeMatcher,
    );

    if (files.isEmpty) {
      continue;
    }

    final jsonMap = _buildIndexJson(schemaRef: schemaRef, files: files);
    _validateOrExit(
      data: jsonMap,
      schemaJson: schemaJson,
      schemaArg: schemaArg,
    );

    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    outFile.writeAsStringSync('${encoder.convert(jsonMap)}\n');
    generatedCount++;
  }

  return generatedCount;
}

Future<int> _removeTopLevelIndexes({
  required Directory sourceRoot,
  required Directory outputRoot,
  required String rootAbs,
}) async {
  final sourceDirs = await _listTopLevelDirectories(sourceRoot);
  final outputPaths = _buildOutputPathsForSourceDirs(
    sourceDirs: sourceDirs,
    outputRoot: outputRoot,
    rootAbs: rootAbs,
  );
  return _removeExistingFiles(outputPaths);
}

Future<List<Directory>> _listDirectoriesRecursive(Directory root) async {
  final dirs = <Directory>[root];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is Directory) {
      dirs.add(entity);
    }
  }
  dirs.sort((a, b) => _normalizePath(a.path).compareTo(_normalizePath(b.path)));
  return dirs;
}

Future<List<Directory>> _listTopLevelDirectories(Directory root) async {
  final dirs = <Directory>[];
  await for (final entity in root.list(recursive: false, followLinks: false)) {
    if (entity is Directory) {
      dirs.add(entity);
    }
  }
  dirs.sort((a, b) => _normalizePath(a.path).compareTo(_normalizePath(b.path)));
  return dirs;
}

String _toRelativeDirPath(String dirAbs, String rootAbs) {
  final normalizedRoot = rootAbs.endsWith('/') ? rootAbs : '$rootAbs/';
  if (dirAbs == rootAbs) return '';
  if (dirAbs.startsWith(normalizedRoot)) {
    return dirAbs.substring(normalizedRoot.length);
  }
  return '';
}

Set<String> _buildOutputPathsForSourceDirs({
  required List<Directory> sourceDirs,
  required Directory outputRoot,
  required String rootAbs,
}) {
  final outputPaths = <String>{};
  for (final dir in sourceDirs) {
    final dirAbs = _normalizePath(dir.absolute.path);
    final relativeDir = _toRelativeDirPath(dirAbs, rootAbs);
    final outDirPath = relativeDir.isEmpty
        ? _normalizePath(outputRoot.path)
        : '${_normalizePath(outputRoot.path)}/$relativeDir';
    final outFilePath = _normalizePath('$outDirPath/index.json');
    outputPaths.add(_normalizePath(File(outFilePath).absolute.path));
  }
  return outputPaths;
}

int _removeExistingFiles(Set<String> outputPaths) {
  var removed = 0;
  for (final path in outputPaths) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
      removed++;
    }
  }
  return removed;
}

class _ExcludeMatcher {
  const _ExcludeMatcher({
    required this.containsPatterns,
    required this.exactPatterns,
  });

  final List<String> containsPatterns;
  final Set<String> exactPatterns;

  bool matches(String relativePath) {
    if (exactPatterns.contains(relativePath)) {
      return true;
    }
    for (final pattern in containsPatterns) {
      if (pattern.isNotEmpty && relativePath.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}

_ExcludeMatcher _buildExcludeMatcher(List<String> rawPatterns) {
  final contains = <String>[];
  final exact = <String>{};

  for (final raw in rawPatterns) {
    final value = raw.trim();
    if (value.isEmpty) continue;

    if (value.startsWith('exact:')) {
      final p = value.substring('exact:'.length).trim();
      if (p.isNotEmpty) exact.add(p);
      continue;
    }

    if (value.startsWith('contains:')) {
      final p = value.substring('contains:'.length).trim();
      if (p.isNotEmpty) contains.add(p);
      continue;
    }

    contains.add(value);
  }

  return _ExcludeMatcher(containsPatterns: contains, exactPatterns: exact);
}
