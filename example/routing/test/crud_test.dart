import 'package:routing_examples/crud.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  setUp(() {
    // A new service per test: Winter.context.setUp with a new DI
    Winter.context.setUp(
      dependencyInjection: DependencyInjection()..put(UserService()),
    );
    client = WinterTestClient.build(router: router());
  });

  test('list, find and a 404', () async {
    expect((await client.get('/users')).json, hasLength(2));
    expect((await client.get('/users/1')).json, {
      'id': 1,
      'name': 'Alice',
      'nickname': 'ali',
    });
    expect((await client.get('/users/9')).statusCode, 404);
  });

  test('create: 201 with Location', () async {
    final response = await client.post('/users', body: {'name': 'Carol'});

    expect(response.statusCode, 201);
    expect(response.headers['location'], '/users/3');
    expect((await client.get('/users/3')).json, {
      'id': 3,
      'name': 'Carol',
      'nickname': null,
    });
  });

  test('patch: absent keeps, null clears', () async {
    expect((await client.patch('/users/1', body: {'name': 'Alicia'})).json, {
      'id': 1,
      'name': 'Alicia',
      'nickname': 'ali',
    });
    expect((await client.patch('/users/1', body: {'nickname': null})).json, {
      'id': 1,
      'name': 'Alicia',
      'nickname': null,
    });
  });

  test('delete: 204, then 404', () async {
    expect((await client.delete('/users/2')).statusCode, 204);
    expect((await client.get('/users/2')).statusCode, 404);
  });
}
