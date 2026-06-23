import 'package:winter/winter.dart';

class Tool {
  String? name;

  Tool({required this.name});

  Tool.empty();

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(name: json['NAME'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'NAME': name};
  }

  @override
  String toString() {
    return 'Tool{name: $name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tool && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class Worker {
  String name;

  Worker({required this.name});

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(name: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'name': name};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Worker && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class Gadget implements Serializable {
  final String id;

  Gadget({required this.id});

  @override
  Map<String, dynamic> toJson() => {'id': id};

  factory Gadget.fromJson(Map<String, dynamic> json) => Gadget(id: json['id']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gadget && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Workshop implements Serializable {
  final String name;
  final List<Gadget> gadgets;

  Workshop({required this.name, required this.gadgets});

  @override
  Map<String, dynamic> toJson() => {'name': name, 'gadgets': gadgets};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workshop &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          _listEquals(gadgets, other.gadgets);

  @override
  int get hashCode => name.hashCode ^ gadgets.hashCode;

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
