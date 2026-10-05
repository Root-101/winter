import 'package:i18n_example/i18n/t.dart';
import 'package:i18n_example/i18n_example.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(I18nServer.configure);

  /// A new service (empty) for each test, run in memory without a port
  setUp(
    () => client = WinterTestClient.build(
      router: I18nServer.router(OrderService()),
    ),
  );

  Map<String, String> lang(String acceptLanguage) => {
    HttpHeader.acceptLanguage: acceptLanguage,
  };

  List<String> messages(TestResponse response) => [
    for (final v in response.json as List)
      (v as Map<String, dynamic>)['message'] as String,
  ];

  group('GET /hello (text of the app + user of the request)', () {
    test('English without Accept-Language', () async {
      final response = await client.get('/hello', headers: {'X-User': 'adam'});
      expect(response.body, 'Hello, adam');
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
    });

    test('Spanish, also for a region (es-MX)', () async {
      final response = await client.get(
        '/hello',
        headers: {'X-User': 'adam', ...lang('es-MX')},
      );
      expect(response.body, 'Hola, adam');
    });

    test('A language that the app does not support: English', () async {
      final response = await client.get(
        '/hello',
        headers: {'X-User': 'adam', ...lang('fr')},
      );
      expect(response.body, 'Hello, adam');
    });

    test('Without user: 401', () async {
      expect((await client.get('/hello')).statusCode, 401);
    });
  });

  group('POST /orders', () {
    test('Created, in Spanish', () async {
      final response = await client.post(
        '/orders',
        body: {'product': 'book', 'quantity': 2},
        headers: lang('es'),
      );
      expect(response.statusCode, 201);
      expect(response.json, {'id': 1, 'message': 'Pedido 1 creado'});
    });

    test('422 mixes the texts of the app and of Winter, in Spanish', () async {
      final response = await client.post(
        '/orders',
        body: {'product': ' ', 'quantity': 0},
        headers: lang('es'),
      );
      expect(response.statusCode, 422);
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
      expect(messages(response), ['Elige un producto', 'El mínimo es 1']);
    });

    test('422 in English', () async {
      final response = await client.post('/orders', body: {'product': ''});
      expect(messages(response), [
        'Choose a product',
        'The field cannot be null',
      ]);
    });
  });

  group('GET /orders/{id} (a service throws the translated error)', () {
    test('404 in Spanish', () async {
      final response = await client.get('/orders/7', headers: lang('es'));
      expect(response.statusCode, 404);
      expect(response.body, 'Pedido 7 no encontrado');
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
    });

    test('Found: nothing reads the language, so no Vary', () async {
      await client.post('/orders', body: {'product': 'book', 'quantity': 2});
      final response = await client.get('/orders/1', headers: lang('es'));
      expect(response.json, {'product': 'book', 'quantity': 2});
      expect(response.headers[HttpHeader.vary], isNull);
    });

    test('404 in English', () async {
      final response = await client.get('/orders/7');
      expect(response.body, 'Order 7 not found');
    });
  });

  test('Concurrent requests answer each one in its language', () async {
    final responses = await Future.wait([
      for (int i = 0; i < 20; i++)
        client.get('/orders/$i', headers: lang(i.isEven ? 'es' : 'en')),
    ]);

    for (int i = 0; i < 20; i++) {
      expect(
        responses[i].body,
        i.isEven ? 'Pedido $i no encontrado' : 'Order $i not found',
      );
    }
  });

  test('The service outside the server, in a RequestScope', () {
    expect(
      () => RequestScope.run(
        RequestScope(locale: WinterLocale.spanish),
        () => OrderService().find(3),
      ),
      throwsA(
        isA<NotFoundException>().having(
          (e) => e.body,
          'body',
          'Pedido 3 no encontrado',
        ),
      ),
    );
  });

  test('t outside a request: the fallback (English)', () {
    expect(t.orders.created(id: 1), 'Order 1 created');
  });
}
