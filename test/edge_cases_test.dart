import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Edge cases of several modules that no behavior test covered
void main() {
  group('Object mapper', () {
    test('a fromJson that asks for a type without deserializer is a 500, not a 400', () {
      final mapper = ObjectMapper(
        deserializers: [
          Deserializer<_Box>.json(
            (json) => _Box(om.deserialize<_Unregistered>(json['value'])),
          ),
        ],
      );

      expect(
        () => mapper.deserialize<_Box>({'value': 1}),
        throwsA(isA<MissingDeserializerError>()),
      );
    });

    test('a DateTime that is not a String says what was expected', () {
      expect(
        () => ObjectMapper().deserialize<DateTime>(20260101),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected an ISO-8601 date, got an integer',
          ),
        ),
      );
    });

    test('an object where a primitive was expected', () {
      expect(
        () => ObjectMapper().deserialize<int>({'a': 1}),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected an integer, got an object',
          ),
        ),
      );
    });

    test('includeNulls: false without fieldNaming keeps the names', () {
      final mapper = ObjectMapper(includeNulls: false);

      expect(mapper.serialize(_Named('ann', null)), {'firstName': 'ann'});
      expect(mapper.jsonFieldName('firstName'), 'firstName');
    });
  });

  group('Env', () {
    test(
      r'a quoted value of a .env file reads \t, \n and an escaped quote',
      () {
        expect(Env.parseDotEnv([r'KEY="a\tb\nc\"d"']), {'KEY': 'a\tb\nc"d'});
      },
    );
  });

  group('RequestEntity', () {
    test('a parameter of the Content-Type without "=" is ignored', () {
      final request = RequestEntity(
        'POST',
        Uri.parse('http://localhost/'),
        headers: {'content-type': 'text/plain; flowed; charset=iso-8859-1'},
      );

      expect(request.encoding?.name, 'iso-8859-1');
    });

    test('a bool query param reads false too', () {
      final request = RequestEntity(
        'GET',
        Uri.parse('http://localhost/?a=false&b=FALSE'),
      );

      expect(request.queryParam<bool>('a'), isFalse);
      expect(request.queryParam<bool>('b'), isFalse);
    });

    test('a path param with an invalid encoding is kept as it is', () async {
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/files/{name}',
              handler: (request) =>
                  ResponseEntity.ok(body: request.pathParams['name']),
            ),
          ],
        ),
      );

      expect((await client.get('/files/a%ZZb')).body, 'a%ZZb');
    });
  });

  group('WinterRouter', () {
    test('called directly, its handler routes the request itself', () async {
      final router = WinterRouter(
        routes: [
          Route.get(
            path: '/a',
            handler: (r) => ResponseEntity.ok(body: 'a'),
          ),
        ],
      );

      final response = await router.handler(
        RequestEntity('GET', Uri.parse('http://localhost/a')),
      );

      expect(await response.readAsString(), 'a');
    });
  });

  group('WinterLocale', () {
    test('is equal only to a locale with the same language and country', () {
      expect(const WinterLocale('es'), const WinterLocale('es'));
      expect(const WinterLocale('es', 'MX'), isNot(const WinterLocale('es')));
      // ignore: unrelated_type_equality_checks
      expect(const WinterLocale('es') == 'es', isFalse);
      expect({
        const WinterLocale('es'),
        WinterLocale.tryParse('es'),
      }, hasLength(1));
    });
  });

  group('ResponseEntity', () {
    test('an encoding of the app is the charset of its text', () {
      final response = ResponseEntity<Map<String, int>>(
        200,
        body: {'a': 1},
        encoding: latin1,
      );

      expect(
        response.headers['content-type'],
        'application/json; charset=iso-8859-1',
      );
    });
  });
}

class _Box {
  final Object? value;

  _Box(this.value);
}

class _Unregistered {}

class _Named {
  final String firstName;
  final String? lastName;

  _Named(this.firstName, this.lastName);

  Map<String, Object?> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
  };
}
