import 'package:analyzer/dart/element/element.dart';
import 'package:auto_route/auto_route_annotations.dart';
import 'package:auto_route_generator/import_resolver.dart';
import 'package:auto_route_generator/route_config_resolver.dart';
import 'package:auto_route_generator/router_class_generator.dart';
import 'package:auto_route_generator/utils.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class AutoRouteGenerator extends GeneratorForAnnotation<AutoRouter> {
  @override
  dynamic generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    // throw if annotation is used for a none class element
    throwIf(
      element is! ClassElement,
      '${element.name} is not a class element',
      element: element,
    );

    var libs = await buildStep.resolver.libraries.toList();

    var targetFileUri;
    if (annotation.peek('preferRelativeImports')?.boolValue != false) {
      targetFileUri = element.source.uri;
    }
    var importResolver = ImportResolver(libs, targetFileUri);

    var routerResolver = RouterConfigResolver(importResolver);
    final routerConfig = await routerResolver.resolve(annotation, element);

    return RouterClassGenerator(routerConfig).generate();
  }
}
