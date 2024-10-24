import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../winter.dart';
import 'filter_chain/filter_processor.dart';
import 'route/route_processor.dart';

///Function used to extract a param, like the body or an header from a request
typedef ParamExtractor = dynamic Function(RequestEntity request);

///Base annotation for top level annotations, if ANYTHING is not annotated with this, it's not processed
///All top level annotations SHOULD extends this if they wanna be processed
class ScanComponent {
  final int order;

  const ScanComponent({
    this.order = 1,
  });
}

class PackageScanner {
  final BuildContext _context;
  final WinterRouter _router;
  final FilterConfig _filterConfig;
  final List<String> packageScan; //TODO: as a lib, always scan itself

  final List<ProcessedComponent> summary = [];

  static const RouteProcessor _routeProcessor = RouteProcessor();
  static const FilterProcessor _filterProcessor = FilterProcessor();
  static const InjectableProcessor _injectableProcessor = InjectableProcessor();

  PackageScanner._(
    this._router,
    this._context,
    this._filterConfig, {
    required this.packageScan,
  });

  factory PackageScanner({
    BuildContext? context,
    List<String>? packageScan,
    FilterConfig? filterConfig,
  }) {
    PackageScanner scanner = PackageScanner._(
      WinterRouter(),
      context ?? BuildContext(),
      filterConfig ?? FilterConfig([]),
      //cant be const bc 'Unsupported operation: Cannot add to an unmodifiable list'
      packageScan: packageScan ?? [],
    );

    scanner._scan();

    return scanner;
  }

  WinterRouter get router => _router;

  BuildContext get context => _context;

  FilterConfig get filterConfig => _filterConfig;

  void _addProcessedComponent({
    required ComponentType type,
    required RawComponent component,
    required ProcessedAs processedAs,
  }) {
    summary.add(
      ProcessedComponent(
        type: type,
        name: MirrorSystem.getName(component.declaration.simpleName),
        library: MirrorSystem.getName(component.libMirror.simpleName),
        processedAs: processedAs,
      ),
    );
  }

  //TODO: ver si con el .owner se puede acceder al library mirror sin tener que pasarlo por parametros
  void _scan() {
    //scan and get all components
    List<RawComponent> components = _getComponents();
    _sortComponents(components);

    for (var rawComponent in components) {
      if (rawComponent.declaration is MethodMirror) {
        MethodMirror methodMirror = rawComponent.declaration as MethodMirror;

        ///------ process possible route ------\\\
        Route? route = _routeProcessor.processRouteFromMethod(
          rawComponent.libMirror,
          methodMirror,
          _context.objectMapper,
        );
        if (route != null) {
          _router.addRoute(route);

          _addProcessedComponent(
            type: ComponentType.method,
            component: rawComponent,
            processedAs: ProcessedAs.route,
          );

          continue;
        }

        ///------ process possible FilterAsFunction ------\\\
        Filter? filter = _filterProcessor.processFilterFromMethod(
          rawComponent.libMirror,
          methodMirror,
        );
        if (filter != null) {
          _filterConfig.add(filter);

          _addProcessedComponent(
            type: ComponentType.method,
            component: rawComponent,
            processedAs: ProcessedAs.filter,
          );

          continue;
        }

        ///------ process possible injectable (as method)------\\\
        ({Object? dependency, String? tag}) injectableObject =
            _injectableProcessor.processInjectableFromMethod(
          methodMirror,
          _context.dependencyInjection,
        );

        if (injectableObject.dependency != null) {
          _context.dependencyInjection.put(
            injectableObject.dependency,
            tag: injectableObject.tag,
          );

          _addProcessedComponent(
            type: ComponentType.method,
            component: rawComponent,
            processedAs: ProcessedAs.injectable,
          );

          continue;
        }
      } else if (rawComponent.declaration is ClassMirror) {
        ClassMirror classMirror = rawComponent.declaration as ClassMirror;

        ///------ process possible Filter (as class) ------\\\
        Filter? filter = _filterProcessor.processFilterFromClass(
          rawComponent.libMirror,
          classMirror,
        );
        if (filter != null) {
          _filterConfig.add(filter);

          _addProcessedComponent(
            type: ComponentType.clazz,
            component: rawComponent,
            processedAs: ProcessedAs.filter,
          );

          continue;
        }
      } else if (rawComponent.declaration is VariableMirror) {
        VariableMirror variableMirror =
            rawComponent.declaration as VariableMirror;

        ///------ process possible injectable (as variable)------\\\
        ({Object? dependency, String? tag}) injectableObject =
            _injectableProcessor.processInjectableFromVariable(
          variableMirror,
        );

        if (injectableObject.dependency != null) {
          _context.dependencyInjection.put(
            injectableObject.dependency,
            tag: injectableObject.tag,
          );

          _addProcessedComponent(
            type: ComponentType.variable,
            component: rawComponent,
            processedAs: ProcessedAs.injectable,
          );

          continue;
        }
      }
    }
  }

  ///Get all the raw component of the system
  List<RawComponent> _getComponents() {
    List<RawComponent> components = [];
    // Iterar sobre todas las librerías cargadas
    for (var library in currentMirrorSystem().libraries.entries) {
      final uri = library.key;
      final libMirror = library.value;

      String uriPath = uri.toString();

      ///Dont scan if:
      ///1 - Is a dart package
      ///2 - Is an external package and it's not specified to scan it in `packageScan`'s list
      if (uriPath.startsWith('dart:') ||
          (uriPath.startsWith('package:') && !packageScan.contains(uriPath))) {
        continue;
      }

      for (var entry in libMirror.declarations.entries) {
        //print('key: ${entry.key}, value: ${entry.value}');

        final declaration = entry.value;

        ScanComponent? component = declaration.metadata
            .firstWhereOrNull(
              (metadata) => metadata.reflectee is ScanComponent,
            )
            ?.reflectee;

        if (component != null) {
          components.add(RawComponent(component, libMirror, declaration));
        }
      }
    }
    return components;
  }

  void _sortComponents(List<RawComponent> components) {
    //sort components by priority
    components.sort(
      (a, b) => a.scanComponent.order.compareTo(b.scanComponent.order),
    );
  }
}

class RawComponent {
  final ScanComponent scanComponent;
  final LibraryMirror libMirror;
  final DeclarationMirror declaration;

  RawComponent(this.scanComponent, this.libMirror, this.declaration);
}

enum ComponentType {
  clazz,
  method,
  variable,
  unknown;
}

enum ProcessedAs {
  route,
  filter,
  injectable,
  notProcessed;
}

class ProcessedComponent {
  final ComponentType type;
  final String name;
  final String library;
  final ProcessedAs processedAs;

  ProcessedComponent({
    required this.type,
    required this.name,
    required this.library,
    required this.processedAs,
  });

  @override
  String toString() {
    return 'ProcessedComponent{type: $type, name: $name, library: $library, processedAs: $processedAs}';
  }
}
