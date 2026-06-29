import 'package:winter/winter.dart';

class BuildContext {
  ///When was this context created
  final DateTime timestamp;

  ObjectMapper _objectMapper;

  ObjectMapper get objectMapper => _objectMapper;

  ExceptionHandler _exceptionHandler;

  ExceptionHandler get exceptionHandler => _exceptionHandler;

  DependencyInjection _dependencyInjection;

  DependencyInjection get dependencyInjection => _dependencyInjection;

  Env _env;

  Env get env => _env;

  BuildContext({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
    Env? env,
  }) : timestamp = DateTime.now(),
       _objectMapper = objectMapper ?? ObjectMapper(),
       _exceptionHandler = exceptionHandler ?? SimpleExceptionHandler(),
       _dependencyInjection = dependencyInjection ?? DependencyInjection(),
       _env = env ?? Env();

  void setUp({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
    Env? env,
  }) {
    if (objectMapper != null) {
      _objectMapper = objectMapper;
    }
    if (exceptionHandler != null) {
      _exceptionHandler = exceptionHandler;
    }
    if (dependencyInjection != null) {
      _dependencyInjection = dependencyInjection;
    }
    if (env != null) {
      _env = env;
    }
  }
}
