void main() {
  final asd = [1, 2, 3];
  List<int> list = deserialize(asd);
  print(list);
}

S deserialize<S>(dynamic data) {
  Type s = S;

  if (s == List) {
    print('list');
  }

  print(S.toString());

  return data as S;
}

extension Testtt<T> on List<T> {
  Type get testType => T;
}
