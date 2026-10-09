import 'dart:convert';

import 'package:security_examples/webhook_signature.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 9, 12);
  final int nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  final verifier = WebhookVerifier('whsec_test', clock: () => now);
  late List<String> received;
  late WinterTestClient client;

  setUp(() {
    received = [];
    client = WinterTestClient.build(router: router(verifier, received));
  });

  const String body = '{"type": "payment.succeeded", "id": "evt_1"}';

  Future<TestResponse> send(String body, String signature) => client.post(
    '/webhooks/payments',
    headers: {
      'content-type': 'application/json',
      'webhook-signature': signature,
    },
    body: body,
  );

  String signed(int timestamp, String body) =>
      't=$timestamp,v1=${verifier.sign(timestamp, utf8.encode(body))}';

  test('a valid signature is accepted', () async {
    final response = await send(body, signed(nowSeconds, body));

    expect(response.statusCode, 204);
    expect(received, ['payment.succeeded']);
  });

  test('a body changed after signing is rejected', () async {
    final response = await send(
      body.replaceFirst('evt_1', 'evt_2'),
      signed(nowSeconds, body),
    );

    expect(response.statusCode, 400);
    expect((response.json as Map)['detail'], 'Invalid webhook signature');
    expect(received, isEmpty);
  });

  test('an old signature (a replay) is rejected', () async {
    final int anHourAgo = nowSeconds - 3600;
    final response = await send(body, signed(anHourAgo, body));

    expect(response.statusCode, 400);
    expect((response.json as Map)['detail'], 'The webhook signature expired');
  });

  test('no signature is rejected', () async {
    final response = await send(body, '');

    expect(response.statusCode, 400);
    expect((response.json as Map)['detail'], 'Missing webhook signature');
  });
}
