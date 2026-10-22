/// The object mapper in an obfuscated AOT build, where the names of the types are not the ones of
/// the source: it finds the types by `Type`, never by name (DECISIONS.md §2), so it must work the
/// same. Exits with 1 and the failed checks otherwise.
///
/// ```bash
/// dart compile exe tool/obfuscation/main.dart -o build/obfuscated \
///   --extra-gen-snapshot-options=--obfuscate
/// build/obfuscated --expect-obfuscated
/// ```
library;

import 'dart:io';

import 'package:winter/winter.dart';

import 'item_a.dart' as a;
import 'item_b.dart' as b;

void main(List<String> args) {
  final List<String> failures = [];
  void check(String name, bool Function() passes) {
    try {
      if (!passes()) failures.add(name);
    } catch (error) {
      failures.add('$name ($error)');
    }
  }

  // CI runs it with --expect-obfuscated: a build that isn't obfuscated would prove nothing
  if (args.contains('--expect-obfuscated') && '${a.Item}' == 'Item') {
    failures.add('the build is not obfuscated');
  }

  final ObjectMapper mapper = ObjectMapper(
    deserializers: [
      Deserializer<a.Item>.json(a.Item.fromJson),
      Deserializer<b.Item>.json(b.Item.fromJson),
    ],
  );

  check('generic types', () {
    final List<a.Item> list = mapper.decode<List<a.Item>>('[{"name":"x"}]');
    final Map<String, b.Item> map = mapper.decode<Map<String, b.Item>>(
      '{"k":{"count":2}}',
    );
    final a.Item? missing = mapper.decode<a.Item?>('null');
    return list.single.name == 'x' && map['k']!.count == 2 && missing == null;
  });

  check('two classes with the same name', () {
    final a.Item first = mapper.decode<a.Item>('{"name":"x"}');
    final b.Item second = mapper.decode<b.Item>('{"count":3}');
    final Object? both = mapper.serialize(const [a.Item('y'), b.Item(4)]);
    return first.name == 'x' &&
        second.count == 3 &&
        '$both' == '[{name: y}, {count: 4}]';
  });

  check('a failing fromJson has no obfuscated name in its error', () {
    try {
      mapper.decode<List<a.Item>>('[{"name":"x"},{"name":3}]');
      return false;
    } on DeserializationException catch (error) {
      // The path and a fixed reason: never a type, which obfuscation would rename
      return error.message == r'$[1]: invalid value';
    }
  });

  check('a wrong value names its JSON type, never a Dart one', () {
    try {
      mapper.decode<DateTime>('1');
      return false;
    } on DeserializationException catch (error) {
      return error.message == r'$: expected an ISO-8601 date, got an integer';
    }
  });

  if (failures.isEmpty) {
    stdout.writeln('The object mapper works obfuscated');
    return;
  }
  stderr.writeln('Failed with obfuscation:\n- ${failures.join('\n- ')}');
  exitCode = 1;
}
