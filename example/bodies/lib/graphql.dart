/// GraphQL: raw JSON with the query, its variables and the name of the operation. (This only reads
/// the request; a real server passes it to a GraphQL engine.)
///
/// Run: `dart run lib/graphql.dart`
library;

import 'package:winter/winter.dart';

class GraphQLRequest {
  final String query;
  final Map<String, dynamic> variables;
  final String? operationName;

  GraphQLRequest(this.query, this.variables, this.operationName);

  factory GraphQLRequest.fromJson(Map<String, dynamic> json) => GraphQLRequest(
    json.field<String>('query'),
    json.field<Map<String, dynamic>?>('variables') ?? const {},
    json.field<String?>('operationName'),
  );
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [Deserializer<GraphQLRequest>.json(GraphQLRequest.fromJson)],
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/graphql',
      handler: (request) async {
        final GraphQLRequest graphql = await request.body<GraphQLRequest>();
        return ResponseEntity.ok(
          body: {
            'operationName': graphql.operationName,
            'query': graphql.query,
            'variables': graphql.variables,
          },
        );
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}
