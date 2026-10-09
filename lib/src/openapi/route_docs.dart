import 'package:winter/winter.dart';

/// What OpenAPI says about a route, besides what Winter finds by itself (the method, the path, its
/// params, the security of its `AuthFilter`, the errors):
///
/// ```dart
/// Route.post(
///   path: '/users',
///   handler: createUser,
///   docs: RouteDocs(
///     summary: 'Create a user',
///     tags: ['users'],
///     status: 201,
///     request: CreateUser(name: 'Ann Lee', email: 'ann@example.com'), // an example
///     response: User(id: 7, name: 'Ann Lee', email: 'ann@example.com'),
///     responses: {409: 'The email is already registered'},
///   ),
/// )
/// ```
///
/// A body ([request], [response] and the values of [responses]) is any of:
///
/// - **an example**: an object (written by the object mapper, so its `toJson()` or serializer
///   must exist) or a JSON value. Its schema is inferred from it, and when it's [Validatable] the
///   rules of its `validate()` become constraints (`required`, `format`, `minLength`...).
/// - **a [JsonSchema]** written by hand, when the inferred one isn't precise enough.
/// - **a [BodyDocs]**: both, plus a description or another content type.
/// - **a String** (only in [responses]): just its description, without a body.
///
/// {@category OpenAPI}
final class RouteDocs {
  /// A short summary of the operation (one line in Swagger)
  final String? summary;

  /// A longer description (Markdown)
  final String? description;

  /// The groups of the operation in Swagger. The children of a `Route.parent` with docs inherit
  /// its tags when they have none.
  final List<String> tags;

  /// A unique id of the operation, for the clients generated from the document
  final String? operationId;

  /// Whether the operation is deprecated
  final bool deprecated;

  /// Leaves the route out of the document
  final bool hidden;

  /// The status of a successful response: 200 by default (201 for a creation, 204 without body)
  final int status;

  /// The body of the request: an example, a [JsonSchema] or a [BodyDocs]
  final Object? request;

  /// The body of the successful response ([status]): an example, a [JsonSchema] or a [BodyDocs]
  final Object? response;

  /// Other responses by status (`{409: 'Already registered'}`): an example, a [JsonSchema], a
  /// [BodyDocs] or a description
  final Map<int, Object?> responses;

  /// The query params the handler reads (Winter can't find them by itself)
  final List<QueryParam> query;

  /// The docs of a route
  const RouteDocs({
    this.summary,
    this.description,
    this.tags = const [],
    this.operationId,
    this.deprecated = false,
    this.hidden = false,
    this.status = 200,
    this.request,
    this.response,
    this.responses = const {},
    this.query = const [],
  });

  /// Leaves the route out of the document
  static const RouteDocs none = RouteDocs(hidden: true);

  /// These docs with the tags of [parent] when they have none
  RouteDocs inheriting(RouteDocs? parent) =>
      parent == null || tags.isNotEmpty || parent.tags.isEmpty
      ? this
      : RouteDocs(
          summary: summary,
          description: description,
          tags: parent.tags,
          operationId: operationId,
          deprecated: deprecated,
          hidden: hidden || parent.hidden,
          status: status,
          request: request,
          response: response,
          responses: responses,
          query: query,
        );
}

/// A body of [RouteDocs] with everything it can say: a [schema] (written by hand), an [example]
/// (from which a schema is inferred when there is no [schema]), the model whose `validate()` gives
/// the constraints ([rulesFrom]; by default the [example] when it's [Validatable]), a
/// [description] and a [contentType].
///
/// ```dart
/// BodyDocs(
///   example: {'name': 'Ann Lee', 'email': 'ann@example.com'}, // a model without toJson()
///   rulesFrom: CreateUser(name: 'Ann Lee', email: 'ann@example.com'),
///   description: 'The new user',
/// )
/// ```
///
/// {@category OpenAPI}
final class BodyDocs {
  /// The schema written by hand; it wins over the inferred one
  final JsonSchema? schema;

  /// An example: an object written by the object mapper, or a JSON value
  final Object? example;

  /// The model whose `validate()` gives the constraints of the inferred schema
  final Validatable? rulesFrom;

  /// What the body is
  final String? description;

  /// Its media type
  final String contentType;

  /// A documented body
  const BodyDocs({
    this.schema,
    this.example,
    this.rulesFrom,
    this.description,
    this.contentType = 'application/json',
  });
}

/// A query param that a handler reads (`request.queryParam<int>('page')`)
///
/// {@category OpenAPI}
final class QueryParam {
  /// The name of the param
  final String name;

  /// Its schema (`JsonSchema.integer(minimum: 1)`)
  final JsonSchema schema;

  /// Whether the request must have it
  final bool required;

  /// What it does
  final String? description;

  /// A query param of [name]
  const QueryParam(
    this.name,
    this.schema, {
    this.required = false,
    this.description,
  });
}
