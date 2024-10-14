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
  final BasicRouter _router;
  final FilterConfig _filterConfig;
  final List<String> packageScan; //TODO: as a lib, always scan itself

  static const RouteProcessor _routeProcessor = RouteProcessor();
  static const FilterProcessor _filterProcessor = FilterProcessor();

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
      BasicRouter(),
      context ?? BuildContext(),
      filterConfig ?? FilterConfig([]),
      //cant be const bc 'Unsupported operation: Cannot add to an unmodifiable list'
      packageScan: packageScan ?? [],
    );

    scanner.scan();

    return scanner;
  }

  WinterRouter get router => _router;

  BuildContext get context => _context;

  FilterConfig get filterConfig => _filterConfig;

  void scan() {
    //scan and get all components
    List<PreprocessedComponent> components = _getComponents();
    _sortComponents(components);

    for (var singleComponent in components) {
      if (singleComponent.declaration is MethodMirror) {
        MethodMirror methodMirror = singleComponent.declaration as MethodMirror;

        ///------ process possible route ------\\\
        Route? route = _routeProcessor.processRouteFromMethod(
          singleComponent.libMirror,
          methodMirror,
          _context.objectMapper,
        );
        if (route != null) {
          _router.addRoute(route);
        }

        ///------ process possible FilterAsFunction ------\\\
        Filter? filter = _filterProcessor.processFilterFromMethod(
          singleComponent.libMirror,
          methodMirror,
        );
        if (filter != null) {
          _filterConfig.add(filter);
        }
      } else if (singleComponent.declaration is ClassMirror) {
        ClassMirror classMirror = singleComponent.declaration as ClassMirror;

        ///------ process possible FilterAsFunction ------\\\
        Filter? filter = _filterProcessor.processFilterFromClass(
          singleComponent.libMirror,
          classMirror,
        );
        if (filter != null) {
          _filterConfig.add(filter);
        }
      }
    }
  }

  ///Get all the raw component of the system
  List<PreprocessedComponent> _getComponents() {
    List<PreprocessedComponent> components = [];
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
          components
              .add(PreprocessedComponent(component, libMirror, declaration));
        }
      }
    }
    return components;
  }

  void _sortComponents(List<PreprocessedComponent> components) {
    //sort components by priority
    components.sort(
      (a, b) => a.scanComponent.order.compareTo(b.scanComponent.order),
    );
  }
}

class PreprocessedComponent {
  final ScanComponent scanComponent;
  final LibraryMirror libMirror;
  final DeclarationMirror declaration;

  PreprocessedComponent(this.scanComponent, this.libMirror, this.declaration);
}
