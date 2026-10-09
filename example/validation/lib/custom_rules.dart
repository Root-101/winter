/// Rules of your own: a reusable validator (an extension), a one-off `custom` rule, a rule that
/// compares two fields, and `oneOf`.
///
/// Run: `dart run lib/custom_rules.dart`
library;

import 'package:winter/winter.dart';

/// A reusable validator: an extension on the FieldValidator of the type it checks. The bound
/// (`T extends String?`) keeps the type of the field for the rules chained after it
extension SlugValidator<T extends String?> on FieldValidator<T> {
  FieldValidator<T> slug({String? message}) => addRule(
    // Pass on null, like the validators of Winter (notNull is the one for null)
    (value) =>
        value == null || RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(value),
    // A function: only called when the rule fails
    message: () =>
        message ?? 'Only lowercase letters, digits and single dashes',
    code: 'slug',
  );
}

class CreateEvent implements Validatable {
  final String slug;
  final DateTime start;
  final DateTime end;
  final String visibility;
  final int seats;

  CreateEvent(this.slug, this.start, this.end, this.visibility, this.seats);

  factory CreateEvent.fromJson(Map<String, dynamic> json) => CreateEvent(
    json.field<String>('slug'),
    json.field<DateTime>('start'),
    json.field<DateTime>('end'),
    json.field<String>('visibility'),
    json.field<int>('seats'),
  );

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('slug', slug).slug()
    // A rule that depends on two fields: on one of them, reading the other
    ..field('end', end).custom(
      (end) => end.isAfter(start) ? null : 'The end must be after the start',
      code: 'dateRange',
    )
    ..field('visibility', visibility).oneOf(['public', 'private'])
    // A one-off rule with params for the client
    ..field('seats', seats).custom(
      (seats) => seats % 10 == 0 ? null : 'Seats are sold in rows of 10',
      code: 'multipleOf',
      params: {'value': 10},
    );
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/events',
      handler: (request) async {
        final CreateEvent event = await request.body<CreateEvent>();
        return ResponseEntity.ok(body: {'slug': event.slug});
      },
    ),
  ],
);

Future<void> main() async {
  om.addDeserializer(Deserializer<CreateEvent>.json(CreateEvent.fromJson));
  await Winter.start(router: router());
}
