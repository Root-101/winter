import 'package:test/test.dart';
import 'package:validation_examples/custom_rules.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(
    () => om.addDeserializer(
      Deserializer<CreateEvent>.json(CreateEvent.fromJson),
    ),
  );

  Map<String, Object?> event({
    String slug = 'dart-conf',
    String end = '2027-05-02T18:00:00Z',
    String visibility = 'public',
    int seats = 120,
  }) => {
    'slug': slug,
    'start': '2027-05-01T09:00:00Z',
    'end': end,
    'visibility': visibility,
    'seats': seats,
  };

  test('a valid event', () async {
    expect((await client.post('/events', body: event())).json, {
      'slug': 'dart-conf',
    });
  });

  test('the custom rules, with their codes and params', () async {
    final response = await client.post(
      '/events',
      body: event(
        slug: 'Dart Conf',
        end: '2027-04-30T18:00:00Z',
        visibility: 'secret',
        seats: 125,
      ),
    );
    final List<Object?> violations =
        (response.json as Map)['violations'] as List;

    expect(response.statusCode, 422);
    expect(
      [for (final v in violations) (v as Map)['code']],
      ['slug', 'dateRange', 'oneOf', 'multipleOf'],
    );
    expect(violations.last, {
      'fieldName': 'seats',
      'message': 'Seats are sold in rows of 10',
      'code': 'multipleOf',
      'params': {'value': 10},
    });
  });
}
