import 'package:winter/context/context.dart';

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
  Tool tool;

  Worker({required this.name, required this.tool});

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      name: json['name'] as String,
      tool: Tool.fromJson(json['tool'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'tool': tool.toJson()};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Worker &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          tool == other.tool;

  @override
  int get hashCode => name.hashCode ^ tool.hashCode;
}

class SerializableTool implements Serializable {
  String? name;

  SerializableTool({required this.name});

  SerializableTool.empty();

  factory SerializableTool.fromJson(Map<String, dynamic> json) {
    return SerializableTool(name: json['NAME'] as String);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'NAME': name};
  }

  @override
  String toString() {
    return 'SerializableTool{name: $name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tool && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
