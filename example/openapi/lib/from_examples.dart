/// The bodies from an example of each model: its schema is inferred from what the object mapper
/// writes, and the rules of its `validate()` become the constraints (`required`, `minLength`,
/// `format`, `minimum`, `enum`). Nothing is written twice.
///
/// Run: `dart run lib/from_examples.dart`, then open http://localhost:8080/docs
library;

import 'package:winter/winter.dart';

class CreateProduct implements Validatable {
  final String? name;
  final String? supportEmail;
  final double? price;
  final String? category;
  final List<String> tags;

  CreateProduct({
    this.name,
    this.supportEmail,
    this.price,
    this.category,
    this.tags = const [],
  });

  /// The example of the document (and of "Try it out" in Swagger)
  static final CreateProduct example = CreateProduct(
    name: 'Desk lamp',
    supportEmail: 'help@example.com',
    price: 39.9,
    category: 'home',
    tags: ['light'],
  );

  factory CreateProduct.fromJson(Map<String, dynamic> json) => CreateProduct(
    name: json.field<String?>('name'),
    supportEmail: json.field<String?>('supportEmail'),
    price: json.field<double?>('price'),
    category: json.field<String?>('category'),
    tags: json.field<List<String>?>('tags') ?? const [],
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'supportEmail': supportEmail,
    'price': price,
    'category': category,
    'tags': tags,
  };

  // These rules are also the schema: read, never run, to write the document
  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('name', name).notNull().notBlank().size(max: 80)
    ..field('supportEmail', supportEmail).email()
    ..field('price', price).notNull().positive()
    ..field('category', category).notNull().oneOf(['home', 'garden', 'office'])
    ..field('tags', tags).size(max: 5);
}

class Product {
  final int id;
  final String name;
  final double price;
  final DateTime createdAt;

  Product(this.id, this.name, this.price, this.createdAt);

  static final Product example = Product(
    7,
    'Desk lamp',
    39.9,
    DateTime.utc(2026, 3, 1, 10),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'createdAt': createdAt,
  };
}

WinterRouter router() {
  final List<Product> products = [];
  final router = WinterRouter(
    routes: [
      Route.get(
        path: '/products',
        docs: RouteDocs(
          summary: 'Every product',
          // A list: its schema is an array of the first element's
          response: [Product.example],
        ),
        handler: (request) => ResponseEntity.ok(body: products),
      ),
      Route.post(
        path: '/products',
        docs: RouteDocs(
          summary: 'Create a product',
          status: 201,
          request: CreateProduct.example,
          response: Product.example,
          // A status without a body: its description
          responses: {409: 'A product with that name already exists'},
        ),
        handler: (request) async {
          final CreateProduct body = await request.body<CreateProduct>();
          final Product product = Product(
            products.length + 1,
            body.name!,
            body.price!,
            DateTime.now().toUtc(),
          );
          products.add(product);
          return ResponseEntity.created(
            location: '/products/${product.id}',
            body: product,
          );
        },
      ),
    ],
  );
  return router
    ..addRoute(
      Route.openApi(
        openApi: OpenApi(title: 'Products', version: '1.0.0', router: router),
      ),
    )
    ..addRoute(Route.swaggerUi(title: 'Products'));
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [Deserializer<CreateProduct>.json(CreateProduct.fromJson)],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}
