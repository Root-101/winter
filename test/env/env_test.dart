@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The basics of Env: the map, put and find of each type, and the parse errors. require,
/// requireAll, .env files and the messages of the errors are in config_behavior_test.dart.
void main() {
  group('Env', () {
    late Env env;

    setUp(() => env = Env(env: {'START': 'start', 'Test': 'test'}));

    test('find a variable; null when it is not there', () {
      expect(env.find<String>('START'), 'start');
      expect(env.find<String>('start'), isNull);
      expect(env.find<String>('NON_EXISTENT'), isNull);
      expect(env.find<String>('non_existent', caseSensitive: false), isNull);
    });

    test('case-insensitive: the first match, in order of insertion', () {
      final Env twice = Env(env: {'abc': 'value1', 'ABC': 'value2'});

      expect(twice.find<String>('AbC', caseSensitive: false), 'value1');
    });

    test('put adds or replaces a value', () {
      env
        ..put('NEW_KEY', 'new_value')
        ..put('START', 'updated');

      expect(env.find<String>('NEW_KEY'), 'new_value');
      expect(env.find<String>('START'), 'updated');
    });

    test('all is a copy', () {
      final Map<String, String> all = env.all..['TEMP_KEY'] = 'temp';

      expect(all['START'], 'start');
      expect(env.find<String>('TEMP_KEY'), isNull);
    });

    test('the variables of the process, under the ones given', () {
      // PATH is on every platform (Path on Windows)
      expect(env.find<String>('PATH') ?? env.find<String>('Path'), isNotNull);
      expect(Env(env: {'PATH': 'custom'}).find<String>('PATH'), 'custom');
    });

    test('put and find every type', () {
      void roundTrip<T>(T value) {
        expect(env.put<T>('KEY', value), value);
        expect(env.find<T>('KEY'), value, reason: '$T');
      }

      roundTrip<int>(8080);
      roundTrip<double>(1.2);
      roundTrip<bool>(true);
      roundTrip<bool>(false);
      roundTrip<List<String>>(['admin', 'user']);
      roundTrip<List<int>>([1, 2, 3]);
      roundTrip<List<double>>([1.1, 2.2]);
    });
  });

  group('Parsing', () {
    final Env env = Env(
      env: {
        'IDS': '1, 2, 3',
        'BOOLS': 'true, false',
        'NUMS': '1, 2.5',
        'TIMEOUT': '3.7',
        'BOOL': 'yes',
        'WORD': 'abc',
        'BAD_INTS': '1, x',
      },
    );

    test('lists with spaces, of bool and of num', () {
      expect(env.find<List<int>>('IDS'), [1, 2, 3]);
      expect(env.find<List<bool>>('BOOLS'), [true, false]);
      expect(env.find<List<num>>('NUMS'), [1, 2.5]);
    });

    test('a decimal is never truncated to an int', () {
      expect(() => env.find<int>('TIMEOUT'), throwsStateError);
      expect(env.find<double>('TIMEOUT'), 3.7);
      expect(env.find<num>('TIMEOUT'), 3.7);
    });

    test('a value that is not its type is a StateError', () {
      expect(() => env.find<bool>('BOOL'), throwsStateError);
      expect(() => env.find<int>('WORD'), throwsStateError);
      expect(() => env.find<List<int>>('BAD_INTS'), throwsStateError);
    });
  });
}
