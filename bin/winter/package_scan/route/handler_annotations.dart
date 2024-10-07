import '../../winter.dart';

class Body<T> {
  final Object Function(String body, ObjectMapper om) parser;

  const Body._(this.parser);

  const Body() : parser = plainBodyParser<T>;

  const Body.list() : parser = bodyListParser<T>;

  const Body.map() : parser = bodyMapParser<T>;
}

class PlainBodyWrapper<T> {
  final T body;

  PlainBodyWrapper(this.body);
}

PlainBodyWrapper<T> plainBodyParser<T>(String body, ObjectMapper om) =>
    PlainBodyWrapper(om.deserialize(body, T));

List<T> bodyListParser<T>(String body, ObjectMapper om) =>
    om.deserialize(body, List<T>).cast<T>();

Map<String, T> bodyMapParser<T>(String body, ObjectMapper om) =>
    om.deserialize(body, Map<String, T>).cast<String, T>();

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
