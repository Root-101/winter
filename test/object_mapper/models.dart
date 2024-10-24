import 'package:winter/winter.dart';

//----------------------
class Tool implements WinterSerializer, WinterDeserializable {
  String? name;

  Tool({required this.name});

  Tool.empty();

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      name: json['NAME'] as String,
    );
  }

  @override
  Map toJson() {
    return {
      'NAME': name,
    };
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

//----------------------
String _propertyToString(dynamic property) =>
    (property as String).toUpperCase();

String _propertyFromJson(dynamic property) =>
    (property as String).toLowerCase();

//Tiene que tener el Computer();
class Computer {
  @ToJsonParser(_propertyToString)
  @FromJsonParser(_propertyFromJson)
  String? brand;

  Computer();

  Computer.named({required this.brand});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Computer &&
          runtimeType == other.runtimeType &&
          brand == other.brand;

  @override
  int get hashCode => brand.hashCode;
}

//----------------------
class Mouse {
  @JsonProperty('mouse_brand')
  String? brand;

  Mouse();

  Mouse.named({required this.brand});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Mouse &&
          runtimeType == other.runtimeType &&
          brand == other.brand;

  @override
  int get hashCode => brand.hashCode;
}

//----------------------
class Address {
  String? streetName;
  int? houseNumber;

  Address();

  Address.named({
    this.streetName,
    this.houseNumber,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address &&
          runtimeType == other.runtimeType &&
          streetName == other.streetName &&
          houseNumber == other.houseNumber;

  @override
  int get hashCode => streetName.hashCode ^ houseNumber.hashCode;

  @override
  String toString() {
    return 'Address{streetName: $streetName, houseNumber: $houseNumber}';
  }
}

class User {
  String? userName;

  int? userId;

  Duration? duration;

  bool? isActive;

  @CastList<Address>()
  List<Address>? addresses;

  Address? singleAddress;

  @CastMap<String, dynamic>()
  Map<String, dynamic>? additionalAttributes;

  User();

  User.named({
    required this.userName,
    required this.userId,
    required this.duration,
    required this.isActive,
    required this.addresses,
    required this.singleAddress,
    required this.additionalAttributes,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    final User otherUser = other as User;
    return userName == otherUser.userName &&
        userId == otherUser.userId &&
        duration == otherUser.duration &&
        isActive == otherUser.isActive &&
        _listEquals(addresses, otherUser.addresses) &&
        singleAddress == otherUser.singleAddress &&
        _mapEquals(additionalAttributes, otherUser.additionalAttributes);
  }

  bool _listEquals(List? a, List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map? a, Map? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;

      final valueA = a[key];
      final valueB = b[key];

      // Comparar recursivamente si el valor es otro Map
      if (valueA is Map && valueB is Map) {
        if (!_mapEquals(valueA, valueB)) return false;
      } else if (valueA is List && valueB is List) {
        return _listEquals(valueA, valueB);
      } else if (valueA != valueB) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      userName.hashCode ^
      userId.hashCode ^
      duration.hashCode ^
      isActive.hashCode ^
      addresses.hashCode ^
      singleAddress.hashCode ^
      additionalAttributes.hashCode;

  @override
  String toString() {
    return 'User{userName: $userName, userId: $userId, duration: $duration, isActive: $isActive, addresses: $addresses, singleAddress: $singleAddress, additionalAttributes: $additionalAttributes}';
  }
}
