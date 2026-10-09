///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

import 'messages.g.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';

// Path: <root>
class AppMessagesEs
    with BaseTranslations<AppLocale, AppMessages>
    implements AppMessages {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  AppMessagesEs({
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
             locale: AppLocale.es,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ) {
    _meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <es>.
  final TranslationMetadata<AppLocale, AppMessages> _meta;
  @override
  TranslationMetadata<AppLocale, AppMessages> get $meta => _meta;

  /// Access flat map
  @override
  dynamic operator [](String key) => _meta.getTranslation(key);

  late final AppMessagesEs _root = this; // ignore: unused_field

  @override
  AppMessagesEs $copyWith({
    TranslationMetadata<AppLocale, AppMessages>? meta,
  }) => AppMessagesEs(meta: meta ?? this.$meta);

  // Translations
  @override
  late final AppMessages$greetings$es greetings = AppMessages$greetings$es._(
    _root,
  );
  @override
  late final AppMessages$orders$es orders = AppMessages$orders$es._(_root);
}

// Path: greetings
class AppMessages$greetings$es implements AppMessages$greetings$en {
  AppMessages$greetings$es._(this._root);

  final AppMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  String hello({required Object name}) => 'Hola, ${name}';
}

// Path: orders
class AppMessages$orders$es implements AppMessages$orders$en {
  AppMessages$orders$es._(this._root);

  final AppMessagesEs _root; // ignore: unused_field

  // Translations
  @override
  String created({required Object id}) => 'Pedido ${id} creado';
  @override
  String notFound({required Object id}) => 'Pedido ${id} no encontrado';
  @override
  String get productRequired => 'Elige un producto';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on AppMessagesEs {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
      'greetings.hello' => ({required Object name}) => 'Hola, ${name}',
      'orders.created' => ({required Object id}) => 'Pedido ${id} creado',
      'orders.notFound' =>
        ({required Object id}) => 'Pedido ${id} no encontrado',
      'orders.productRequired' => 'Elige un producto',
      _ => null,
    };
  }
}
