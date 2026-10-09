import 'package:object_mapper_examples/typed_fields.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  String? detail(TestResponse response) =>
      (response.json as Map)['detail'] as String?;

  Future<TestResponse> post(Object body) =>
      client.post('/contacts', body: body);

  test('a valid contact, with the optional fields missing', () async {
    final response = await post({
      'name': 'Ann',
      'address': {'city': 'Madrid'},
    });

    expect(response.json, {
      'name': 'Ann',
      'birthday': null,
      'address': {'city': 'Madrid', 'zipCode': null},
      'phones': <Object>[],
    });
  });

  test('each error names its path', () async {
    final cases = <Object, String>{
      {
        'address': {'city': 'Madrid'},
      }: r'$.name: missing',
      {
        'name': 1,
        'address': {'city': 'Madrid'},
      }: r'$.name: expected a string, got an integer',
      {'name': 'Ann'}: r'$.address: missing',
      {
        'name': 'Ann',
        'address': {'city': true},
      }: r'$.address.city: expected a string, got a boolean',
      {
        'name': 'Ann',
        'address': {'city': 'Madrid'},
        'phones': [
          {'number': '600'},
          {'number': 600},
        ],
      }: r'$.phones[1].number: expected a string, got an integer',
      {
        'name': 'Ann',
        'address': {'city': 'Madrid'},
        'birthday': 'tomorrow',
      }: r'$.birthday: expected an ISO-8601 date, got an invalid string',
    };
    for (final MapEntry(key: body, value: message) in cases.entries) {
      final response = await post(body);

      expect(response.statusCode, 400);
      expect(detail(response), message);
    }
  });

  test('not JSON is a 400, another Content-Type a 415', () async {
    final notJson = await client.post(
      '/contacts',
      body: '{"name": ',
      headers: {HttpHeader.contentType: 'application/json'},
    );
    final form = await client.post(
      '/contacts',
      body: 'name=Ann',
      headers: {HttpHeader.contentType: 'application/x-www-form-urlencoded'},
    );

    expect(notJson.statusCode, 400);
    expect(form.statusCode, 415);
  });
}
