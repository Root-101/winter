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

  WinterLogger _logger;

  WinterLogger get logger => _logger;

  LocaleConfig _localeConfig;

  ///Languages of the responses, used by `request.locale`
  LocaleConfig get localeConfig => _localeConfig;

  BuildContext({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
    Env? env,
    WinterLogger? logger,
    LocaleConfig? localeConfig,
  }) : timestamp = DateTime.now(),
       _logger = logger ?? const ConsoleLogger(),
       _objectMapper = objectMapper ?? ObjectMapper(),
       _exceptionHandler = exceptionHandler ?? SimpleExceptionHandler(),
       _dependencyInjection = dependencyInjection ?? DependencyInjection(),
       _env = env ?? Env(),
       _localeConfig = localeConfig ?? LocaleConfig();

  void setUp({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
    Env? env,
    WinterLogger? logger,
    LocaleConfig? localeConfig,
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
    if (logger != null) {
      _logger = logger;
    }
    if (localeConfig != null) {
      _localeConfig = localeConfig;
    }
  }
}
