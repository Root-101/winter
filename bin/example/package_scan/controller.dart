import 'dart:async';

import '../../winter/winter.dart';
import 'model.dart';

@GetRoute(path: '/test/{user-id}')
FutureOr<ResponseEntity> handler(
  RequestEntity request,
  @PathParam(name: 'user-id') String userId, {
  @Body<Test>() required Test body,
  @Header(name: 'abc') String headerAbc = 'abc',
  @QueryParam(name: 'qwe') String queryQwe = 'qwe',
}) async {
  return ResponseEntity.ok(
    body:
        'body: $body, header: $headerAbc, request: ${request.requestedUri}, path-param: $userId, q-param: $queryQwe',
  );
}

@RequestRoute(
  path: '/test-0/{user-id}',
  method: HttpMethod.get,
  order: 0,
  filterConfig: FilterConfig([LogsFilter()]),
)
FutureOr<ResponseEntity> handler0(
  RequestEntity request,
  @PathParam(name: 'user-id') String userId, {
  @Body<Test>() required Test body,
  @Header(name: 'abc') String headerAbc = 'abc',
  @QueryParam(name: 'qwe') String queryQwe = 'qwe',
}) async {
  return ResponseEntity.ok(
    body:
        'body: $body, header: $headerAbc, request: ${request.requestedUri}, path-param: $userId, q-param: $queryQwe',
  );
}
