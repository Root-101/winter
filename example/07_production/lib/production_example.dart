import 'package:winter/winter.dart';

/// A stand-in for a connection pool: it can be checked and must be closed on shutdown
class Database {
  final String url;
  bool _open = true;

  Database(this.url);

  bool get isOpen => _open;

  /// Whether the database answers (readiness)
  Future<bool> ping() async => _open;

  Future<void> close() async => _open = false;
}

class ProductionApp {
  /// Every variable the app needs, checked at once: a container that misses two of them names
  /// both in one restart
  static const List<String> requiredVariables = ['DATABASE_URL'];

  /// The configuration: `.env` and `.env.<WINTER_PROFILE>` under the variables of the process
  /// (in a container, the platform sets them and the files don't exist)
  static Env loadEnv({
    String directory = '.',
    Map<String, String>? environment,
  }) {
    final env = Env.load(directory: directory, environment: environment);
    env.requireAll(requiredVariables);
    return env;
  }

  /// JSON logs in production (one object per line, with the request id), readable ones locally
  static WinterLogger loggerFor(Env env) {
    final LogLevel level =
        env.findEnum('LOG_LEVEL', LogLevel.values) ?? LogLevel.info;
    return env.find<String>('LOG_FORMAT') == 'json'
        ? JsonLogger(minLevel: level)
        : ConsoleLogger(minLevel: level);
  }

  static WinterRouter router() => WinterRouter(
    routes: [
      /// Liveness: the process answers
      Route.health(path: '/health'),

      /// Readiness: the dependencies answer (a 503 takes the instance out of the load balancer)
      Route.health(
        path: '/ready',
        checks: {'database': () => di.find<Database>().ping()},
      ),
      Route.get(
        path: '/hello',
        handler: (request) {
          logger.info(
            'Greeting',
            fields: {'name': request.queryParam<String>('name')},
          );
          return ResponseEntity.ok(
            body: 'Hello from ${env.profile ?? 'local'}',
          );
        },
      ),
    ],
  );

  static FilterConfig filters(Env env) => FilterConfig([
    LoggingFilter(),
    RateLimiterFilter(
      maxRequests: env.find<int>('RATE_LIMIT') ?? 100,
      window: const Duration(minutes: 1),

      /// Behind the load balancer, the client is in X-Forwarded-For
      clientId: (request) =>
          request.clientIp(
            trustedProxies: env.find<int>('TRUSTED_PROXIES') ?? 0,
          ) ??
          'unknown',
    ),
  ]);

  static SecurityConfig security(Env env) => SecurityConfig(
    cors: CorsConfig(
      allowedOrigins: env.find<List<String>>('CORS_ORIGINS') ?? const [],
      allowCredentials: true,
    ),
    securityHeaders: SecurityHeaders(hsts: env.find<bool>('HSTS') ?? false),
  );

  static Future<void> start({Env? env}) async {
    final Env config = env ?? loadEnv();
    Winter.context.setUp(env: config, logger: loggerFor(config));

    /// Closed by Winter.shutdown() on SIGTERM, after the requests in progress
    di.put<Database>(
      Database(config.require<String>('DATABASE_URL')),
      onDispose: (database) => database.close(),
    );

    await Winter.start(
      config: ServerConfig.fromEnv(
        config,
        maxBodySize: config.find<int>('MAX_BODY_SIZE') ?? 1024 * 1024,

        /// Below the grace period of the platform (Kubernetes: 30 s by default)
        shutdownTimeout:
            config.find<Duration>('SHUTDOWN_TIMEOUT') ??
            const Duration(seconds: 25),
        onShutdown: () => logger.info('Stopped accepting requests'),
      ),
      router: router(),
      globalFilterConfig: filters(config),
      securityConfig: security(config),
    );
  }
}
