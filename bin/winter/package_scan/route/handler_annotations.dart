class Body {
  const Body();
}

class Header {
  final String? name;

  const Header({
    this.name,
  });
}

///NOTE: path-param dont support optional type
class PathParam {
  final String? name;

  const PathParam({
    this.name,
  });
}

class QueryParam {
  final String? name;

  const QueryParam({
    this.name,
  });
}
