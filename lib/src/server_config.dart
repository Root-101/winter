import 'dart:async';
import 'dart:io';

const int defaultServerPort = 8080;

///10 MB
const int defaultMaxBodySize = 10 * 1024 * 1024;

class ServerConfig {
  ///Address on which the service will be running
  ///Default to InternetAddress.anyIPv4
  late final InternetAddress ip;

  ///Port on which the service will be running
  ///Default to `defaultServerPort` (8080)
  late final int port;

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

  ///Called on a graceful shutdown after the server is closed,
  ///to release other resources (database connections, files...)
  final FutureOr<void> Function()? onShutdown;

  ServerConfig({
    InternetAddress? ip,
    int? port,
    this.maxBodySize = defaultMaxBodySize,
    this.handleSignals = true,
    this.shutdownTimeout = const Duration(seconds: 10),
    this.onShutdown,
  }) {
    this.ip = ip ?? InternetAddress.anyIPv4;
    this.port = port ?? defaultServerPort;
  }
}
