class Test {
  String? name;

  Test();

  Test.named(this.name);

  @override
  String toString() {
    return 'Test{name: $name}';
  }
}
