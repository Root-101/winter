import 'package:di_examples/layered_services.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

class FakeGateway implements PaymentGateway {
  final List<int> charged = [];

  @override
  String charge(int amount) {
    charged.add(amount);
    return 'fake:$amount';
  }
}

void main() {
  late DependencyInjection app;
  late FakeGateway fake;
  final client = WinterTestClient.build(router: router());

  setUpAll(() {
    Winter.context.setUp(dependencyInjection: DependencyInjection());
    registerDependencies();
    app = di; // the registrations of the app, never changed by a test
  });

  setUp(() {
    fake = FakeGateway();
    // Each test: a child with the fake. The rest (repository, service) comes from the app,
    // created again in the child, so the service gets the fake
    Winter.context.setUp(
      dependencyInjection: app.child()..put<PaymentGateway>(fake, tag: 'latam'),
    );
  });

  List<String> payments() =>
      (di.find<OrderRepository>() as InMemoryOrderRepository).payments;

  Future<TestResponse> checkout(String country) =>
      client.post('/checkout', body: {'country': country, 'amount': 100});

  test('a Latin American country uses the latam gateway (the fake)', () async {
    final response = await checkout('MX');

    expect(response.statusCode, 201);
    expect(fake.charged, [100]);
  });

  test('another country uses the default gateway, from the app', () async {
    await checkout('ES');

    expect(fake.charged, isEmpty);
    expect(payments(), ['stripe:100']);
  });

  test('each test has its own repository', () async {
    await checkout('MX');

    expect(payments(), ['fake:100']);
  });

  test('every registration of the app can be created', () {
    expect(app.createAll, returnsNormally);
  });
}
