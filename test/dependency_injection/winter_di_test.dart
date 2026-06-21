@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class ServiceA {
  String get name => 'Service A';
}

class ServiceB {
  String get name => 'Service B';
}

void main() {
  group('DependencyInjection', () {
    late DependencyInjection di;

    setUp(() {
      di = DependencyInjection();
    });

    test('put and find', () {
      final service = ServiceA();
      di.put<ServiceA>(service);

      final found = di.find<ServiceA>();
      expect(found, equals(service));

      di.delete<ServiceA>();
    });

    test('put and find with tag', () {
      final service1 = ServiceA();
      final service2 = ServiceA();

      di.put<ServiceA>(service1, tag: 'tag1');
      di.put<ServiceA>(service2, tag: 'tag2');

      expect(di.find<ServiceA>(tag: 'tag1'), equals(service1));
      expect(di.find<ServiceA>(tag: 'tag2'), equals(service2));

      di.delete<ServiceA>(tag: 'tag1');
      di.delete<ServiceA>(tag: 'tag2');
    });

    test('find throws StateError when not found', () {
      expect(() => di.find<ServiceB>(), throwsA(isA<StateError>()));
    });

    test('tryFind returns null when not found', () {
      expect(di.tryFind<ServiceB>(), isNull);
    });

    test('tryFind returns dependency when found', () {
      final service = ServiceA();
      di.put<ServiceA>(service);

      expect(di.tryFind<ServiceA>(), equals(service));

      di.delete<ServiceA>();
    });

    test('delete removes and returns dependency', () {
      final service = ServiceA();
      di.put<ServiceA>(service);

      final deleted = di.delete<ServiceA>();
      expect(deleted, equals(service));
      expect(di.tryFind<ServiceA>(), isNull);
    });

    test('delete throws StateError when not found', () {
      expect(() => di.delete<ServiceB>(), throwsA(isA<StateError>()));
    });

    test('overwrite dependency', () {
      final service1 = ServiceA();
      final service2 = ServiceA();

      di.put<ServiceA>(service1);
      di.put<ServiceA>(service2);

      expect(di.find<ServiceA>(), equals(service2));

      di.delete<ServiceA>();
    });

    test('find different types', () {
      final serviceA = ServiceA();
      final serviceB = ServiceB();

      di.put<ServiceA>(serviceA);
      di.put<ServiceB>(serviceB);

      expect(di.find<ServiceA>(), equals(serviceA));
      expect(di.find<ServiceB>(), equals(serviceB));

      di.delete<ServiceA>();
      di.delete<ServiceB>();
    });

    test('StateError message', () {
      try {
        di.find<ServiceB>(tag: 'my-tag');
        fail('Should have thrown StateError');
      } on StateError catch (e) {
        expect(e.message, contains('<ServiceB>'));
        expect(e.message, contains('with tag: my-tag'));
      }
    });
  });
}
