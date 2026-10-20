/// An item of one library, with the same name as the one of `item_b.dart`
class Item {
  /// Its name
  final String name;

  /// An item called [name]
  const Item(this.name);

  /// Read from its JSON
  factory Item.fromJson(Map<String, dynamic> json) =>
      Item(json['name'] as String);

  /// Its JSON
  Map<String, Object> toJson() => {'name': name};
}
