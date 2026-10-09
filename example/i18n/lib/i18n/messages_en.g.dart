///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

part of 'messages.g.dart';

// Path: <root>
typedef AppMessagesEn = AppMessages; // ignore: unused_element

class AppMessages with BaseTranslations<AppLocale, AppMessages> {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  AppMessages({
    Map<String, Node>? overrides,
    PluralResolver? cardinalResolver,
    PluralResolver? ordinalResolver,
    TranslationMetadata<AppLocale, AppMessages>? meta,
  }) : assert(
         overrides == null,
         'Set "translation_overrides: true" in order to enable this feature.',
       ),
       _meta =
           meta ??
           TranslationMetadata(
             locale: AppLocale.en,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ) {
    _meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <en>.
  final TranslationMetadata<AppLocale, AppMessages> _meta;
  @override
  TranslationMetadata<AppLocale, AppMessages> get $meta => _meta;

  /// Access flat map
  dynamic operator [](String key) => _meta.getTranslation(key);

  late final AppMessages _root = this; // ignore: unused_field

  AppMessages $copyWith({TranslationMetadata<AppLocale, AppMessages>? meta}) =>
      AppMessages(meta: meta ?? this.$meta);

  // Translations
  late final AppMessages$greetings$en greetings = AppMessages$greetings$en._(
    _root,
  );
  late final AppMessages$orders$en orders = AppMessages$orders$en._(_root);
}

// Path: greetings
class AppMessages$greetings$en {
  AppMessages$greetings$en._(this._root);

  final AppMessages _root; // ignore: unused_field

  // Translations

  /// en: 'Hello, {name}'
  String hello({required Object name}) => 'Hello, ${name}';
}

// Path: orders
class AppMessages$orders$en {
  AppMessages$orders$en._(this._root);

  final AppMessages _root; // ignore: unused_field

  // Translations

  /// en: 'Order {id: int} created'
  String created({required int id}) => 'Order ${id} created';

  /// en: 'Order {id: int} not found'
  String notFound({required int id}) => 'Order ${id} not found';

  /// en: 'Choose a product'
  String get productRequired => 'Choose a product';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on AppMessages {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'greetings.hello' => ({required Object name}) => 'Hello, ${name}',
      'orders.created' => ({required int id}) => 'Order ${id} created',
      'orders.notFound' => ({required int id}) => 'Order ${id} not found',
      'orders.productRequired' => 'Choose a product',
      _ => null,
    };
  }
}
