import 'package:analyzer/dart/element/element.dart';
import 'package:auto_route/auto_route_annotations.dart';
import 'package:auto_route_generator/import_resolver.dart';
import 'package:auto_route_generator/route_config_resolver.dart';
import 'package:auto_route_generator/utils.dart';
import 'package:source_gen/source_gen.dart';

const TypeChecker autoRouteChecker = TypeChecker.fromRuntime(AutoRoute);

// extracts route configs from autoRoutes
class RouteConfigResolver {
  final RouterConfig _routerConfig;
  final ImportResolver _importResolver;

  RouteConfigResolver(this._routerConfig, this._importResolver);

  Future<RouteConfig> resolve(ConstantReader autoRoute) async {
    final routeConfig = RouteConfig();
    final type = autoRoute.read('page').typeValue;
    final classElement = type.element as ClassElement;

    final import = _importResolver.resolve(classElement);
    if (import != null) {
      routeConfig.imports.add(import);
    }
    routeConfig.className = type.getDisplayString();
    var path = autoRoute.peek('path')?.stringValue;
    if (path == null) {
      if (autoRoute.peek('initial')?.boolValue == true) {
        path = '/';
      } else {
        path = '${_routerConfig.routeNamePrefix}${toKababCase(routeConfig.className)}';
      }
    }
    routeConfig.pathName = path;

    throwIf(
      type.element is! ClassElement,
      '${type.getDisplayString()} is not a class element',
      element: type.element,
    );

    await _extractRouteMetaData(routeConfig, autoRoute);

    routeConfig.name = autoRoute.peek('name')?.stringValue ?? toLowerCamelCase(routeConfig.className);

    routeConfig.hasWrapper = classElement.allSupertypes.map<String>((el) => el.getDisplayString()).contains('AutoRouteWrapper');

    final constructor = classElement.unnamedConstructor;

    var params = constructor?.parameters;
    if (params?.isNotEmpty == true) {
      if (constructor.isConst && params.length == 1 && params.first.type.getDisplayString() == 'Key') {
        routeConfig.hasConstConstructor = true;
      } else {
        final paramResolver = RouteParameterResolver(_importResolver);
        routeConfig.parameters = [];
        for (ParameterElement p in constructor.parameters) {
          routeConfig.parameters.add(await paramResolver.resolve(p));
        }
      }
    }
    // _validatePathParams(routeConfig, classElement);
    return routeConfig;
  }

  Future<void> _extractRouteMetaData(RouteConfig routeConfig, ConstantReader autoRoute) async {
    routeConfig.fullscreenDialog = autoRoute.peek('fullscreenDialog')?.boolValue;
    routeConfig.maintainState = autoRoute.peek('maintainState')?.boolValue;

    autoRoute.peek('guards')?.listValue?.map((g) => g.toTypeValue())?.forEach((guard) {
      routeConfig.guards.add(RouteGuardConfig(type: guard.getDisplayString(), import: _importResolver.resolve(guard.element)));
    });

    final returnType = autoRoute.objectValue.type.typeArguments.first;
    routeConfig.returnType = returnType.getDisplayString();

    if (routeConfig.returnType != 'dynamic') {
      routeConfig.imports.addAll(_importResolver.resolveAll(returnType));
    }

    if (autoRoute.instanceOf(TypeChecker.fromRuntime(MaterialRouteType))) {
      routeConfig.routeType = MaterialRouteType();
    } else if (autoRoute.instanceOf(TypeChecker.fromRuntime(CupertinoRouteType))) {
      routeConfig.routeType = CupertinoRouteType();
      routeConfig.cupertinoNavTitle = autoRoute.peek('title')?.stringValue;
    } else if (autoRoute.instanceOf(TypeChecker.fromRuntime(AdaptiveRoute))) {
      routeConfig.routeType = AdaptiveRouteType();
      routeConfig.cupertinoNavTitle = autoRoute.peek('cupertinoPageTitle')?.stringValue;
    } else if (autoRoute.instanceOf(TypeChecker.fromRuntime(CustomRoute))) {
      routeConfig.routeType = CustomRouteType();
      routeConfig.durationInMilliseconds = autoRoute.peek('durationInMilliseconds')?.intValue;
      routeConfig.customRouteOpaque = autoRoute.peek('opaque')?.boolValue;
      routeConfig.customRouteBarrierDismissible = autoRoute.peek('barrierDismissible')?.boolValue;
      final function = autoRoute.peek('transitionsBuilder')?.objectValue?.toFunctionValue();
      if (function != null) {
        final displayName = function.displayName.replaceFirst(RegExp('^_'), '');
        final functionName = (function.isStatic && function.enclosingElement?.displayName != null)
            ? '${function.enclosingElement.displayName}.$displayName'
            : displayName;

        var import;
        if (function.enclosingElement?.name != 'TransitionsBuilders') {
          import = _importResolver.resolve(function);
        }
        routeConfig.transitionBuilder = CustomTransitionBuilder(functionName, import);
      }
    } else {
      var defaultRouteType = _routerConfig.defaultRouteType;
      routeConfig.routeType = defaultRouteType;
//      if (defaultRouteType is CustomRouteType) {
//        routeConfig.transitionBuilder = defaultRouteType.transitionBuilder;
//        routeConfig.durationInMilliseconds = defaultRouteType.durationInMilliseconds;
//        routeConfig.customRouteBarrierDismissible = defaultRouteType.customRouteBarrierDismissible;
//        routeConfig.customRouteOpaque = defaultRouteType.customRouteOpaque;
//      }
    }
  }
}
