import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:winter/winter.dart';

///Dependency Injection: easy access to the current dependency injection instance
DependencyInjection get di => Winter.context.dependencyInjection;

///Dependency Injection: easy access to the current object mapper instance
ObjectMapper get om => Winter.context.objectMapper;

///Exception Handler: easy access to the current exception handler instance
ExceptionHandler get eh => Winter.context.exceptionHandler;

Env get env => Winter.context.env;

///Logger: easy access to the current logger instance
WinterLogger get logger => Winter.context.logger;

class Winter {
  static BuildContext _context = BuildContext();

  /// Access to the global context, available even before starting the server.
  static BuildContext get context => _context;

  static Winter? _server;

  /// Access to the global server, It needs to be started in order to access it
  static Winter get server {
    if (_server == null) {
      throw StateError('Server hasn\'t started yet. Try starting one first.');
    }
    return _server!;
  }

  static bool get isRunning => _server != null;

  final BuildContext serverContext;
  final ServerConfig config;
  final AbstractWinterRouter router;
  final FilterConfig globalFilterConfig;
  final SecurityConfig securityConfig;

  final HttpServer _rawServer;

  ///Restore the dependencies registered by [start] to its previous state
  final void Function() _restoreDependencies;

  ///When was this server started
  final DateTime timestamp;

  Winter._({
    required this.serverContext,
    required this.config,
    required this.router,
    required this.globalFilterConfig,
    required this.securityConfig,
    required this._rawServer,
    required this._restoreDependencies,
  }) : timestamp = DateTime.now();

  ///Register [value] in [injection] and return a function that restores the previous value (or deletes it if there was none)
  static void Function() _putRestorable<S>(
    DependencyInjection injection,
    S value,
  ) {
    final S? previous = injection.tryFind<S>();
    injection.put<S>(value);
    return () {
      if (previous != null) {
        injection.put<S>(previous);
      } else if (injection.tryFind<S>() != null) {
        injection.delete<S>();
      }
    };
  }

  static Future<Winter> start({
    BuildContext? context,
    ServerConfig? config,
    AbstractWinterRouter? router,
    FilterConfig? globalFilterConfig,
    SecurityConfig? securityConfig,
    bool shared = false,
  }) async {
    if (isRunning) {
      throw StateError('Server already started');
    }

    final startTime = DateTime.now();

    if (context != null) {
      _context = context;
    }

    ///Everything registered here is restored on [close], so nothing leaks to the next server
    final DependencyInjection injection = di;
    final List<void Function()> restores = [];
    void restoreDependencies() {
      for (final restore in restores.reversed) {
        restore();
      }
    }

    ServerConfig nonNullConfig =
        config ?? injection.tryFind<ServerConfig>() ?? ServerConfig();
    restores.add(_putRestorable<ServerConfig>(injection, nonNullConfig));

    AbstractWinterRouter nonNullRouter =
        router ?? injection.tryFind<WinterRouter>() ?? WinterRouter();
    restores.add(
      _putRestorable<AbstractWinterRouter>(injection, nonNullRouter),
    );

    SecurityConfig nonNullSecurityConfig =
        securityConfig ??
        injection.tryFind<SecurityConfig>() ??
        SecurityConfig();
    restores.add(
      _putRestorable<SecurityConfig>(injection, nonNullSecurityConfig),
    );

    List<Filter> filters = [];

    // Check for CORS configuration in SecurityConfig
    final corsConfig = nonNullSecurityConfig.cors();
    if (corsConfig != null) {
      filters.insert(0, CorsFilter(config: corsConfig));
    }

    filters.addAll(globalFilterConfig?.filters ?? []);

    FilterConfig nonNullGlobalFilterConfig = FilterConfig(filters);

    final HttpServer rawServer;
    try {
      rawServer = await shelf_io.serve(
        poweredByHeader: 'Winter-Server',
        (request) => _handleRunRequest(
          router: nonNullRouter,
          globalFilterConfig: nonNullGlobalFilterConfig,
          request: request,
        ),
        shared: shared,
        nonNullConfig.ip,
        nonNullConfig.port,
      );
    } catch (_) {
      ///The server never started (ex: port in use), don't leave its dependencies behind
      restoreDependencies();
      rethrow;
    }

    Winter nextRunningServer = Winter._(
      serverContext: _context,
      config: nonNullConfig,
      router: nonNullRouter,
      globalFilterConfig: nonNullGlobalFilterConfig,
      securityConfig: nonNullSecurityConfig,
      rawServer: rawServer,
      restoreDependencies: restoreDependencies,
    );

    _server = nextRunningServer;

    final endTime = DateTime.now();
    double timeDiff = endTime.difference(startTime).inMilliseconds / 1000;
    stdout.writeln('Server started on port ${rawServer.port} ($timeDiff sec)');

    return nextRunningServer;
  }

  static Future close({
    bool force = false,
    void Function()? onNotRunning,
    @Deprecated('Use onNotRunning instead') void Function()? onAlreadyStarted,
  }) async {
    if (isRunning) {
      await server._rawServer.close(force: force);
      server._restoreDependencies();
      _server = null;
    } else {
      final notRunningCallback = onNotRunning ?? onAlreadyStarted;
      if (notRunningCallback != null) {
        notRunningCallback();
      } else {
        stdout.writeln('Server not running');
      }
    }
  }

  static FutureOr<Response> _handleRunRequest({
    required Request request,
    required AbstractWinterRouter router,
    required FilterConfig globalFilterConfig,
  }) async {
    RequestEntity requestEntity = RequestEntity(
      request.method,
      request.requestedUri,
      body: request.read(),
      context: request.context,
      encoding: request.encoding,
      handlerPath: request.handlerPath,
      headers: request.headers,
      protocolVersion: request.protocolVersion,
      url: request.url,
    );

    try {
      FilterConfig? routeFilterConfig;
      Route? route = router.resolveRoute(requestEntity);

      if (route != null) {
        ///set-up the filter config from route
        routeFilterConfig = route.filterConfig;

        ///set-up path params
        requestEntity.setRoutingContext(
          RequestRoutingContext(
            path: route.path,
            key: route.key,
            method: route.method!,
          ),
        );
      }

      ///The exception handler goes inside the chain, so every filter
      ///(CORS, logs, rate limiter...) also sees the error responses
      FilterChain filterChain = FilterChain(
        [
          ...globalFilterConfig.filters,
          if (routeFilterConfig != null) ...routeFilterConfig.filters,
        ],
        router.handler,
        exceptionHandler: eh,
      );

      return await filterChain.doFilter(requestEntity);
    } on Exception catch (error, stackTrace) {
      ///Exceptions outside the chain (like routing)
      return eh.call(requestEntity, error, stackTrace);
    } on Error catch (error, stackTrace) {
      ///Errors are bugs (StateError, TypeError...): log them and don't expose its details
      final currentEh = eh;
      final log = currentEh is SimpleExceptionHandler
          ? currentEh.logUnhandledError
          : defaultLogUnhandledError;
      log(requestEntity, error, stackTrace);
      return internalServerErrorResponse();
    }
  }
}
