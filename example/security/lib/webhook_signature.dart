/// Receiving a webhook (a payment provider, GitHub, Slack): the sender signs the raw body with a
/// shared secret, and the receiver checks the signature **over the bytes as they came**, before
/// trusting the JSON. A timestamp in the signature stops an old request from being replayed.
///
/// The header follows the scheme of Stripe: `Webhook-Signature: t=<unix seconds>,v1=<hex>`, where
/// the hex is the HMAC-SHA256 of `<t>.<body>`.
///
/// Run: `WEBHOOK_SECRET=whsec_test dart run lib/webhook_signature.dart` (the test shows how a
/// sender signs a request)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:winter/winter.dart';

class WebhookVerifier {
  final List<int> secret;

  /// How old a signature can be
  final Duration tolerance;

  final DateTime Function() clock;

  WebhookVerifier(
    String secret, {
    this.tolerance = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : secret = utf8.encode(secret),
       clock = clock ?? DateTime.now;

  /// The signature of [body] at [timestamp] (what the sender computes)
  String sign(int timestamp, List<int> body) => Hmac(
    sha256,
    secret,
  ).convert([...utf8.encode('$timestamp.'), ...body]).toString();

  /// Throws a 400 unless [header] is a valid, recent signature of [body]
  void verify(String? header, Uint8List body) {
    final Map<String, String> parts = {
      for (final String part in (header ?? '').split(','))
        if (part.contains('='))
          part.substring(0, part.indexOf('=')).trim(): part.substring(
            part.indexOf('=') + 1,
          ),
    };
    final int? timestamp = int.tryParse(parts['t'] ?? '');
    final String? signature = parts['v1'];
    if (timestamp == null || signature == null) {
      throw const BadRequestException(detail: 'Missing webhook signature');
    }

    final DateTime signedAt = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    );
    if (clock().difference(signedAt).abs() > tolerance) {
      throw const BadRequestException(detail: 'The webhook signature expired');
    }
    if (!_constantTimeEquals(sign(timestamp, body), signature)) {
      throw const BadRequestException(detail: 'Invalid webhook signature');
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int difference = 0;
    for (int i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}

WinterRouter router(
  WebhookVerifier verifier,
  List<String> received,
) => WinterRouter(
  routes: [
    Route.post(
      path: '/webhooks/payments',
      handler: (request) async {
        // The raw bytes first (cached): re-encoding the parsed JSON would change them
        verifier.verify(
          request.headers['webhook-signature'],
          await request.bytes(),
        );
        final Map<String, dynamic> event = await request
            .body<Map<String, dynamic>>();
        received.add(event['type'] as String);
        // Answer fast: the sender retries anything that isn't a 2xx
        return ResponseEntity.noContent();
      },
    ),
  ],
);

Future<void> main() async => Winter.start(
  router: router(WebhookVerifier(env.require<String>('WEBHOOK_SECRET')), []),
);
