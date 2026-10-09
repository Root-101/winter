/// `rejectUnknownFields`: a key the model doesn't read (`is_admin`, a typo) is a 400, against mass
/// assignment; one type (a webhook of another service) keeps accepting anything.
///
/// Run: `dart run lib/unknown_fields.dart`
library;

import 'package:winter/winter.dart';

class SignUp {
  final String name;
  final String email;

  SignUp(this.name, this.email);

  // The fields it reads are the known ones: nothing else to declare
  factory SignUp.fromJson(Map<String, dynamic> json) =>
      SignUp(json.field<String>('name'), json.field<String>('email'));
}

/// The event of a payment provider: it adds fields whenever it wants
class PaymentEvent {
  final String type;

  PaymentEvent(this.type);

  factory PaymentEvent.fromJson(Map<String, dynamic> json) =>
      PaymentEvent(json.field<String>('type'));
}

ObjectMapper objectMapper() => ObjectMapper(
  rejectUnknownFields: true,
  deserializers: [
    Deserializer<SignUp>.json(SignUp.fromJson),
    Deserializer<PaymentEvent>.json(
      PaymentEvent.fromJson,
      rejectUnknownFields: false,
    ),
  ],
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/sign-up',
      handler: (request) async => ResponseEntity.ok(
        body: {'name': (await request.body<SignUp>()).name},
      ),
    ),
    Route.post(
      path: '/webhooks/payments',
      handler: (request) async => ResponseEntity.ok(
        body: {'type': (await request.body<PaymentEvent>()).type},
      ),
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}
