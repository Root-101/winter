import 'http_status_code.dart';

///Default implementation of {@link HttpStatusCode}.
class DefaultHttpStatusCode with HttpStatusCode {
  @override
  final int value;

  DefaultHttpStatusCode(this.value);

  @override
  bool is1xxInformational() {
    return _hundreds() == 1;
  }

  @override
  bool is2xxSuccessful() {
    return _hundreds() == 2;
  }

  @override
  bool is3xxRedirection() {
    return _hundreds() == 3;
  }

  @override
  bool is4xxClientError() {
    return _hundreds() == 4;
  }

  @override
  bool is5xxServerError() {
    return _hundreds() == 5;
  }

  @override
  bool isError() {
    int hundreds = _hundreds();
    return hundreds == 4 || hundreds == 5;
  }

  int _hundreds() {
    return value ~/ 100;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultHttpStatusCode &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return value.toString();
  }
}
