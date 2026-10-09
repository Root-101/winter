import 'package:bodies_examples/no_body.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('without a body, and with one', () async {
    expect((await client.post('/ping')).json, {
      'pong': true,
      'options': 'none',
    });
    expect((await client.post('/ping', body: {'verbose': true})).json, {
      'pong': true,
      'options': {'verbose': true},
    });
  });
}
