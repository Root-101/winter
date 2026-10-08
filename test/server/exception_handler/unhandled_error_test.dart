@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class Unserializable {
  final String secret = 'internal-secret';
}

void main() {
  late WinterTestClient client;

  final List<Object> loggedErrors = [];

  setUpAll(() async {
    final objectMapper = ObjectMapper(
      serializers: [
        Serializer<Unserializable>(
          (object) => throw Exception('serializer failed: ${object.secret}'),
        ),
      ],
    );

    Winter.context.setUp(
      objectMapper: objectMapper,
      exceptionHandler: SimpleExceptionHandler(
        logUnhandledError: (request, error, stackTrace) =>
            loggedErrors.add(error),
      ),
    );
    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/error',
            handler: (request) => throw StateError('internal-secret state'),
          ),
          Route.get(
            path: '/exception',
            handler: (request) => throw Exception('internal-secret exception'),
          ),
          Route.get(
            path: '/serialization',
            handler: (request) => ResponseEntity.ok(body: Unserializable()),
          ),
          Route.get(
            path: '/not-found',
            handler: (request) => throw const NotFoundException(),
          ),
        ],
      ),
    );
  });

  setUp(loggedErrors.clear);

  test('Error in handler returns a generic 500 and is logged', () async {
    final response = await client.get('/error');

    expect(response.statusCode, 500);
    expect(
      (jsonDecode(response.body) as Map)['title'],
      'Internal Server Error',
    );
    expect(response.body, isNot(contains('internal-secret')));
    expect(loggedErrors, hasLength(1));
    expect(loggedErrors.single, isA<StateError>());
  });

  test('Unknown exception returns a generic 500 and is logged', () async {
    final response = await client.get('/exception');

    expect(response.statusCode, 500);
    expect(
      (jsonDecode(response.body) as Map)['title'],
      'Internal Server Error',
    );
    expect(response.body, isNot(contains('internal-secret')));
    expect(loggedErrors, hasLength(1));
    expect(loggedErrors.single.toString(), contains('internal-secret'));
  });

  test('Failed response serialization is a 500, not a 400', () async {
    final response = await client.get('/serialization');

    expect(response.statusCode, 500);
    expect(
      (jsonDecode(response.body) as Map)['title'],
      'Internal Server Error',
    );
    expect(response.body, isNot(contains('internal-secret')));
    expect(loggedErrors.single, isA<SerializationException>());
  });

  test('Expected API exceptions are not logged', () async {
    final response = await client.get('/not-found');

    expect(response.statusCode, 404);
    expect(loggedErrors, isEmpty);
  });
}
