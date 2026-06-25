@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Env', () {
    late Env env;

    setUp(() {
      env = Env(env: {'START': 'start'});
      env.put('Test', 'test');
    });

    /*test('find with default case sensitivity', () {
      expect(env.find('START'), 'start');
      expect(env.find('start'), isNull);
      expect(env.find('Test'), 'test');
    });*/

    test('find with case-insensitive search', () {
      //expect(env.find('start', caseSensitive: false), 'start');
      expect(env.find('TEST', caseSensitive: false), 'test');
    });

    test('find returns null for non-existent keys', () {
      expect(env.find('NON_EXISTENT'), isNull);
      expect(env.find('non_existent', caseSensitive: false), isNull);
    });

    test('put updates existing values and returns the new value', () {
      final result = env.put('START', 'updated_start');
      expect(result, 'updated_start');
      expect(env.find('START'), 'updated_start');
    });

    test('put adds new values', () {
      env.put('NEW_KEY', 'new_value');
      expect(env.find('NEW_KEY'), 'new_value');
    });

    test('all returns a copy of the environment map', () {
      final all = env.all;
      expect(all['START'], 'start');
      expect(all['Test'], 'test');

      // Modify the returned map
      all['TEMP_KEY'] = 'temp';
      // Verify the original Env remains unchanged
      expect(env.find('TEMP_KEY'), isNull);
    });

    test('initializes with Platform.environment', () {
      // PATH is generally available on all platforms
      expect(
        env.find('PATH') ?? env.find('Path') ?? env.find('path'),
        isNotNull,
      );
    });

    test('constructor merges Platform.environment and provided map', () {
      // Overriding a potential existing env var
      final customEnv = Env(env: {'PATH': 'custom_path'});
      expect(customEnv.find('PATH'), 'custom_path');
    });

    test('find returns the first match when case-insensitive', () {
      final customEnv = Env(env: {'abc': 'value1', 'ABC': 'value2'});
      // In Dart, LinkedHashMap preserves insertion order.
      // So 'abc' should be found first.
      expect(customEnv.find('AbC', caseSensitive: false), 'value1');
    });
  });
}
