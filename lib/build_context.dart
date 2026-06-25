import 'package:winter/winter.dart';

class BuildContext {
  ///When was this context created
  final DateTime timestamp;

  final ObjectMapper objectMapper;

  final ExceptionHandler exceptionHandler;

  final DependencyInjection dependencyInjection;

  final Env env;

  BuildContext({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
    Env? env,
  }) : timestamp = DateTime.now(),
       objectMapper = objectMapper ?? ObjectMapper(),
       exceptionHandler = exceptionHandler ?? SimpleExceptionHandler(),
       dependencyInjection = dependencyInjection ?? DependencyInjection(),
       env = env ?? Env();
}
