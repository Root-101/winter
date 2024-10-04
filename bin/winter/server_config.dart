import 'dart:io';

const int defaultServerPort = 8080;

class ServerConfig {
  ///Address on which the service will be running
  ///Default to InternetAddress.anyIPv4
  late final InternetAddress ip;

  ///Port on which the service will be running
  ///Default to `defaultServerPort` (8080)
  late final int port;

  ServerConfig({
    InternetAddress? ip,
    int? port,
  }) {
    this.ip = ip ?? InternetAddress.anyIPv4;
    this.port = port ?? defaultServerPort;
  }
}
