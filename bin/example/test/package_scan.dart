import 'dart:async';

import '../../winter/winter.dart';

@GetRoute(path: '/test/{user-id}')
//@RequestRoute(path: '/test', method: 'get')
FutureOr<ResponseEntity> handler(
  RequestEntity request,
  @PathParam(name: 'user-id') String userId, {
  //@Body<Test>() required Test body,
  //@Body<Test>.list() List<Test> body = const [],
  @Body<Test>.map() Map<String, Test> body = const {},
  @Header(name: 'abc') String headerAbc = 'abc',
  @QueryParam(name: 'qwe') String queryQwe = 'qwe',
}) async {
  return ResponseEntity.ok(
    body:
        'body: $body, header: $headerAbc, request: ${request.templateUrl}, path-param: $userId, q-param: $queryQwe',
  );
}

class Test {
  String? name;

  Test();

  Test.named(this.name);

  @override
  String toString() {
    return 'Test{name: $name}';
  }
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
