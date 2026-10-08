/// An HTTP method. The constants are the methods a `Route` can have; any other can be built
/// (`HttpMethod('PROPFIND')`).
///
/// Methods are compared without case, also with a `String`: `HttpMethod.get == 'GET'`.
///
/// {@category HTTP}
class HttpMethod {
  /// `GET`: read a resource (a `HEAD` without its own route uses the `GET` one)
  static const HttpMethod get = HttpMethod('get');

  /// `QUERY`: a safe read with a body (an IETF draft), for searches too big for a query string
  static const HttpMethod query = HttpMethod('query');

  /// `POST`: create a resource, or run an action
  static const HttpMethod post = HttpMethod('post');

  /// `PUT`: replace a resource
  static const HttpMethod put = HttpMethod('put');

  /// `PATCH`: change part of a resource
  static const HttpMethod patch = HttpMethod('patch');

  /// `DELETE`: remove a resource
  static const HttpMethod delete = HttpMethod('delete');

  /// `HEAD`: the headers of a `GET`, without the body
  static const HttpMethod head = HttpMethod('head');

  /// `OPTIONS`: the methods allowed for a path (a CORS preflight too)
  static const HttpMethod options = HttpMethod('options');

  /// Every constant, in this order
  static const List<HttpMethod> values = [
    get,
    query,
    post,
    put,
    patch,
    delete,
    head,
    options,
  ];

  /// The name of the method, as it was given (`get` for the constants)
  final String name;

  /// The method [name] (any case)
  const HttpMethod(this.name);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is HttpMethod) {
      return name.toLowerCase() == other.name.toLowerCase();
    }
    if (other is String) {
      return name.toLowerCase() == other.toLowerCase();
    }
    return false;
  }

  @override
  int get hashCode => name.toLowerCase().hashCode;

  @override
  String toString() {
    return name;
  }
}
