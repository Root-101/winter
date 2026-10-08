import 'package:winter/winter.dart';

/// What the whole app shares: the object mapper, the exception handler, the dependencies, the
/// configuration, the logger and the languages. The global one is `Winter.context`, read through
/// `om`, `eh`, `di`, `env` and `logger`; it exists before the server starts.
///
/// ```dart
/// Winter.context.setUp(
///   objectMapper: ObjectMapper(fieldNaming: FieldNaming.snakeCase),
///   logger: const JsonLogger(),
/// );
/// ```
///
/// {@category Server}
class WinterContext {
  ///When was this context created
  final DateTime timestamp;

  ObjectMapper _objectMapper;

  /// The object mapper (`om`)
  ObjectMapper get objectMapper => _objectMapper;

  ExceptionHandler _exceptionHandler;

  /// The exception handler (`eh`)
  ExceptionHandler get exceptionHandler => _exceptionHandler;

  DependencyInjection _dependencyInjection;

  /// The dependencies (`di`)
  DependencyInjection get dependencyInjection => _dependencyInjection;

  Env _env;

  /// The configuration (`env`)
  Env get env => _env;

  WinterLogger _logger;

  /// The logger (`logger`)
  WinterLogger get logger => _logger;

  LocaleConfig _localeConfig;

  ///Languages of the responses, used by `request.locale`
  LocaleConfig get localeConfig => _localeConfig;

  /// A context; what isn't given has its default (`ConsoleLogger`, `SimpleExceptionHandler`...)
  WinterContext({
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

  /// Replaces the values given and keeps the rest
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
