import 'dart:convert';

import 'package:security_examples/basic_auth.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  Map<String, String> basic(String credentials) => {
    'authorization': 'Basic ${base64.encode(utf8.encode(credentials))}',
  };

  test('without credentials: 401 with the Basic challenge', () async {
    final response = await client.get('/admin/metrics');

    expect(response.statusCode, 401);
    expect(
      response.headers['www-authenticate'],
      'Basic realm="admin", charset="UTF-8"',
    );
  });

  test('the right user and password', () async {
    final response = await client.get(
      '/admin/metrics',
      headers: basic('admin:s3cret'),
    );

    expect(response.statusCode, 200);
    expect((response.json as Map)['user'], 'admin');
  });

  test('a wrong password, an unknown user or a broken header: 401', () async {
    for (final headers in [
      basic('admin:wrong'),
      basic('root:s3cret'),
      {'authorization': 'Basic not-base64!'},
    ]) {
      expect(
        (await client.get('/admin/metrics', headers: headers)).statusCode,
        401,
      );
    }
  });

  test('parseBasic() keeps the colons of the password', () {
    final String header = 'Basic ${base64.encode(utf8.encode('ann:a:b'))}';

    expect(parseBasic(header), ('ann', 'a:b'));
    expect(parseBasic('Bearer abc'), isNull);
  });
}
