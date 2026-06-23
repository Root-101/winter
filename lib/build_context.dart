import 'package:winter/winter.dart';

class BuildContext {
  ///When was this context created
  final DateTime timestamp;

  final ObjectMapper objectMapper;

  final ExceptionHandler exceptionHandler;

  final DependencyInjection dependencyInjection;

  BuildContext({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
  }) : timestamp = DateTime.now(),
       objectMapper = objectMapper ?? ObjectMapper(),
       exceptionHandler = exceptionHandler ?? SimpleExceptionHandler(),
       dependencyInjection = dependencyInjection ?? DependencyInjection();
}
