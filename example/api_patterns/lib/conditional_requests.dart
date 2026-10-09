/// Conditional requests with an `ETag` (RFC 9110 §13):
///
/// - `GET` with `If-None-Match`: a 304 without body when the client already has this version.
/// - `PUT` with `If-Match`: optimistic locking, so two users editing the same document don't
///   overwrite each other. A stale version is a 412; no `If-Match` at all is a 428.
///
/// Run: `dart run lib/conditional_requests.dart`, then `curl -i localhost:8080/documents/1` and
/// `curl -i -X PUT localhost:8080/documents/1 -H 'If-Match: "1"' -H 'Content-Type: application/json' -d '{"text": "v2"}'`
library;

import 'package:winter/winter.dart';

class Document {
  final int id;
  final String text;
  final int version;

  const Document(this.id, this.text, this.version);

  /// A strong ETag: the version, quoted
  String get etag => '"$version"';

  Map<String, Object> toJson() => {'id': id, 'text': text};
}

class DocumentStore {
  final Map<int, Document> _documents = {1: const Document(1, 'v1', 1)};

  Document find(int id) =>
      _documents[id] ??
      (throw NotFoundException(detail: 'Document $id not found'));

  Document save(int id, String text) =>
      _documents[id] = Document(id, text, find(id).version + 1);
}

/// Whether `header` (`"1"`, `"1", "2"`, `W/"1"` or `*`) matches the ETag
bool etagMatches(String? header, String etag) {
  if (header == null) return false;
  return header
      .split(',')
      .map((tag) => tag.trim().replaceFirst('W/', ''))
      .any((tag) => tag == '*' || tag == etag);
}

WinterRouter router(DocumentStore store) => WinterRouter(
  routes: [
    Route.get(
      path: '/documents/{id|[0-9]+}',
      handler: (request) {
        final Document document = store.find(request.pathParam<int>('id'));
        final Map<String, String> headers = {
          HttpHeader.etag: document.etag,
          // The browser may keep it, but asks again every time (with If-None-Match)
          HttpHeader.cacheControl: 'no-cache',
        };
        if (etagMatches(
          request.headers[HttpHeader.ifNoneMatch],
          document.etag,
        )) {
          return ResponseEntity(StatusCode.notModified.value, headers: headers);
        }
        return ResponseEntity.ok(body: document, headers: headers);
      },
    ),
    Route.put(
      path: '/documents/{id|[0-9]+}',
      handler: (request) async {
        final int id = request.pathParam<int>('id');
        final String? ifMatch = request.headers[HttpHeader.ifMatch];
        if (ifMatch == null) {
          throw const ApiException(
            StatusCode.preconditionRequired,
            detail: 'Send If-Match with the ETag of the version you edited',
          );
        }
        final Document current = store.find(id);
        if (!etagMatches(ifMatch, current.etag)) {
          throw ApiException(
            StatusCode.preconditionFailed,
            detail: 'The document changed since you read it',
            extensions: {'currentVersion': current.etag},
          );
        }

        final Map<String, dynamic> changes = await request
            .body<Map<String, dynamic>>();
        final Document saved = store.save(id, changes['text'] as String);
        return ResponseEntity.ok(
          body: saved,
          headers: {HttpHeader.etag: saved.etag},
        );
      },
    ),
  ],
);

Future<void> main() async => Winter.start(router: router(DocumentStore()));
