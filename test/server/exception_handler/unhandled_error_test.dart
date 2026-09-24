@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

class Unserializable {
  final String secret = 'internal-secret';
}

void main() {
  int port = 9064;
  String localUrl = 'http://localhost:$port';

  final List<Object> loggedErrors = [];

  setUpAll(() async {
    final objectMapper = ObjectMapper(
      serializers: [
        Serializer<Unserializable>(
          (object) => throw Exception('serializer failed: ${object.secret}'),
        ),
      ],
    );

    await Winter.start(
      config: ServerConfig(port: port),
      context: BuildContext(
        objectMapper: objectMapper,
        exceptionHandler: SimpleExceptionHandler(
          logUnhandledError: (request, error, stackTrace) =>
              loggedErrors.add(error),
        ),
      ),
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
            handler: (request) => throw NotFoundException(),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  setUp(loggedErrors.clear);

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Error in handler returns a generic 500 and is logged', () async {
    final response = await http.get(url('/error'));

    expect(response.statusCode, 500);
    expect(response.body, 'Internal Server Error');
    expect(response.body, isNot(contains('internal-secret')));
    expect(loggedErrors, hasLength(1));
    expect(loggedErrors.single, isA<StateError>());
  });

  test('Unknown exception returns a generic 500 and is logged', () async {
    final response = await http.get(url('/exception'));

    expect(response.statusCode, 500);
    expect(response.body, 'Internal Server Error');
    expect(response.body, isNot(contains('internal-secret')));
    expect(loggedErrors, hasLength(1));
    expect(loggedErrors.single.toString(), contains('internal-secret'));
  });

  test('Failed response serialization is a 500, not a 400', () async {
    final response = await http.get(url('/serialization'));

    expect(response.statusCode, 500);
    expect(response.body, 'Internal Server Error');
    expect(response.body, isNot(contains('internal-secret')));
    expect(loggedErrors.single, isA<SerializationException>());
  });

  test('Expected API exceptions are not logged', () async {
    final response = await http.get(url('/not-found'));

    expect(response.statusCode, 404);
    expect(loggedErrors, isEmpty);
  });
}
