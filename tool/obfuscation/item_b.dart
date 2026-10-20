/// An item of another library, with the same name as the one of `item_a.dart`
class Item {
  /// How many
  final int count;

  /// An item of [count]
  const Item(this.count);

  /// Read from its JSON
  factory Item.fromJson(Map<String, dynamic> json) =>
      Item(json['count'] as int);

  /// Its JSON
  Map<String, Object> toJson() => {'count': count};
}
