import 'package:winter/winter.dart';

/// An amount of money, written as text in the JSON (`"12.50 EUR"`) by its own serializer
class Money {
  final int cents;
  final String currency;

  const Money(this.cents, this.currency);

  /// `12.50 EUR`: a FormatException otherwise (a 400 with `invalid value`)
  factory Money.parse(String text) {
    final match = RegExp(r'^(\d+)\.(\d{2}) ([A-Z]{3})$').firstMatch(text);
    if (match == null) throw FormatException('Not an amount', text);
    return Money(int.parse(match[1]!) * 100 + int.parse(match[2]!), match[3]!);
  }

  Money operator *(int times) => Money(cents * times, currency);

  @override
  String toString() =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')} $currency';
}

enum Shipping { standard, express }

class Address implements Validatable {
  final String street;
  final String city;
  final String zipCode;

  const Address(this.street, this.city, this.zipCode);

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    json['street'] as String,
    json['city'] as String,
    json['zipCode'] as String,
  );

  Map<String, Object?> toJson() => {
    'street': street,
    'city': city,
    'zipCode': zipCode,
  };

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('street', street).notBlank();
    cvc.field('city', city).notBlank();
    cvc.field('zipCode', zipCode).pattern(RegExp(r'^\d{5}$'));
    return cvc;
  }
}

class OrderItem implements Validatable {
  final String productId;
  final int quantity;
  final Money unitPrice;

  const OrderItem(this.productId, this.quantity, this.unitPrice);

  /// The parent reads its children itself; a registered type (Money) goes through the mapper
  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    json['productId'] as String,
    json['quantity'] as int,
    om.deserialize<Money>(json['unitPrice']),
  );

  Map<String, Object?> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('productId', productId).notBlank();
    cvc.field('quantity', quantity).positive().max(100);
    return cvc;
  }
}

/// The body of `POST /orders`
class CreateOrder implements Validatable {
  final String customerEmail;
  final Address shippingAddress;
  final List<OrderItem> items;
  final Shipping shipping;
  final DateTime? deliverOn;

  /// Discount codes and their percentage (`{"SUMMER": 10}`)
  final Map<String, int> discounts;

  const CreateOrder({
    required this.customerEmail,
    required this.shippingAddress,
    required this.items,
    required this.shipping,
    this.deliverOn,
    this.discounts = const {},
  });

  factory CreateOrder.fromJson(Map<String, dynamic> json) => CreateOrder(
    customerEmail: json['customerEmail'] as String,
    shippingAddress: Address.fromJson(
      json['shippingAddress'] as Map<String, dynamic>,
    ),
    items: [
      for (final item in json['items'] as List)
        OrderItem.fromJson(item as Map<String, dynamic>),
    ],
    shipping: om.deserialize<Shipping>(json['shipping']),
    deliverOn: om.deserialize<DateTime?>(json['deliverOn']),
    discounts: om.deserialize<Map<String, int>>(json['discounts'] ?? {}),
  );

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('customerEmail', customerEmail).email();
    cvc.field('shippingAddress', shippingAddress).valid();
    cvc.field('items', items).notEmpty().size(max: 20).validEach();
    cvc.field('deliverOn', deliverOn).future();
    cvc
        .field('discounts', discounts)
        .size(max: 2)
        .custom(
          (value) => value.values.every((percent) => percent <= 50)
              ? null
              : 'A discount is 50 % at most',
          code: 'discountTooBig',
        );
    return cvc;
  }
}

class Order {
  final int id;
  final CreateOrder request;

  const Order(this.id, this.request);

  Money get total => request.items
      .map((item) => item.unitPrice * item.quantity)
      .reduce((a, b) => Money(a.cents + b.cents, a.currency));

  Map<String, Object?> toJson() => {
    'id': id,
    'customerEmail': request.customerEmail,
    'shippingAddress': request.shippingAddress,
    'items': request.items,
    'shipping': request.shipping,
    'deliverOn': request.deliverOn,
    'total': total,
  };
}

class OrderService {
  final List<Order> _orders = [];

  Order create(CreateOrder request) {
    final order = Order(_orders.length + 1, request);
    _orders.add(order);
    return order;
  }

  Order find(int id) =>
      _orders.where((order) => order.id == id).firstOrNull ??
      (throw NotFoundException(detail: 'Order $id not found'));

  List<Order> list({required int page, Shipping? shipping}) => _orders
      .where((order) => shipping == null || order.request.shipping == shipping)
      .skip((page - 1) * 10)
      .take(10)
      .toList();
}

class OrdersApp {
  /// The object mapper of the app: snake_case JSON, without nulls, with its types
  static ObjectMapper objectMapper() => ObjectMapper(
    fieldNaming: FieldNaming.snakeCase,
    includeNulls: false,
    serializers: [Serializer<Money>((money) => money.toString())],
    deserializers: [
      Deserializer<CreateOrder>.json(CreateOrder.fromJson),
      Deserializer<Money>.string(Money.parse),
      Deserializer<Shipping>.enumByName(Shipping.values),
    ],
  );

  static WinterRouter router(OrderService service) => WinterRouter(
    basePath: '/orders',
    routes: [
      Route.post(
        path: '/',
        handler: (request) async {
          final order = service.create(await request.body<CreateOrder>());
          return ResponseEntity.created(
            location: '/orders/${order.id}',
            body: order,
          );
        },
      ),
      Route.get(
        path: '/',
        handler: (request) => ResponseEntity.ok(
          body: service.list(
            page: request.queryParam<int>('page') ?? 1,
            shipping: request.queryParam('shipping', values: Shipping.values),
          ),
        ),
      ),
      Route.get(
        path: '/{id}',
        handler: (request) =>
            ResponseEntity.ok(body: service.find(request.pathParam<int>('id'))),
      ),
    ],
  );

  static Future<void> start({int port = 8080}) async {
    Winter.context.setUp(objectMapper: objectMapper());
    await Winter.start(
      config: ServerConfig(port: port),
      router: router(OrderService()),
    );
  }
}
