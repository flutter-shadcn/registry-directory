import 'dart:convert';
import 'dart:io';

const String _defaultEntriesDir = 'registries/entries';
const String _defaultOutputFile = 'registries/registries.json';

void main(List<String> args) {
  final parsed = _parseArgs(args);
  if (parsed.showHelp) {
    _printUsage();
    exit(0);
  }

  final entriesDir = Directory(parsed.entriesDir);
  if (!entriesDir.existsSync()) {
    stderr.writeln('Error: entries directory not found: ${entriesDir.path}');
    exit(66);
  }

  final entryFiles =
      entriesDir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (entryFiles.isEmpty) {
    stderr.writeln('Error: no entry files found in ${entriesDir.path}');
    exit(65);
  }

  final registries = <Map<String, dynamic>>[];
  for (final file in entryFiles) {
    final decoded = _readJsonObject(file);
    if (decoded['id'] is! String || (decoded['id'] as String).trim().isEmpty) {
      stderr.writeln(
        "Error: entry file '${file.path}' must include a non-empty string 'id'.",
      );
      exit(65);
    }
    registries.add(decoded);
  }

  registries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  _assertUniqueValues(
    values: registries.map((r) => r['id'] as String),
    label: 'registry id',
  );
  _assertUniqueValues(
    values: registries
        .map((r) => r['install'])
        .whereType<Map>()
        .map((i) => i['namespace'])
        .whereType<String>(),
    label: 'install.namespace',
  );
  _assertUniqueValues(
    values: registries
        .map((r) => r['install'])
        .whereType<Map>()
        .map((i) => i['root'])
        .whereType<String>(),
    label: 'install.root',
  );

  final output = <String, dynamic>{
    r'$schema': './registries.schema.json',
    'schemaVersion': 1,
    'registries': registries,
  };

  final outputFile = File(parsed.outputFile);
  if (!outputFile.parent.existsSync()) {
    outputFile.parent.createSync(recursive: true);
  }

  final encoder = const JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync('${encoder.convert(output)}\n');
  stdout.writeln(
    'Generated ${registries.length} registry entries into ${outputFile.path}',
  );
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.entriesDir,
    required this.outputFile,
    required this.showHelp,
  });

  final String entriesDir;
  final String outputFile;
  final bool showHelp;
}

_ParsedArgs _parseArgs(List<String> args) {
  var entriesDir = _defaultEntriesDir;
  var outputFile = _defaultOutputFile;
  var showHelp = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }

    if (arg == '--entries-dir' || arg == '-e') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: missing value for $arg');
        exit(64);
      }
      entriesDir = args[++i];
      continue;
    }

    if (arg == '--output' || arg == '-o') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: missing value for $arg');
        exit(64);
      }
      outputFile = args[++i];
      continue;
    }

    stderr.writeln('Error: unknown argument: $arg');
    _printUsage();
    exit(64);
  }

  return _ParsedArgs(
    entriesDir: entriesDir,
    outputFile: outputFile,
    showHelp: showHelp,
  );
}

Map<String, dynamic> _readJsonObject(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Error: entry file must be a JSON object: ${file.path}');
    exit(65);
  }
  return decoded;
}

void _assertUniqueValues({
  required Iterable<String> values,
  required String label,
}) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isEmpty) continue;
    if (!seen.add(normalized)) {
      duplicates.add(normalized);
    }
  }
  if (duplicates.isNotEmpty) {
    stderr.writeln(
      'Error: duplicate $label values found: ${duplicates.toList()..sort()}',
    );
    exit(65);
  }
}

void _printUsage() {
  stdout.writeln('''
Build registries/registries.json from registries/entries/*.json.

Usage:
  dart run scripts/build_registries.dart [--entries-dir <dir>] [--output <file>]

Flags:
  -e, --entries-dir  Source directory for per-registry JSON entries
                     (default: $_defaultEntriesDir)
  -o, --output       Output registries directory file
                     (default: $_defaultOutputFile)
  -h, --help         Show help
''');
}
