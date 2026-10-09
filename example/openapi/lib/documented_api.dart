/// A whole API documented: a `basePath`, groups with their tags (`Route.parent` with docs), an
/// admin group protected by an `AuthFilter` (its 401/403 and the Bearer scheme in Swagger's
/// "Authorize"), and the document and Swagger UI under the same base path.
///
/// Run: `dart run lib/documented_api.dart`, then open http://localhost:8080/api/v1/docs and use
/// "Authorize" with the token `admin-token`
library;

import 'package:winter/winter.dart';

class Book {
  final int id;
  final String title;
  final String author;

  const Book(this.id, this.title, this.author);

  static const Book example = Book(1, 'Dune', 'Frank Herbert');

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'author': author};
}

class NewBook implements Validatable {
  final String title;
  final String author;

  NewBook(this.title, this.author);

  static final NewBook example = NewBook('Dune', 'Frank Herbert');

  factory NewBook.fromJson(Map<String, dynamic> json) =>
      NewBook(json.field<String>('title'), json.field<String>('author'));

  Map<String, Object?> toJson() => {'title': title, 'author': author};

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('title', title).notBlank()
    ..field('author', author).notBlank();
}

/// Authenticates `Authorization: Bearer admin-token` as an admin (a real app checks a JWT)
class TokenFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.headers[HttpHeader.authorization] == 'Bearer admin-token') {
      request.securityContext.setAuthentication(
        Authentication(principal: 'admin', roles: {'admin'}),
      );
    }
    return await chain.doFilter(request);
  }
}

FilterConfig globalFilters() => FilterConfig([TokenFilter()]);

WinterRouter router() {
  final Map<int, Book> books = {1: Book.example};
  final router = WinterRouter(
    basePath: '/api/v1',
    routes: [
      Route.parent(
        path: '/books',
        // Every child is in the group "books" of Swagger
        docs: const RouteDocs(tags: ['books']),
        routes: [
          Route.get(
            path: '/',
            docs: RouteDocs(
              summary: 'Every book',
              query: [QueryParam('author', JsonSchema.string())],
              response: [Book.example],
            ),
            handler: (request) {
              final String? author = request.queryParam<String>('author');
              return ResponseEntity.ok(
                body: books.values
                    .where((book) => author == null || book.author == author)
                    .toList(),
              );
            },
          ),
          Route.get(
            path: '/{id|[0-9]+}',
            docs: const RouteDocs(summary: 'A book', response: Book.example),
            handler: (request) {
              final int id = request.pathParam<int>('id');
              return ResponseEntity.ok(
                body:
                    books[id] ??
                    (throw NotFoundException(detail: 'Book $id not found')),
              );
            },
          ),
        ],
      ),
      Route.parent(
        path: '/admin/books',
        filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
        docs: const RouteDocs(tags: ['admin']),
        routes: [
          Route.post(
            path: '/',
            docs: RouteDocs(
              summary: 'Add a book',
              status: 201,
              request: NewBook.example,
              response: Book.example,
            ),
            handler: (request) async {
              final NewBook body = await request.body<NewBook>();
              final Book book = Book(books.length + 1, body.title, body.author);
              books[book.id] = book;
              return ResponseEntity.created(
                location: '/api/v1/books/${book.id}',
                body: book,
              );
            },
          ),
          Route.delete(
            path: '/{id|[0-9]+}',
            docs: const RouteDocs(summary: 'Remove a book', status: 204),
            handler: (request) {
              books.remove(request.pathParam<int>('id'));
              return ResponseEntity.noContent();
            },
          ),
        ],
      ),
    ],
  );
  // Added after the routes, so they take the basePath too: /api/v1/openapi.json, /api/v1/docs
  return router
    ..addRoute(
      Route.openApi(
        openApi: OpenApi(
          title: 'Library',
          version: '1.0.0',
          description:
              'The books of the library. The admin routes need `admin-token`.',
          servers: ['http://localhost:8080'],
          router: router,
        ),
      ),
    )
    ..addRoute(
      Route.swaggerUi(specUrl: '/api/v1/openapi.json', title: 'Library'),
    );
}

ObjectMapper objectMapper() =>
    ObjectMapper(deserializers: [Deserializer<NewBook>.json(NewBook.fromJson)]);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router(), globalFilterConfig: globalFilters());
}
