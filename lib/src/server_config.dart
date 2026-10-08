import 'dart:async';
import 'dart:io' show SecurityContext;

import 'package:winter/winter.dart';

/// The port of a server without one: 8080
///
/// {@category Server}
const int defaultServerPort = 8080;

///10 MB
///
/// {@category Server}
const int defaultMaxBodySize = 10 * 1024 * 1024;

/// How the server runs: where it listens, the body limit and the graceful shutdown.
///
/// ```dart
/// await Winter.start(config: const ServerConfig(port: 9000));
/// await Winter.start(config: ServerConfig.fromEnv(env)); // PORT and HOST of the platform
/// ```
///
/// `Winter.start` validates it before opening the port (an [ArgumentError] for a port out of
/// 0-65535, a negative [maxBodySize] or [shutdownTimeout], or a [requestTimeout] that isn't
/// positive).
///
/// {@category Server}
class ServerConfig {
  ///Address on which the server listens: `'0.0.0.0'` (default, every IPv4 interface),
  ///`'localhost'`, `'127.0.0.1'`, `'::'`...
  final String host;

  ///Port on which the server listens. Default to [defaultServerPort] (8080); `0` picks a free one.
  final int port;

  ///If true, several isolates can listen on the same [port] (see
  ///`benchmark/server_shared_benchmark.dart`): the connections are balanced between them.
  final bool shared;

  ///Max size (in bytes) of the body of a request, a bigger body is rejected with a 413 (Payload Too Large)
  ///when it's read. It protects the server from running out of memory with huge requests.
  ///Default to `defaultMaxBodySize` (10 MB), `null` means no limit.
  final int? maxBodySize;

  ///If true (default), SIGINT (Ctrl+C) & SIGTERM shut the server down gracefully
  ///(see `Winter.shutdown`): the requests in progress finish before the server stops.
  ///Set it to false if your app handles the signals itself.
  final bool handleSignals;

  ///Max time to wait for the requests in progress on a graceful shutdown,
  ///after it the remaining connections are closed. Default to 10 seconds.
  final Duration shutdownTimeout;

  ///Called on a graceful shutdown after the server is closed and before the dependencies are
  ///disposed (`di.disposeAll()`), to release other resources
  final FutureOr<void> Function()? onShutdown;

  ///Compress the responses with gzip when the client accepts it (`Accept-Encoding`). Off by
  ///default: usually the proxy in front of the app compresses, and it costs CPU.
  final bool autoCompress;

  ///How long an idle keep-alive connection stays open. Default to 120 seconds (the one of
  ///`dart:io`); `null` keeps them open.
  final Duration? idleTimeout;

  ///Serve HTTPS with this certificate and key (`bindSecure`), or plain HTTP without it:
  ///
  ///```dart
  ///ServerConfig(
  ///  port: 8443,
  ///  securityContext: SecurityContext()
  ///    ..useCertificateChain('cert.pem')
  ///    ..usePrivateKey('key.pem'),
  ///)
  ///```
  ///
  ///Usually the proxy in front of the app (a load balancer, nginx) terminates TLS instead.
  final SecurityContext? securityContext;

  ///Max time to build the response of a request (the filters and the handler, reading its body
  ///included). After it the client gets a 503 and the request no longer holds a graceful
  ///shutdown; the handler can't be stopped, so it goes on in the background and its result is
  ///ignored. Sending the response is not timed (a stream, like Server-Sent Events, can go on).
  ///Default `null`: no limit. Leave room for the slow uploads of the app.
  final Duration? requestTimeout;

  /// The configuration of the server
  const ServerConfig({
    this.host = '0.0.0.0',
    this.port = defaultServerPort,
    this.shared = false,
    this.maxBodySize = defaultMaxBodySize,
    this.handleSignals = true,
    this.shutdownTimeout = const Duration(seconds: 10),
    this.onShutdown,
    this.autoCompress = false,
    this.idleTimeout = const Duration(seconds: 120),
    this.securityContext,
    this.requestTimeout,
  });

  /// The configuration with the `PORT` and `HOST` of [env], the variables that Cloud Run, Heroku,
  /// Render and Kubernetes set. [port] and [host] are the values without them.
  factory ServerConfig.fromEnv(
    Env env, {
    String host = '0.0.0.0',
    int port = defaultServerPort,
    bool shared = false,
    int? maxBodySize = defaultMaxBodySize,
    bool handleSignals = true,
    Duration shutdownTimeout = const Duration(seconds: 10),
    FutureOr<void> Function()? onShutdown,
    bool autoCompress = false,
    Duration? idleTimeout = const Duration(seconds: 120),
    SecurityContext? securityContext,
    Duration? requestTimeout,
  }) => ServerConfig(
    host: env.find<String>('HOST')?.trim() ?? host,
    port: env.find<int>('PORT') ?? port,
    shared: shared,
    maxBodySize: maxBodySize,
    handleSignals: handleSignals,
    shutdownTimeout: shutdownTimeout,
    onShutdown: onShutdown,
    autoCompress: autoCompress,
    idleTimeout: idleTimeout,
    securityContext: securityContext,
    requestTimeout: requestTimeout,
  );

  /// An [ArgumentError] if a value is out of its range (a `const` constructor can't check it)
  void validate() {
    if (port < 0 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'Must be between 0 and 65535');
    }
    final int? maxBodySize = this.maxBodySize;
    if (maxBodySize != null && maxBodySize < 0) {
      throw ArgumentError.value(
        maxBodySize,
        'maxBodySize',
        'Must be 0 or more (null for no limit)',
      );
    }
    if (shutdownTimeout.isNegative) {
      throw ArgumentError.value(
        shutdownTimeout,
        'shutdownTimeout',
        'Must be 0 or more',
      );
    }
    if (host.trim().isEmpty) {
      throw ArgumentError.value(host, 'host', 'Must not be empty');
    }
    final Duration? idleTimeout = this.idleTimeout;
    if (idleTimeout != null && idleTimeout.isNegative) {
      throw ArgumentError.value(
        idleTimeout,
        'idleTimeout',
        'Must be 0 or more (null keeps the connections open)',
      );
    }
    final Duration? requestTimeout = this.requestTimeout;
    if (requestTimeout != null && requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be more than 0 (null for no limit)',
      );
    }
  }
}
