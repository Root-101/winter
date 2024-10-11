import 'winter.dart';

class BuildContext {
  ///When was this context created
  final DateTime timestamp;

  final ObjectMapper objectMapper;

  final ValidationService validationService;

  final ExceptionHandler exceptionHandler;

  final DependencyInjection dependencyInjection;

  BuildContext({
    ObjectMapper? objectMapper,
    ValidationService? validationService,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
  })  : timestamp = DateTime.now(),
        objectMapper = objectMapper ?? ObjectMapperImpl(),
        validationService = validationService ?? ValidationServiceImpl(),
        exceptionHandler = exceptionHandler ?? SimpleExceptionHandler(),
        dependencyInjection = DependencyInjection.instance;
}
