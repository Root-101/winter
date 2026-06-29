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

  final HttpServer _rawServer;

  ///When was this server started
  final DateTime timestamp;

  Winter._({
    required this.serverContext,
    required this.config,
    required this.router,
    required this.globalFilterConfig,
    required this._rawServer,
  }) : timestamp = DateTime.now();

  static Future<Winter> start({
    BuildContext? context,
    ServerConfig? config,
    AbstractWinterRouter? router,
    FilterConfig? globalFilterConfig,
  }) async {
    if (isRunning) {
      throw StateError('Server already started');
    }

    final startTime = DateTime.now();

    if (context != null) {
      _context = context;
    }

    ServerConfig nonNullConfig = config ?? ServerConfig();
    AbstractWinterRouter nonNullRouter = router ?? WinterRouter();
    FilterConfig nonNullGlobalFilterConfig =
        globalFilterConfig ?? const FilterConfig([]);

    HttpServer rawServer = await shelf_io.serve(
      poweredByHeader: 'Winter-Server',
      (request) => _handleRunRequest(
        router: nonNullRouter,
        globalFilterConfig: nonNullGlobalFilterConfig,
        request: request,
      ),
      nonNullConfig.ip,
      nonNullConfig.port,
    );

    Winter nextRunningServer = Winter._(
      serverContext: _context,
      config: nonNullConfig,
      router: nonNullRouter,
      globalFilterConfig: nonNullGlobalFilterConfig,
      rawServer: rawServer,
    );

    _server = nextRunningServer;

    final endTime = DateTime.now();
    double timeDiff = endTime.difference(startTime).inMilliseconds / 1000;
    stdout.writeln('Server started on port ${rawServer.port} ($timeDiff sec)');

    return nextRunningServer;
  }

  static Future close({
    bool force = false,
    void Function()? onAlreadyStarted,
  }) async {
    if (isRunning) {
      await server._rawServer.close(force: force);
      _server = null;
    } else {
      if (onAlreadyStarted != null) {
        onAlreadyStarted();
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
      if (router is WinterRouter) {
        Route? route = router.handlerRoute(requestEntity);

        if (route != null) {
          ///set-up the filter config from route
          routeFilterConfig = router.handlerRoute(requestEntity)?.filterConfig;

          ///set-up path params
          requestEntity.setRoutingContext(
            RequestRoutingContext(
              path: route.path,
              key: route.key,
              method: route.method!,
            ),
          );
        }
      }

      FilterChain filterChain = FilterChain([
        ...globalFilterConfig.filters,
        if (routeFilterConfig != null) ...routeFilterConfig.filters,
      ], router.handler);

      return await filterChain.doFilter(requestEntity);
    } on Exception catch (error, stackTrace) {
      return eh.call(requestEntity, error, stackTrace);
    } on Error catch (error, _) {
      return ResponseEntity.internalServerError(body: error.toString());
    }
  }
}
