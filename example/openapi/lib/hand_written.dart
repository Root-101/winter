/// Schemas written by hand (`JsonSchema`), where an example isn't precise enough: an optional
/// field, a nullable one, an enum, a map; and the query params a handler reads (`QueryParam`).
///
/// Run: `dart run lib/hand_written.dart`, then open http://localhost:8080/docs
library;

import 'package:winter/winter.dart';

final JsonSchema _payment = JsonSchema.object(
  {
    'amount': JsonSchema.number(minimum: 0.01, description: 'In the currency'),
    'currency': JsonSchema.string(enumValues: ['EUR', 'USD']),
    'note': JsonSchema.string(maxLength: 200, nullable: true),
    // Free keys: {"orderId": "42", ...}
    'metadata': JsonSchema.map(JsonSchema.string()),
  },
  required: ['amount', 'currency'],
);

WinterRouter router() {
  final router = WinterRouter(
    routes: [
      Route.get(
        path: '/payments',
        docs: RouteDocs(
          summary: 'The payments, by page',
          query: [
            QueryParam(
              'page',
              JsonSchema.integer(minimum: 1),
              description: 'From 1',
            ),
            QueryParam(
              'status',
              JsonSchema.string(enumValues: ['pending', 'paid', 'refunded']),
            ),
          ],
          response: JsonSchema.array(_payment),
        ),
        handler: (request) {
          final int page = request.queryParam<int>('page') ?? 1;
          return ResponseEntity.ok(
            body: {'page': page, 'items': const <Object>[]},
          );
        },
      ),
      Route.post(
        path: '/payments',
        docs: RouteDocs(
          summary: 'Pay',
          status: 201,
          request: _payment,
          response: _payment,
          // A body for an error of your own
          responses: {
            402: JsonSchema.object({'missing': JsonSchema.number()}),
          },
        ),
        handler: (request) async {
          final Map<String, dynamic> payment = await request
              .body<Map<String, dynamic>>();
          return ResponseEntity.created(location: '/payments/1', body: payment);
        },
      ),
    ],
  );
  return router
    ..addRoute(
      Route.openApi(
        openApi: OpenApi(title: 'Payments', version: '1.0.0', router: router),
      ),
    )
    ..addRoute(Route.swaggerUi(title: 'Payments'));
}

Future<void> main() async => Winter.start(router: router());
