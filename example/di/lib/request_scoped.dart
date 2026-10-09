/// One instance per request with `putScoped`: an audit trail that the services of a request fill
/// in, and that is written once when the request ends (its `onDispose`), with the user of the
/// request. Two requests at the same time never share it.
///
/// Run: `dart run lib/request_scoped.dart`, then
/// `curl -X DELETE localhost:8080/documents/7 -H 'X-User: ann'`
library;

import 'package:winter/winter.dart';

/// Filled during a request, written when it ends
class AuditTrail {
  final String user;
  final List<String> actions = [];

  AuditTrail(this.user);
}

/// Where the trails end (a table, a log, a queue)
class AuditSink {
  final List<String> lines = [];

  void write(AuditTrail trail) {
    if (trail.actions.isEmpty) return;
    lines.add('${trail.user}: ${trail.actions.join(', ')}');
  }
}

class DocumentService {
  /// Found on each call: a singleton never keeps a scoped instance in a field
  AuditTrail get _audit => di.find<AuditTrail>();

  void delete(int id) {
    _audit.actions.add('delete document $id');
    _deleteAttachments(id);
  }

  void _deleteAttachments(int id) =>
      _audit.actions.add('delete attachments of $id');
}

void registerDependencies(AuditSink sink) {
  di
    ..put<AuditSink>(sink)
    ..put<DocumentService>(DocumentService())
    ..putScoped<AuditTrail>(
      // Created the first time a request finds it, inside that request: it sees its user
      () => AuditTrail(requestPrincipalOrNull<String>() ?? 'anonymous'),
      onDispose: (trail) => di.find<AuditSink>().write(trail),
    );
}

/// `X-User: ann` as the user; a real app verifies a token here (see example/security)
class UserHeaderFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? user = request.headers['x-user'];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication<String>(principal: user),
      );
    }
    return chain.doFilter(request);
  }
}

final FilterConfig globalFilters = FilterConfig([UserHeaderFilter()]);

WinterRouter router() => WinterRouter(
  routes: [
    Route.delete(
      path: '/documents/{id|[0-9]+}',
      handler: (request) {
        di.find<DocumentService>().delete(request.pathParam<int>('id'));
        return ResponseEntity.noContent();
      },
    ),
  ],
);

Future<void> main() async {
  registerDependencies(AuditSink());
  await Winter.start(globalFilterConfig: globalFilters, router: router());
}
