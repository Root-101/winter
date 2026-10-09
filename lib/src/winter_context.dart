import 'package:winter/src/context/object_mapper/object_mapper.dart'
    show lostRegistrations;
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
  }) : _logger = logger ?? const ConsoleLogger(),
       _objectMapper = objectMapper ?? ObjectMapper(),
       _exceptionHandler = exceptionHandler ?? SimpleExceptionHandler(),
       _dependencyInjection = dependencyInjection ?? DependencyInjection(),
       _env = env ?? Env(),
       _localeConfig = localeConfig ?? LocaleConfig();

  /// What the app registered in the mapper being replaced and the new one doesn't have: a
  /// `request.body<User>()` would be a 500 at runtime, so it's said now. (Register them in the
  /// new mapper, or set up the mapper before registering.)
  void _warnLostRegistrations(ObjectMapper previous, ObjectMapper next) {
    if (identical(previous, next)) return;
    final List<Type> lost = lostRegistrations(previous, next);
    if (lost.isEmpty) return;
    _logger.warning(
      'The object mapper was replaced, and the new one has no serializer or deserializer of '
      '${lost.join(', ')}, registered in the previous one. Register them in the new mapper, '
      'or set up the mapper before registering them.',
    );
  }

  /// Replaces the values given and keeps the rest. Replacing the object mapper warns about the
  /// serializers and deserializers of the app that the new one doesn't have.
  void setUp({
    ObjectMapper? objectMapper,
    ExceptionHandler? exceptionHandler,
    DependencyInjection? dependencyInjection,
    Env? env,
    WinterLogger? logger,
    LocaleConfig? localeConfig,
  }) {
    if (objectMapper != null) {
      _warnLostRegistrations(_objectMapper, objectMapper);
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
