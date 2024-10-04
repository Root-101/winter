import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/src/request.dart';
import 'package:shelf/src/response.dart';

import 'winter.dart';

///Dependency Injection: easy access to the current dependency injection instance
WinterDI get di => WinterServer.instance.context.dependencyInjection;

///Dependency Injection: easy access to the current object mapper instance
ObjectMapper get om => WinterServer.instance.context.objectMapper;

///Validation Service: easy access to the current validation service instance
ValidationService get vs => WinterServer.instance.context.validationService;

///Exception Handler: easy access to the current exception handler instance
ExceptionHandler get eh => WinterServer.instance.context.exceptionHandler;

typedef WinterHandler = FutureOr<ResponseEntity> Function(
  RequestEntity request,
);

class WinterServer {
  static WinterServer get instance {
    if (_winterServer == null) {
      throw StateError(
          'Server hasn\'t starter yet. Try calling start() first.');
    }
    return _winterServer!;
  }

  static WinterServer? _winterServer;

  final BuildContext context;
  final ServerConfig config;
  final AbstractWinterRouter router;
  final FilterConfig filterConfig;

  late final HttpServer runningServer;

  bool get isRunning => _isRunning;
  bool _isRunning = false;

  WinterServer({
    BuildContext? context,
    ServerConfig? config,
    AbstractWinterRouter? router,
    ExceptionHandler? exceptionHandler,
    WinterDI? di,
    FilterConfig? filterConfig,
  })  : context = context ?? BuildContext(),
        config = config ?? ServerConfig(),
        router = router ?? WinterRouter(),
        filterConfig = filterConfig ?? FilterConfig([]);

  ///Start the web server with all the current config in this object
  ///beforeStart:
  /// - Function to be called right before the server actually start
  /// - Its delay is counted in the `start time` of the server
  /// - Waits for it to complete to start the server
  /// - Calling `WinterServer.instance` in this method will result in an `StateError` because the server isnt already started
  ///afterStart:
  /// - Function to be called right after the server actually start
  /// - Its delay is counted in the `start time` of the server
  /// - Waits for it to complete to mark the server as started
  /// - In this method the `WinterServer.instance` will already by initialized
  Future<WinterServer> start({
    Future Function()? beforeStart,
    Future Function()? afterStart,
  }) async {
    if (_winterServer != null) {
      throw StateError('Server already starter');
    }

    final startTime = DateTime.now();

    if (beforeStart != null) {
      await beforeStart();
    }

    runningServer = await shelf_io.serve(
      poweredByHeader: 'Winter-Server',
      _handleRequest,
      config.ip,
      config.port,
    );

    _winterServer = this;

    if (afterStart != null) {
      await afterStart();
    }

    final endTime = DateTime.now();
    double timeDiff = endTime.difference(startTime).inMilliseconds / 1000;
    print('Server started on port ${runningServer.port} ($timeDiff sec)');

    _isRunning = true;

    return this;
  }

  Future close({bool force = false}) async {
    _isRunning = false;
    _winterServer = null;
    await runningServer.close(force: force);
  }

  FutureOr<Response> _handleRequest(Request request) async {
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
      WinterHandler baseCall = router.call(requestEntity);

      FilterChain filterChain = FilterChain(
        filterConfig.filters,
        baseCall,
      );

      return await filterChain.doFilter(requestEntity);
    } on Exception catch (error, stackTrace) {
      return WinterServer.instance.context.exceptionHandler.call(
        requestEntity,
        error,
        stackTrace,
      );
    }
  }
}
