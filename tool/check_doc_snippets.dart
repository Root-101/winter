/// Analyzes the Dart snippets of the docs (`README.md` and `doc/*.md`) against the API of Winter,
/// so a renamed class or parameter can't stay in a guide. Exits with 1 when one is wrong.
///
/// ```bash
/// dart run tool/check_doc_snippets.dart
/// ```
///
/// - A **program** (a snippet that imports `package:winter/winter.dart`) is analyzed as it is.
/// - A **fragment** (most of them: a route, a call, a class) uses names of an app that the guide
///   doesn't define (`User`, `store`, `request`). It's tried at the top level, in a function, in a
///   list and as an argument; the first way that parses is analyzed, and only an error about Winter
///   counts (a parameter, a method or a type that doesn't exist), never an unknown name of the app.
///   A fragment that parses in no way (`routes: [...]`) is skipped.
library;

import 'dart:io';

/// The errors of a fragment that come from the names of the app it doesn't define
const Set<String> _appNames = {
  'undefined_identifier',
  'undefined_class',
  'undefined_function',
  'undefined_prefixed_name',
  'creation_with_non_type',
  'non_type_as_type_argument',
  'not_a_type',
  'cast_to_non_type',
  'extends_non_class',
  'implements_non_class',
  'mixin_of_non_class',
  'undefined_annotation',
  'new_with_non_type',
  'type_test_with_undefined_name',
  // A member of an extension that depends on a type the fragment doesn't define
  'ambiguous_extension_member_access',
  // The fields of a class shown without its constructor
  'final_not_initialized',
  'new_with_undefined_constructor_default',
  // The package of the app itself (`package:todo_api/...`)
  'uri_does_not_exist',
};

const String _imports = '''
// ignore_for_file: type=lint, unused_import, unused_element, unused_local_variable, dead_code
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:winter/winter.dart';
''';

/// The ways a fragment is tried, in order
final List<String Function(String code)> _ways = [
  // First in a function: a statement with `await` would be an error at the top level
  (code) => '$_imports\nFuture<Object?> snippet() async {\n$code\n}\n',
  (code) => '$_imports\n$code\n',
  (code) => '$_imports\nfinal Object snippet = [\n$code\n];\n',
];

class _Snippet {
  final String doc;
  final int line;
  final String code;

  _Snippet(this.doc, this.line, this.code);

  bool get isProgram => code.contains("import 'package:winter/winter.dart'");

  @override
  String toString() => '$doc:$line';
}

class _Diagnostic {
  final String severity;
  final String type;
  final String code;
  final String file;
  final String message;

  _Diagnostic(this.severity, this.type, this.code, this.file, this.message);
}

