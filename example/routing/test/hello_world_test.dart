import 'package:routing_examples/hello_world.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  test('GET /hello', () async {
    final response = await WinterTestClient.build(
      router: router(),
    ).get('/hello');

    expect(response.statusCode, 200);
    expect(response.body, 'Hello World');
  });
}
