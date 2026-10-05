import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:basic_server/main.dart';

void main() {
  group('Basic Server Tests', () {
    const int port = 8081;

    setUp(() async {
      await BasicServer.start(port: port);
    });

    tearDown(() async {
      await BasicServer.close();
    });

    test('GET /hello returns 200 and Hello World', () async {
      final response = await http.get(
        Uri.parse('http://localhost:$port/hello'),
      );
      expect(response.statusCode, equals(200));
      expect(response.body, equals('Hello World'));
    });

    test('GET /not-found returns 404', () async {
      final response = await http.get(
        Uri.parse('http://localhost:$port/not-found'),
      );
      expect(response.statusCode, equals(404));
    });
  });
}