Future<void> main() async {
  final Directory root = Directory.current;
  final List<_Snippet> snippets = [
    for (final File doc in [
      File('${root.path}/README.md'),
      ...Directory('${root.path}/doc')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md')),
    ])
      ..._snippetsOf(doc, root),
  ];

  final Directory package = Directory.systemTemp.createTempSync('doc_snippets');
  try {
    File('${package.path}/pubspec.yaml').writeAsStringSync('''
name: doc_snippets
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  test: any
  winter:
    path: ${root.absolute.path.replaceAll(r'\', '/')}
''');
    File('${package.path}/analysis_options.yaml').writeAsStringSync('');
    final Directory lib = Directory('${package.path}/lib')..createSync();
    for (var i = 0; i < snippets.length; i++) {
      final _Snippet snippet = snippets[i];
      if (snippet.isProgram) {
        File('${lib.path}/s${i}_program.dart').writeAsStringSync(snippet.code);
      } else {
        for (var way = 0; way < _ways.length; way++) {
          File('${lib.path}/s${i}_way$way.dart')
              .writeAsStringSync(_ways[way](snippet.code));
        }
      }
    }

    final String dart = Platform.resolvedExecutable;
    final ProcessResult get = await Process.run(dart, [
      'pub',
      'get',
      '--offline',
    ], workingDirectory: package.path);
    if (get.exitCode != 0) {
      stderr.writeln('pub get failed:\n${get.stderr}');
      exitCode = 1;
      return;
    }
    final ProcessResult analysis = await Process.run(dart, [
      'analyze',
      '--format=machine',
      'lib',
    ], workingDirectory: package.path);
    final List<_Diagnostic> diagnostics = [
      for (final String line in '${analysis.stderr}\n${analysis.stdout}'.split(
        '\n',
      ))
        if (_parse(line) case final _Diagnostic diagnostic) diagnostic,
    ];
    Iterable<_Diagnostic> of(String file) => diagnostics.where(
      (d) => d.file.endsWith('${Platform.pathSeparator}$file'),
    );

    final List<String> wrong = [];
    var checked = 0;
    var skipped = 0;
    for (var i = 0; i < snippets.length; i++) {
      final _Snippet snippet = snippets[i];
      if (snippet.isProgram) {
        checked++;
        for (final _Diagnostic d in _apiErrors(
          of('s${i}_program.dart').toList(),
        )) {
          // A program may use a class of the app too (`Login`): the same rule as a fragment
          wrong.add('$snippet: ${d.message} (${d.code})');
        }
        continue;
      }
      List<_Diagnostic> errorsOf(int way) =>
          _apiErrors(of('s${i}_way$way.dart').toList());
      // Of the ways that parse, the one with the fewest errors: one of the API is in all of them,
      // one of the wrapping (a function used before it's declared inside a body) only in some
      final List<List<_Diagnostic>> parsed = [
        for (var way = 0; way < _ways.length; way++)
          if (of('s${i}_way$way.dart')
              .every((d) => d.type != 'SYNTACTIC_ERROR'))
            errorsOf(way),
      ];
      if (parsed.isEmpty) {
        skipped++;
        continue;
      }
      checked++;
      parsed.sort((a, b) => a.length.compareTo(b.length));
      for (final _Diagnostic d in parsed.first) {
        wrong.add('$snippet: ${d.message} (${d.code})');
      }
    }

    stdout.writeln(
      '${snippets.length} snippets: $checked analyzed, $skipped fragments that '
      "don't parse alone (skipped)",
    );
    if (wrong.isEmpty) return;
    stderr.writeln('Snippets that use the API wrong:\n- ${wrong.join('\n- ')}');
    exitCode = 1;
  } finally {
    package.deleteSync(recursive: true);
  }
}

/// The errors of [diagnostics] (one file) that come from Winter, not from the app: never an
/// unknown name of the app, nor the `null` a parameter typed by one of its classes seems to be
List<_Diagnostic> _apiErrors(List<_Diagnostic> diagnostics) {
  final bool appTypes = diagnostics.any((d) => _appNames.contains(d.code));
  return [
    for (final _Diagnostic d in diagnostics)
      if (d.severity == 'ERROR' &&
          !_appNames.contains(d.code) &&
          !(appTypes &&
              d.code == 'unchecked_use_of_nullable_value' &&
              d.message.contains("the receiver can be 'null'")))
        d,
  ];
}

/// The ```dart blocks of [doc], with the line where each one starts
Iterable<_Snippet> _snippetsOf(File doc, Directory root) sync* {
  final List<String> lines = doc.readAsLinesSync();
  final String name = doc.path
      .substring(root.path.length + 1)
      .replaceAll(r'\', '/');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() != '```dart') continue;
    final int start = i + 1;
    final int end = lines.indexWhere((line) => line.trim() == '```', start);
    if (end < 0) return;
    yield _Snippet(name, start, lines.sublist(start, end).join('\n'));
    i = end;
  }
}

/// A line of `dart analyze --format=machine`:
/// `SEVERITY|TYPE|CODE|file|line|column|length|message`
_Diagnostic? _parse(String line) {
  final List<String> parts = line.trim().split('|');
  if (parts.length < 8) return null;
  return _Diagnostic(
    parts[0],
    parts[1],
    parts[2].toLowerCase(),
    parts[3],
    parts.sublist(7).join('|'),
  );
}
