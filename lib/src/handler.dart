import 'dart:async';

import 'package:winter/winter.dart';

/// A function that answers a [RequestEntity] with a [ResponseEntity]: the handler of a `Route`,
/// and the whole pipeline that `Winter.buildHandler` returns (what `WinterTestClient` calls).
///
/// Code that runs before or after a handler is a `Filter`.
typedef RequestHandler = FutureOr<ResponseEntity> Function(
  RequestEntity request,
);
