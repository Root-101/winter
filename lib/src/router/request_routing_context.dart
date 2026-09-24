import 'package:winter/winter.dart';

class RequestRoutingContext {
  final String path;
  final String key;
  final HttpMethod method;

  RequestRoutingContext({
    required this.path,
    required this.key,
    required this.method,
  });
}
