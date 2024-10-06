import 'dart:async';

import '../../winter/winter.dart';

@GetRoute(path: '/test/{user-id}')
//@RequestRoute(path: '/test', method: 'get')
FutureOr<ResponseEntity> handler(
  RequestEntity request,
  @PathParam(name: 'user-id') String userId, {
  //@Body() String body = 'body',
  @Header(name: 'abc') String headerAbc = 'abc',
  @QueryParam(name: 'qwe') String queryQwe = 'qwe',
}) async {
  return ResponseEntity.ok(
    body:
        'header: $headerAbc, request: ${request.templateUrl}, path-param: $userId, q-param: $queryQwe',
  );
}

void main() {
  Route? loadedRoute = route();
  if (loadedRoute != null) {
    WinterServer(
      config: ServerConfig(port: 8080),
      router: BasicRouter(
        routes: [
          loadedRoute,
        ],
      ),
    ).start();
  }
}
