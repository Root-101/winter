class HttpMethod {
  static const HttpMethod get = HttpMethod('get');
  static const HttpMethod query = HttpMethod('query');
  static const HttpMethod post = HttpMethod('post');
  static const HttpMethod put = HttpMethod('put');
  static const HttpMethod patch = HttpMethod('patch');
  static const HttpMethod delete = HttpMethod('delete');
  static const HttpMethod head = HttpMethod('head');
  static const HttpMethod options = HttpMethod('options');
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

  final String name;

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
