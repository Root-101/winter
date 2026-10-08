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
    final bool hadPrevious = injection.isRegistered<S>();
    final S? previous = hadPrevious ? injection.find<S>() : null;
    injection.put<S>(value);
    return () {
      if (hadPrevious) {
        injection.put<S>(previous as S);
      } else if (injection.isRegistered<S>()) {
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
        config ?? injection.tryFind<ServerConfig>() ?? const ServerConfig();

    ///Before registering anything or opening the port: a const constructor can't check its values
    nonNullConfig.validate();
    restores.add(_putRestorable<ServerConfig>(injection, nonNullConfig));

    ///Found with the same type it's registered with (any router, ex: a MultiRouter),
    ///or as a WinterRouter (`di.put(WinterRouter(...))` infers that type)
    AbstractWinterRouter nonNullRouter =
        router ??
        injection.tryFind<AbstractWinterRouter>() ??
        injection.tryFind<WinterRouter>() ??
        WinterRouter();
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
        shared: nonNullConfig.shared,
        nonNullConfig.host,
        nonNullConfig.port,
      );
    } catch (_) {
      ///The server never started (ex: port in use), don't leave its dependencies behind
      restoreDependencies();
      rethrow;
    }

    ///dart:io adds its own headers to every response: `Content-Type: text/plain` (a response
    ///without body has no type), `X-Frame-Options`, `X-Content-Type-Options` and the obsolete
    ///`X-XSS-Protection`. They are removed: Winter adds its security headers itself
    ///(`_securityHeaders`), so the server and `WinterTestClient` answer the same.
    rawServer.defaultResponseHeaders.clear();

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

    warnLocalesWithoutWinterMessages(_context.localeConfig);

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
  ///then calls [ServerConfig.onShutdown], and then disposes the dependencies
  ///(`di.disposeAll()`, their `onDispose` in reverse order of registration).
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

    ///The `onDispose` of the dependencies (close the database...), after the requests and onShutdown
    await di.disposeAll();
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
  /// On every response (`SecurityHeaders` adds more): the browser never guesses the type of a
  /// response, and an API is never shown in a frame
  static final Map<String, String> _securityHeaders = {
    HttpHeader.xContentTypeOptions: 'nosniff',
    HttpHeader.xFrameOptions: 'DENY',
  };

  static FilterConfig _globalFilters(
    SecurityConfig securityConfig,
    FilterConfig? globalFilterConfig,
  ) {
    final corsConfig = securityConfig.cors();
    final securityHeaders = securityConfig.securityHeaders;
    return FilterConfig([
      if (corsConfig != null) CorsFilter(config: corsConfig),
      if (securityHeaders != null)
        SecurityHeadersFilter(config: securityHeaders),
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
    ///and the scope share the same security context and locale.
    ///(Outside the zone yet: reading `request.locale` here doesn't mark the scope)
    final String? sentId = requestEntity.headers[HttpHeader.xRequestId];
    final RequestScope scope = RequestScope(
      securityContext: requestEntity.securityContext,
      locale: requestEntity.locale,
      requestId: RequestScope.isValidRequestId(sentId) ? sentId : null,
    );
    final Response pipelineResponse = await RequestScope.run(scope, () async {
      try {
        return await _runPipeline(
          requestEntity: requestEntity,
          router: router,
          globalFilterConfig: globalFilterConfig,
        );
      } finally {
        ///The callbacks of `scope.onComplete` (the scoped dependencies are disposed there)
        await scope.complete();
      }
    });

    ///The id of the request goes back to the client (and the next proxy), to find its logs,
    ///with the basic security headers (unless the response set them)
    final Response response = pipelineResponse.change(
      headers: {
        HttpHeader.xRequestId: scope.requestId,
        for (final MapEntry(:key, :value) in _securityHeaders.entries)
          if (!pipelineResponse.headers.containsKey(key)) key: value,
      },
    );

    ///Some code used the language of the request, so the response depends on it
    ///(only if the app answers in more than one language)
    if (scope.localeRead && Winter.context.localeConfig.supported.length > 1) {
      return addVary(response, HttpHeader.acceptLanguage);
    }
    return response;
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
    } catch (error, stackTrace) {
      ///Errors outside the chain (like routing)
      return _handleError(requestEntity, error, stackTrace);
    }
  }

  /// [eh] answers the error; if [eh] itself fails, the error is logged and the answer is a
  /// generic 500, so a broken exception handler never leaves the request without a response
  static Future<ResponseEntity> _handleError(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      return await eh.call(request, error, stackTrace);
    } catch (handlerError, handlerStackTrace) {
      defaultLogUnhandledError(request, error, stackTrace);
      defaultLogUnhandledError(request, handlerError, handlerStackTrace);
      return internalServerErrorResponse();
    }
  }
}

/// Add [header] to the `Vary` of [response] (a comma separated list), unless it's already there or `*`
Response addVary(Response response, String header) {
  final String? current = response.headers[HttpHeader.vary];
  if (current == null || current.trim().isEmpty) {
    return response.change(headers: {HttpHeader.vary: header});
  }

  final Iterable<String> values = current
      .split(',')
      .map((v) => v.trim().toLowerCase());
  if (values.contains('*') || values.contains(header.toLowerCase())) {
    return response;
  }
  return response.change(headers: {HttpHeader.vary: '$current, $header'});
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
    throw const PayloadTooLargeException();
  }

  int readBytes = 0;
  await for (final chunk in body) {
    readBytes += chunk.length;
    if (readBytes > maxBytes) {
      throw const PayloadTooLargeException();
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
