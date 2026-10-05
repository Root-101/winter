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

  ///Requests being handled right now, to wait for them on a graceful close
  final _InFlightRequests _inFlightRequests;

  ///Restore the dependencies registered by [start] to its previous state
  final void Function() _restoreDependencies;

  ///When was this server started
  final DateTime timestamp;

  ///Subscriptions to SIGINT/SIGTERM (see [ServerConfig.handleSignals])
  List<StreamSubscription<ProcessSignal>> _signalSubscriptions = [];

  bool _shuttingDown = false;

  Winter._({
    required this.serverContext,
    required this.config,
    required this.router,
    required this.globalFilterConfig,
    required this.securityConfig,
    required this._rawServer,
    required this._inFlightRequests,
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

    FilterConfig nonNullGlobalFilterConfig = _globalFilters(
      nonNullSecurityConfig,
      globalFilterConfig,
    );

    final _InFlightRequests inFlightRequests = _InFlightRequests();
    final HttpServer rawServer;
    try {
      rawServer = await shelf_io.serve(
        poweredByHeader: 'Winter-Server',
        _buildHandler(
          router: nonNullRouter,
          globalFilterConfig: nonNullGlobalFilterConfig,
          maxBodySize: nonNullConfig.maxBodySize,
          inFlightRequests: inFlightRequests,
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

    ///dart:io adds `Content-Type: text/plain` to every response without one
    ///(ex: a 204, or a 401/404 without body): a response without body has no type.
    ///The other default headers (X-Frame-Options, X-Content-Type-Options...) are kept.
    rawServer.defaultResponseHeaders.removeAll(HttpHeaders.contentTypeHeader);

    Winter nextRunningServer = Winter._(
      serverContext: _context,
      config: nonNullConfig,
      router: nonNullRouter,
      globalFilterConfig: nonNullGlobalFilterConfig,
      securityConfig: nonNullSecurityConfig,
      rawServer: rawServer,
      inFlightRequests: inFlightRequests,
      restoreDependencies: restoreDependencies,
    );

    _server = nextRunningServer;

    if (nonNullConfig.handleSignals) {
      nextRunningServer._signalSubscriptions = _watchShutdownSignals();
    }

    final endTime = DateTime.now();
    double timeDiff = endTime.difference(startTime).inMilliseconds / 1000;
    logger.info('Server started on port ${rawServer.port} ($timeDiff sec)');

    return nextRunningServer;
  }

  ///Close the server.
  ///
  ///If [force] is false, the server stops accepting connections and waits for the
  ///requests in progress. With a [timeout], the remaining connections are closed after it.
  static Future close({
    bool force = false,
    Duration? timeout,
    void Function()? onNotRunning,
    @Deprecated('Use onNotRunning instead') void Function()? onAlreadyStarted,
  }) async {
    if (isRunning) {
      final Winter current = server;

      if (force) {
        ///Not awaited: if the server is already closing, this future never completes
        ///(the active connections are destroyed synchronously anyway)
        unawaited(current._rawServer.close(force: true));
        current._inFlightRequests.stopWaiting();
      } else {
        ///Stop accepting connections. It does NOT wait for the requests in progress,
        ///that's why they are tracked by [_inFlightRequests]
        await current._rawServer.close();
        final Future<void> idle = current._inFlightRequests.whenIdle();
        if (timeout == null) {
          await idle;
        } else {
          await idle.timeout(
            timeout,
            onTimeout: () {
              logger.warning(
                'Closing ${current._inFlightRequests.count} request(s) still in progress after $timeout',
              );
              unawaited(current._rawServer.close(force: true));
            },
          );
        }
      }
      for (final subscription in current._signalSubscriptions) {
        await subscription.cancel();
      }
      current._restoreDependencies();
      if (identical(_server, current)) {
        _server = null;
      }
    } else {
      final notRunningCallback = onNotRunning ?? onAlreadyStarted;
      if (notRunningCallback != null) {
        notRunningCallback();
      } else {
        logger.info('Server not running');
      }
    }
  }

  ///Graceful shutdown, called on SIGINT/SIGTERM (see [ServerConfig.handleSignals]):
  ///waits for the requests in progress (up to [ServerConfig.shutdownTimeout]),
  ///then calls [ServerConfig.onShutdown].
  ///
  ///Calling it again while it's shutting down (ex: a second Ctrl+C) forces the close.
  ///It never calls `exit`: once the signals are released, a new signal has its default behavior.
  static Future<void> shutdown() async {
    if (!isRunning) return;
    final Winter current = server;

    if (current._shuttingDown) {
      logger.warning('Forcing the shutdown, closing the requests in progress');
      await close(force: true);
      return;
    }
    current._shuttingDown = true;

    logger.info(
      'Shutting down, waiting up to ${current.config.shutdownTimeout.inSeconds} s for the requests in progress...',
    );
    await close(timeout: current.config.shutdownTimeout);
    await current.config.onShutdown?.call();
    logger.info('Server stopped');
  }

  static List<StreamSubscription<ProcessSignal>> _watchShutdownSignals() {
    final List<StreamSubscription<ProcessSignal>> subscriptions = [];
    for (final signal in [
      ProcessSignal.sigint,
      if (!Platform.isWindows) ProcessSignal.sigterm,
    ]) {
      try {
        subscriptions.add(signal.watch().listen((_) => shutdown()));
      } on SignalException {
        ///Not supported in this platform
      }
    }
    return subscriptions;
  }

  /// The full request pipeline of a server (CORS, filters, routing, exception handler,
  /// body size limit...) as a shelf [Handler], without opening any port.
  ///
  /// [start] uses it, and tests can call it directly (see `WinterTestClient`):
  /// it's the same code that handles the requests of a real server.
  static Handler buildHandler({
    required AbstractWinterRouter router,
    FilterConfig? globalFilterConfig,
    SecurityConfig? securityConfig,
    int? maxBodySize = defaultMaxBodySize,
  }) {
    return _buildHandler(
      router: router,
      globalFilterConfig: _globalFilters(
        securityConfig ?? SecurityConfig(),
        globalFilterConfig,
      ),
      maxBodySize: maxBodySize,
    );
  }

  static Handler _buildHandler({
    required AbstractWinterRouter router,
    required FilterConfig globalFilterConfig,
    required int? maxBodySize,
    _InFlightRequests? inFlightRequests,
  }) {
    return (request) async {
      inFlightRequests?.start();
      try {
        return await _handleRunRequest(
          router: router,
          globalFilterConfig: globalFilterConfig,
          maxBodySize: maxBodySize,
          request: request,
        );
      } finally {
        inFlightRequests?.end();
      }
    };
  }

  /// The global filters, with the [CorsFilter] first if CORS is enabled in the [SecurityConfig]
  static FilterConfig _globalFilters(
    SecurityConfig securityConfig,
    FilterConfig? globalFilterConfig,
  ) {
    final corsConfig = securityConfig.cors();
    return FilterConfig([
      if (corsConfig != null) CorsFilter(config: corsConfig),
      ...?globalFilterConfig?.filters,
    ]);
  }

  static FutureOr<Response> _handleRunRequest({
    required Request request,
    required AbstractWinterRouter router,
    required FilterConfig globalFilterConfig,
    required int? maxBodySize,
  }) async {
    RequestEntity requestEntity = RequestEntity(
      request.method,
      request.requestedUri,
      body: maxBodySize == null
          ? request.read()
          : limitBodySize(
              request.read(),
              maxBytes: maxBodySize,
              contentLength: request.contentLength,
            ),
      context: request.context,
      encoding: request.encoding,
      handlerPath: request.handlerPath,
      headers: request.headers,
      protocolVersion: request.protocolVersion,
      url: request.url,
    );

    ///Created now and not lazily, so the request, its changes (`change` copies the context)
    ///and the scope share the same security context and locale
    final RequestScope scope = RequestScope(
      securityContext: requestEntity.securityContext,
      locale: requestEntity.locale,
    );
    return RequestScope.run(
      scope,
      () => _runPipeline(
        requestEntity: requestEntity,
        router: router,
        globalFilterConfig: globalFilterConfig,
      ),
    );
  }

  /// Routing, filters and handler of [requestEntity], with the exception handler
  static Future<Response> _runPipeline({
    required RequestEntity requestEntity,
    required AbstractWinterRouter router,
    required FilterConfig globalFilterConfig,
  }) async {
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

/// Fail (with a [PayloadTooLargeException], a 413) when the body is bigger than [maxBytes].
///
/// The check is done while the body is read, so a request is only rejected if its body is used,
/// and the body is never fully loaded in memory:
/// - if the `Content-Length` header is bigger than the limit, it fails before reading anything
/// - otherwise (ex: chunked requests) it fails as soon as the read bytes exceed the limit
Stream<List<int>> limitBodySize(
  Stream<List<int>> body, {
  required int maxBytes,
  int? contentLength,
}) async* {
  if (contentLength != null && contentLength > maxBytes) {
    throw PayloadTooLargeException();
  }

  int readBytes = 0;
  await for (final chunk in body) {
    readBytes += chunk.length;
    if (readBytes > maxBytes) {
      throw PayloadTooLargeException();
    }
    yield chunk;
  }
}

/// Counter of the requests being handled, to know when a server can be closed gracefully
class _InFlightRequests {
  int count = 0;
  Completer<void>? _idle;

  void start() => count++;

  void end() {
    count--;
    if (count == 0) {
      _idle?.complete();
      _idle = null;
    }
  }

  bool _stopped = false;

  /// Stop waiting, now and in the future (the connections were forcefully closed)
  void stopWaiting() {
    _stopped = true;
    _idle?.complete();
    _idle = null;
  }

  /// Completes when there is no request in progress
  Future<void> whenIdle() {
    if (count == 0 || _stopped) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }
}
