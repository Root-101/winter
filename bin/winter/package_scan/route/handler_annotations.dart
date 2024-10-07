import '../../winter.dart';

typedef BodyParser<T> = T Function(String body, ObjectMapper om);

abstract class AbstractBody<T> {
  final BodyParser<T> parser;

  const AbstractBody(this.parser);
}

T plainBodyParser<T>(String body, ObjectMapper om) => om.deserialize(body, T);

class Body<T> extends AbstractBody<T> {
  const Body() : super(plainBodyParser<T>);
}

List<T> bodyListParser<T>(String body, ObjectMapper om) =>
    om.deserialize(body, List<T>).cast<T>();

class BodyList<T> extends AbstractBody {
  const BodyList() : super(bodyListParser<T>);
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
