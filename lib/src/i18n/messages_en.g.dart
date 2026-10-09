///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

part of 'messages.g.dart';

// Path: <root>
typedef WinterMessagesEn = WinterMessages; // ignore: unused_element

class WinterMessages
    with BaseTranslations<WinterMessagesLocale, WinterMessages> {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [WinterMessagesLocale.build] is preferred.
  WinterMessages({
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
             locale: WinterMessagesLocale.en,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ) {
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <en>.
  @override
  final TranslationMetadata<WinterMessagesLocale, WinterMessages> $meta;

  /// Access flat map
  dynamic operator [](String key) => $meta.getTranslation(key);

  late final WinterMessages _root = this; // ignore: unused_field

  WinterMessages $copyWith({
    TranslationMetadata<WinterMessagesLocale, WinterMessages>? meta,
  }) => WinterMessages(meta: meta ?? this.$meta);

  // Translations
  late final WinterMessages$errors$en errors = WinterMessages$errors$en._(
    _root,
  );
}

// Path: errors
class WinterMessages$errors$en {
  WinterMessages$errors$en._(this._root);

  final WinterMessages _root; // ignore: unused_field

  // Translations
  late final WinterMessages$errors$validations$en validations =
      WinterMessages$errors$validations$en._(_root);
}

// Path: errors.validations
class WinterMessages$errors$validations$en {
  WinterMessages$errors$validations$en._(this._root);

  final WinterMessages _root; // ignore: unused_field

  // Translations

  /// en: 'The field cannot be null'
  String get notNull => 'The field cannot be null';

  /// en: 'The field cannot be blank'
  String get notBlank => 'The field cannot be blank';

  late final WinterMessages$errors$validations$size$en size =
      WinterMessages$errors$validations$size$en._(_root);
  late final WinterMessages$errors$validations$min$en min =
      WinterMessages$errors$validations$min$en._(_root);
  late final WinterMessages$errors$validations$max$en max =
      WinterMessages$errors$validations$max$en._(_root);

  /// en: 'The value is not a valid email'
  String get email => 'The value is not a valid email';

  /// en: 'The value has an invalid format'
  String get pattern => 'The value has an invalid format';

  /// en: 'The value must be one of: {values: String}'
  String isEnum({required String values}) =>
      'The value must be one of: ${values}';

  /// en: 'The field cannot be empty'
  String get notEmpty => 'The field cannot be empty';

  /// en: 'The value must be one of: {values: String}'
  String oneOf({required String values}) =>
      'The value must be one of: ${values}';

  /// en: 'The value is not a valid URL'
  String get url => 'The value is not a valid URL';

  /// en: 'The value is not a valid UUID'
  String get uuid => 'The value is not a valid UUID';

  /// en: 'The value must be greater than 0'
  String get positive => 'The value must be greater than 0';

  /// en: 'The value must be less than 0'
  String get negative => 'The value must be less than 0';

  /// en: 'The value must be 0 or greater'
  String get positiveOrZero => 'The value must be 0 or greater';

  /// en: 'The value must be 0 or less'
  String get negativeOrZero => 'The value must be 0 or less';

  /// en: 'The date must be in the past'
  String get past => 'The date must be in the past';

  /// en: 'The date must be in the future'
  String get future => 'The date must be in the future';

  /// en: 'The date cannot be in the future'
  String get pastOrPresent => 'The date cannot be in the future';

  /// en: 'The date cannot be in the past'
  String get futureOrPresent => 'The date cannot be in the past';
}

// Path: errors.validations.size
class WinterMessages$errors$validations$size$en {
  WinterMessages$errors$validations$size$en._(this._root);

  final WinterMessages _root; // ignore: unused_field

  // Translations

  /// en: 'The minimum is {value: int}'
  String min({required int value}) => 'The minimum is ${value}';

  /// en: 'The maximum is {value: int}'
  String max({required int value}) => 'The maximum is ${value}';
}

// Path: errors.validations.min
class WinterMessages$errors$validations$min$en {
  WinterMessages$errors$validations$min$en._(this._root);

  final WinterMessages _root; // ignore: unused_field

  // Translations

  /// en: 'The minimum is {value: num}'
  String inclusive({required num value}) => 'The minimum is ${value}';

  /// en: 'The value must be greater than {value: num}'
  String exclusive({required num value}) =>
      'The value must be greater than ${value}';
}

// Path: errors.validations.max
class WinterMessages$errors$validations$max$en {
  WinterMessages$errors$validations$max$en._(this._root);

  final WinterMessages _root; // ignore: unused_field

  // Translations

  /// en: 'The maximum is {value: num}'
  String inclusive({required num value}) => 'The maximum is ${value}';

  /// en: 'The value must be less than {value: num}'
  String exclusive({required num value}) =>
      'The value must be less than ${value}';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on WinterMessages {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'errors.validations.notNull' => 'The field cannot be null',
      'errors.validations.notBlank' => 'The field cannot be blank',
      'errors.validations.size.min' => ({
        required int value,
      }) => 'The minimum is ${value}',
      'errors.validations.size.max' => ({
        required int value,
      }) => 'The maximum is ${value}',
      'errors.validations.min.inclusive' => ({
        required num value,
      }) => 'The minimum is ${value}',
      'errors.validations.min.exclusive' => ({
        required num value,
      }) => 'The value must be greater than ${value}',
      'errors.validations.max.inclusive' => ({
        required num value,
      }) => 'The maximum is ${value}',
      'errors.validations.max.exclusive' => ({
        required num value,
      }) => 'The value must be less than ${value}',
      'errors.validations.email' => 'The value is not a valid email',
      'errors.validations.pattern' => 'The value has an invalid format',
      'errors.validations.isEnum' => ({
        required String values,
      }) => 'The value must be one of: ${values}',
      'errors.validations.notEmpty' => 'The field cannot be empty',
      'errors.validations.oneOf' => ({
        required String values,
      }) => 'The value must be one of: ${values}',
      'errors.validations.url' => 'The value is not a valid URL',
      'errors.validations.uuid' => 'The value is not a valid UUID',
      'errors.validations.positive' => 'The value must be greater than 0',
      'errors.validations.negative' => 'The value must be less than 0',
      'errors.validations.positiveOrZero' => 'The value must be 0 or greater',
      'errors.validations.negativeOrZero' => 'The value must be 0 or less',
      'errors.validations.past' => 'The date must be in the past',
      'errors.validations.future' => 'The date must be in the future',
      'errors.validations.pastOrPresent' => 'The date cannot be in the future',
      'errors.validations.futureOrPresent' => 'The date cannot be in the past',
      _ => null,
    };
  }
}
