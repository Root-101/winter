import 'package:api_patterns_examples/api_versioning.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('v1 answers its own shape, marked as deprecated', () async {
    final response = await client.get('/v1/users/1');

    expect(response.json, {'id': 1, 'name': 'Ann Lee'});
    expect(response.headers['deprecation'], 'true');
    expect(response.headers['sunset'], 'Fri, 01 Jan 2027 00:00:00 GMT');
    expect(response.headers['link'], '</v2/users/1>; rel="successor-version"');
  });

  test('v2 answers the new shape, without deprecation', () async {
    final response = await client.get('/v2/users/1');

    expect(response.json, {'id': 1, 'firstName': 'Ann', 'lastName': 'Lee'});
    expect(response.headers['deprecation'], isNull);
  });

  test('an error of v1 is marked as deprecated too', () async {
    final response = await client.get('/v1/users/9');

    expect(response.statusCode, 404);
    expect(response.headers['deprecation'], 'true');
  });
}
