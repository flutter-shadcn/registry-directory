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
  final outputFile = File(outputArg);
  final outputAbs = _normalizePath(outputFile.absolute.path);
  final schemaFile = File(schemaArg);
  if (!schemaFile.existsSync()) {
    stderr.writeln('Error: schema file does not exist: $schemaArg');
    exit(66);
  }

  final files = <String>[];
  await for (final entity in folder.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;

    final fileAbs = _normalizePath(entity.absolute.path);

    // Avoid listing the output file itself if it lives inside the scanned folder.
    if (fileAbs == outputAbs) continue;

    final relative = _toRelativeFilePath(fileAbs, folderAbs);
    files.add(relative);
  }

  files.sort();

  final jsonMap = <String, Object>{
    r'$schema': './index.files.schema.v1.json',
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'files': files,
  };

  final schemaJson = _readJsonObject(schemaFile);
  final validationErrors = _validateIndexAgainstSchema(
    data: jsonMap,
    schema: schemaJson,
  );
  if (validationErrors.isNotEmpty) {
    stderr.writeln('Validation failed against schema: $schemaArg');
    for (final error in validationErrors) {
      stderr.writeln('- $error');
    }
    exit(65);
  }

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
    this.showHelp = false,
  });

  final String? folder;
  final String? output;
  final String? schema;
  final bool showHelp;
}

_ParsedArgs _parseArgs(List<String> args) {
  String? folder;
  String? output;
  String? schema;
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

    stderr.writeln('Error: unknown argument: $arg');
    _printUsage();
    exit(64);
  }

  return _ParsedArgs(
    folder: folder,
    output: output,
    schema: schema,
    showHelp: showHelp,
  );
}

String _normalizePath(String path) {
  return path.replaceAll('\\', '/');
}

String _toRelativeFilePath(String fileAbs, String folderAbs) {
  final normalizedFolder = folderAbs.endsWith('/')
      ? folderAbs
      : '$folderAbs/';

  if (fileAbs.startsWith(normalizedFolder)) {
    return fileAbs.substring(normalizedFolder.length);
  }

  final fileUri = Uri.file(fileAbs);
  final folderUri = Uri.directory(normalizedFolder);
  return fileUri.pathSegments.isEmpty
      ? ''
      : Uri.decodeComponent(
          Uri(
            pathSegments: fileUri.pathSegments,
          ).path,
        ).replaceFirst(folderUri.path, '');
}

void _printUsage() {
  stdout.writeln('''
Generate an index JSON file containing all files under a folder.

Usage:
  dart run scripts/generate_index.dart --folder <path> --output <file> [--schema <file>]

Flags:
  -f, --folder   Folder to scan recursively
  -o, --output   Output JSON file path
  -s, --schema   Schema JSON path (default: $_defaultSchemaPath)
  -h, --help     Show help
''');
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

  final requiredKeys =
      (schema['required'] is List) ? (schema['required'] as List) : const [];
  for (final key in requiredKeys) {
    if (key is String && !data.containsKey(key)) {
      errors.add("Missing required property '$key'.");
    }
  }

  final properties =
      (schema['properties'] is Map<String, dynamic>)
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
  if (expectedSchemaVersion != null && actualSchemaVersion != expectedSchemaVersion) {
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

  final filesSchema =
      properties['files'] is Map<String, dynamic>
          ? properties['files'] as Map<String, dynamic>
          : const <String, dynamic>{};
  final minItems = filesSchema['minItems'];
  final maxItems = filesSchema['maxItems'];
  final uniqueItems = filesSchema['uniqueItems'] == true;
  final itemSchema =
      filesSchema['items'] is Map<String, dynamic>
          ? filesSchema['items'] as Map<String, dynamic>
          : const <String, dynamic>{};

  final itemRef = itemSchema[r'$ref'];
  Map<String, dynamic> resolvedItemSchema = itemSchema;
  if (itemRef is String && itemRef.startsWith(r'#/$defs/')) {
    final defName = itemRef.substring(r'#/$defs/'.length);
    final defs =
        (schema[r'$defs'] is Map<String, dynamic>)
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
