///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

import 'messages.g.dart';

import 'package:intl/intl.dart';
import 'package:slang/generated.dart';

// Path: <root>
class WinterMessagesEs
    with BaseTranslations<WinterMessagesLocale, WinterMessages>
    implements WinterMessages {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [WinterMessagesLocale.build] is preferred.
  WinterMessagesEs({
    Map<String, Node>? overrides,
    PluralResolver? cardinalResolver,
    PluralResolver? ordinalResolver,
    TranslationMetadata<WinterMessagesLocale, WinterMessages>? meta,
  }) : assert(
         overrides == null,
         'Set "translation_overrides: true" in order to enable this feature.',
       ),
       $meta =
           meta ??
           TranslationMetadata(
             locale: WinterMessagesLocale.es,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ) {
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <es>.
  @override
  final TranslationMetadata<WinterMessagesLocale, WinterMessages> $meta;

  /// Access flat map
  @override
  dynamic operator [](String key) => $meta.getTranslation(key);

  late final WinterMessagesEs _root = this; // ignore: unused_field

  @override
  WinterMessagesEs $copyWith({
    TranslationMetadata<WinterMessagesLocale, WinterMessages>? meta,
  }) => WinterMessagesEs(meta: meta ?? this.$meta);

  // Translations
  @override
  late final WinterMessages$errors$es errors = WinterMessages$errors$es._(
    _root,
  );
}

// Path: errors
class WinterMessages$errors$es implements WinterMessages$errors$en {
  WinterMessages$errors$es._(this._root);

  final WinterMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  late final WinterMessages$errors$validations$es validations =
      WinterMessages$errors$validations$es._(_root);
}

// Path: errors.validations
class WinterMessages$errors$validations$es
    implements WinterMessages$errors$validations$en {
  WinterMessages$errors$validations$es._(this._root);

  final WinterMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  late final WinterMessages$errors$validations$type$es type =
      WinterMessages$errors$validations$type$es._(_root);
  @override
  String get notNull => 'El campo no puede ser null';
  @override
  String get notBlank => 'El campo no puede estar vacío';
  @override
  late final WinterMessages$errors$validations$size$es size =
      WinterMessages$errors$validations$size$es._(_root);
  @override
  late final WinterMessages$errors$validations$min$es min =
      WinterMessages$errors$validations$min$es._(_root);
  @override
  late final WinterMessages$errors$validations$max$es max =
      WinterMessages$errors$validations$max$es._(_root);
  @override
  String get email => 'El valor no es un email válido';
  @override
  String get pattern => 'El valor tiene un formato no válido';
  @override
  String isEnum({required Object values}) =>
      'El valor debe ser uno de: ${values}';
}

// Path: errors.validations.type
class WinterMessages$errors$validations$type$es
    implements WinterMessages$errors$validations$type$en {
  WinterMessages$errors$validations$type$es._(this._root);

  final WinterMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  String get string => 'El valor debe ser un String';
  @override
  String get number => 'El valor debe ser un número';
}

// Path: errors.validations.size
class WinterMessages$errors$validations$size$es
    implements WinterMessages$errors$validations$size$en {
  WinterMessages$errors$validations$size$es._(this._root);

  final WinterMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  String min({required Object value}) => 'El mínimo es ${value}';
  @override
  String max({required Object value}) => 'El máximo es ${value}';
  @override
  String get invalidType => 'El valor debe ser un String o un Iterable';
}

// Path: errors.validations.min
class WinterMessages$errors$validations$min$es
    implements WinterMessages$errors$validations$min$en {
  WinterMessages$errors$validations$min$es._(this._root);

  final WinterMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  String inclusive({required Object value}) => 'El mínimo es ${value}';
  @override
  String exclusive({required Object value}) =>
      'El valor debe ser mayor que ${value}';
}

// Path: errors.validations.max
class WinterMessages$errors$validations$max$es
    implements WinterMessages$errors$validations$max$en {
  WinterMessages$errors$validations$max$es._(this._root);

  final WinterMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  String inclusive({required Object value}) => 'El máximo es ${value}';
  @override
  String exclusive({required Object value}) =>
      'El valor debe ser menor que ${value}';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on WinterMessagesEs {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'errors.validations.type.string' => 'El valor debe ser un String',
      'errors.validations.type.number' => 'El valor debe ser un número',
      'errors.validations.notNull' => 'El campo no puede ser null',
      'errors.validations.notBlank' => 'El campo no puede estar vacío',
      'errors.validations.size.min' => ({
        required Object value,
      }) => 'El mínimo es ${value}',
      'errors.validations.size.max' => ({
        required Object value,
      }) => 'El máximo es ${value}',
      'errors.validations.size.invalidType' =>
        'El valor debe ser un String o un Iterable',
      'errors.validations.min.inclusive' => ({
        required Object value,
      }) => 'El mínimo es ${value}',
      'errors.validations.min.exclusive' => ({
        required Object value,
      }) => 'El valor debe ser mayor que ${value}',
      'errors.validations.max.inclusive' => ({
        required Object value,
      }) => 'El máximo es ${value}',
      'errors.validations.max.exclusive' => ({
        required Object value,
      }) => 'El valor debe ser menor que ${value}',
      'errors.validations.email' => 'El valor no es un email válido',
      'errors.validations.pattern' => 'El valor tiene un formato no válido',
      'errors.validations.isEnum' => ({
        required Object values,
      }) => 'El valor debe ser uno de: ${values}',
      _ => null,
    };
  }
}
