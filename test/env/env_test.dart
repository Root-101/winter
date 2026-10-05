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
      expect(env.find<String>('TEST', caseSensitive: false), 'test');
    });

    test('find returns null for non-existent keys', () {
      expect(env.find<String>('NON_EXISTENT'), isNull);
      expect(env.find<String>('non_existent', caseSensitive: false), isNull);
    });

    test('put updates existing values and returns the new value', () {
      final result = env.put('START', 'updated_start');
      expect(result, 'updated_start');
      expect(env.find<String>('START'), 'updated_start');
    });

    test('put adds new values', () {
      env.put('NEW_KEY', 'new_value');
      expect(env.find<String>('NEW_KEY'), 'new_value');
    });

    test('all returns a copy of the environment map', () {
      final all = env.all;
      expect(all['START'], 'start');
      expect(all['Test'], 'test');

      // Modify the returned map
      all['TEMP_KEY'] = 'temp';
      // Verify the original Env remains unchanged
      expect(env.find<String>('TEMP_KEY'), isNull);
    });

    test('initializes with Platform.environment', () {
      // PATH is generally available on all platforms
      expect(
        env.find<String>('PATH') ??
            env.find<String>('Path') ??
            env.find<String>('path'),
        isNotNull,
      );
    });

    test('constructor merges Platform.environment and provided map', () {
      // Overriding a potential existing env var
      final customEnv = Env(env: {'PATH': 'custom_path'});
      expect(customEnv.find<String>('PATH'), 'custom_path');
    });

    test('find returns the first match when case-insensitive', () {
      final customEnv = Env(env: {'abc': 'value1', 'ABC': 'value2'});
      // In Dart, LinkedHashMap preserves insertion order.
      // So 'abc' should be found first.
      expect(customEnv.find<String>('AbC', caseSensitive: false), 'value1');
    });

    group('Type conversions', () {
      test('put and find int', () {
        final result = env.put<int>('PORT', 8080);
        expect(result, 8080);
        expect(env.find<int>('PORT'), 8080);
      });

      test('put and find double', () {
        final result = env.put<double>('VERSION', 1.2);
        expect(result, 1.2);
        expect(env.find<double>('VERSION'), 1.2);
      });

      test('put and find List<String>', () {
        final list = ['admin', 'user', 'guest'];
        final result = env.put<List<String>>('ROLES', list);
        expect(result, list);
        expect(env.find<List<String>>('ROLES'), list);
      });

      test('put and find List<int>', () {
        final list = [1, 2, 3];
        final result = env.put<List<int>>('IDS', list);
        expect(result, list);
        expect(env.find<List<int>>('IDS'), list);
      });

      test('put and find List<double>', () {
        final list = [1.1, 2.2];
        final result = env.put<List<double>>('VALUES', list);
        expect(result, list);
        expect(env.find<List<double>>('VALUES'), list);
      });

      test('put and find bool', () {
        final result = env.put<bool>('DEBUG', true);
        expect(result, true);
        expect(env.find<bool>('DEBUG'), true);

        env.put<bool>('DEBUG', false);
        expect(env.find<bool>('DEBUG'), false);
      });

      test('find List<int> with spaces', () {
        env.put('IDS', '1, 2, 3');
        expect(env.find<List<int>>('IDS'), [1, 2, 3]);
      });

      test('find throws StateError for wrong type', () {
        env.put('NOT_A_NUMBER', 'abc');
        expect(() => env.find<int>('NOT_A_NUMBER'), throwsStateError);
      });

      test('find int with decimals is an error (never truncated)', () {
        env.put('TIMEOUT', '3.7');
        expect(() => env.find<int>('TIMEOUT'), throwsStateError);
        expect(env.find<double>('TIMEOUT'), 3.7);
        expect(env.find<num>('TIMEOUT'), 3.7);
      });

      test('find throws StateError for unsupported type', () {
        env.put('NOW', 'now');
        expect(() => env.find<DateTime>('NOW'), throwsStateError);
      });
    });
  });

  group('Env parsing errors & lists', () {
    final env = Env(
      env: {
        'BOOL': 'yes',
        'BOOLS': 'true, false',
        'NUMS': '1, 2.5',
        'BAD_INTS': '1, x',
      },
    );

    test('a bool must be true or false', () {
      expect(() => env.find<bool>('BOOL'), throwsStateError);
    });

    test('List<bool> & List<num>', () {
      expect(env.find<List<bool>>('BOOLS'), [true, false]);
      expect(env.find<List<num>>('NUMS'), [1, 2.5]);
    });

    test('a list with an invalid item is an error', () {
      expect(() => env.find<List<int>>('BAD_INTS'), throwsStateError);
    });

    test('required: true fails when the env is missing (or blank)', () {
      expect(
        () => env.find<String>('MISSING', required: true),
        throwsStateError,
      );
      expect(env.find<String>('MISSING'), isNull);
    });

    test('an unsupported type is an error', () {
      expect(() => env.find<DateTime>('BOOL'), throwsStateError);
    });
  });
}
