import 'dart:async';

import '../../winter/winter.dart';
import 'model.dart';

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
