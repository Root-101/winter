class HttpMethod {
  static HttpMethod get = HttpMethod('get');
  static HttpMethod query = HttpMethod('query');
  static HttpMethod post = HttpMethod('post');
  static HttpMethod put = HttpMethod('put');
  static HttpMethod patch = HttpMethod('patch');
  static HttpMethod delete = HttpMethod('delete');
  static HttpMethod head = HttpMethod('head');
  static HttpMethod options = HttpMethod('options');
  static List<HttpMethod> values = [
    get,
    query,
    post,
    put,
    patch,
    delete,
    head,
    options,
  ];

  String name;

  HttpMethod(this.name);

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
