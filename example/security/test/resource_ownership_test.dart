import 'package:security_examples/resource_ownership.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUp(
    () => client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([BearerFilter()]),
      router: router(PostService()),
    ),
  );

  Map<String, String> as(String user) => {'authorization': 'Bearer $user'};

  group('a rule on the route (the owner is in the path)', () {
    test('the owner and an admin pass, anybody else gets a 403', () async {
      expect(
        (await client.get('/users/ann/drafts', headers: as('ann'))).statusCode,
        200,
      );
      expect(
        (await client.get('/users/ann/drafts', headers: as('root'))).statusCode,
        200,
      );
      expect(
        (await client.get('/users/ann/drafts', headers: as('bob'))).statusCode,
        403,
      );
    });

    test('nobody authenticated gets a 401', () async {
      expect((await client.get('/users/ann/drafts')).statusCode, 401);
    });
  });

  group('a check in the service (the owner is in the database)', () {
    Future<TestResponse> edit(String user) => client.put(
      '/posts/1',
      headers: {...as(user), 'content-type': 'text/plain'},
      body: 'Edited',
    );

    test('the author edits the post', () async {
      final response = await edit('ann');

      expect(response.statusCode, 200);
      expect((response.json as Map)['text'], 'Edited');
    });

    test('an admin can too, another user gets a 403', () async {
      expect((await edit('root')).statusCode, 200);

      final denied = await edit('bob');
      expect(denied.statusCode, 403);
      expect((denied.json as Map)['detail'], 'Only the author can edit it');
    });
  });
}
