import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:trigger/src/annotations.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

String makeUnModify(String type, String content) {
  type = type.replaceAll(RegExp(r'<[^>]*>'), '');
  return 'Unmodifiable${type}View($content)';
}

class TriggerGenerator extends GeneratorForAnnotation<TriggerGen> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'TriggerGen can only be used on classes',
      );
    }

    final String rawName = element.name!;
    final annotationName = annotation.read('name').isNull
        ? null
        : annotation.read('name').stringValue;

    final effects = annotation
        .read("fx")
        .listValue
        .map((e) => e.toTypeValue()?.getDisplayString())
        .toList();

    final fxInit = StringBuffer();
    for (final fx in effects) {
      if (fx != null) fxInit.writeln('$fx(this);');
    }

    final String className =
        annotationName ??
        (rawName.endsWith('Anno')
            ? rawName.substring(0, rawName.length - 4)
            : rawName);

    final gettersSetters = StringBuffer();
    final constIndices = StringBuffer();
    final initVal = StringBuffer();
    final fBody = StringBuffer();
    final stBody = StringBuffer();
    final efBody = StringBuffer();
    final fieldNamesList = StringBuffer();

    int indexCounter = 0;
    for (var field in element.fields) {
      if (field.isStatic || field.isExternal) continue;

      final bool isNullable =
          field.type.nullabilitySuffix == NullabilitySuffix.question;
      final name = field.name!;
      final capName = name[0].toUpperCase() + name.substring(1);
      final idxConst = '_idx$capName';
      String defaultValue = isNullable ? 'null' : '';

      // ดึง Default Value จาก AST
      final library = field.library;
      final session = library.session;
      final parsedLib =
          session.getParsedLibraryByElement(library) as ParsedLibraryResult?;
      if (parsedLib == null) continue;
      for (var unit in parsedLib.units) {
        for (var declaration in unit.unit.declarations) {
          if (declaration is ClassDeclaration &&
              declaration.name.lexeme == rawName) {
            for (var member in declaration.members) {
              if (member is FieldDeclaration) {
                for (var variable in member.fields.variables) {
                  if (variable.name.lexeme == name &&
                      variable.initializer != null) {
                    defaultValue = variable.initializer.toString();
                  }
                }
              }
            }
          }
        }
      }

      final typeStr = field.type.getDisplayString();

      // 1. สร้าง Static Index
      constIndices.writeln('static const int $idxConst = $indexCounter;');
      fieldNamesList.write("'$name', ");

      // 2. สร้าง Getter/Setter O(1)
      var content = "getValue($idxConst) as $typeStr";
      if (['List', 'Map', 'Set'].any((t) => typeStr.startsWith(t))) {
        content = makeUnModify(typeStr, content);
      }
      gettersSetters.writeln("  $typeStr get $name => $content;");
      gettersSetters.writeln(
        "  set $name($typeStr val) => setValue($idxConst, val);",
      );

      // 3. Constructor Initialization
      initVal.writeln("    $name = $defaultValue;");

      // 4. Fields (Index-based)
      fBody.writeln('''
  ${className}Fields get $name {
    addField($className.$idxConst);
    return this;
  }''');

      // 5. MultiSetter (int keys)
      stBody.writeln(
        '  set $name($typeStr val) => _map[$className.$idxConst] = val;',
      );

      // 6. Effect (Index-based protection)
      efBody.writeln('''
  $typeStr get $name => trigger.$name;
  set $name($typeStr val) {
    checkAllow($className.$idxConst);
    trigger.$name = val;
  }''');

      indexCounter++;
    }

    return '''
typedef _${className}EffectCreator = void Function(${className} t);

final class $className extends Trigger {
  $constIndices
  static const int _fieldCount = $indexCounter;

  static $className? _instance;

  static final List<String> _fieldNamesList = [$fieldNamesList];

  static ${className}Fields get fields => ${className}Fields();

  bool _fxAttached = false;

  $className._internal({bool register = true, UpdateScheduler? scheduler})
      : super(
          fieldCount: _fieldCount,
          fieldNames: _fieldNamesList,
          register: register,
          scheduler: scheduler,
        ) {
    if (register) {
$fxInit
      _fxAttached = true;
    }
$initVal  }

  //this will be used to spawn a new $className instance that is not singleton.
  factory $className.spawn({UpdateScheduler? scheduler}) =>
      $className._internal(register: false, scheduler: scheduler);
  factory $className({UpdateScheduler? scheduler}) {
    _instance ??= $className._internal(scheduler: scheduler);
    return _instance!;
  }

  //Getter/Setter with performance of O(1)
$gettersSetters

  // ignore: library_private_types_in_public_api
  void multiSet(void Function(_${className}MultiSetter setter) func) {
    final setter = _${className}MultiSetter();
    func(setter);
    setMultiValues(setter._map);
  }

  /// Attaches all master effects declared in @TriggerGen(fx: [...])
  ///
  /// - Must be called before any listeners are added
  /// - Can be called only once per instance
  /// - If no effects are declared → acts as no-op and locks further calls
  void attachMasterFx() {
    if (_fxAttached) {
      throw StateError(
        "Multiple attachment attempts are not allowed. This process is restricted to a single occurrence.",
      );
    }
    if (hasListeners()) {
      throw StateError(
        "Cannot attach master effects after listeners have been registered. "
        "Attach effects before any listening occurs.",
      );
    }
$fxInit
    _fxAttached = true;
  }

  // ignore: library_private_types_in_public_api
  void attachFx(List<_${className}EffectCreator> fxs) {
    if (_fxAttached) {
      throw StateError(
        "Multiple attachment attempts are not allowed. This process is restricted to a single occurrence.",
      );
    }
    if (hasListeners()) {
      throw StateError(
        "Cannot attach master effects after listeners have been registered. "
        "Attach effects before any listening occurs.",
      );
    }
    for (var fx in fxs) {
      fx(this);
    }
    _fxAttached = true;
  }
}

final class ${className}Fields extends TriggerFields<$className> {
$fBody
}

class _${className}MultiSetter {
  final _map = <int, dynamic>{};
$stBody
}

abstract base class ${className}Effect extends TriggerEffect<$className> {
  ${className}Effect(super.trigger);
$efBody

  // ignore: library_private_types_in_public_api
  void multiSet(Function(_${className}MultiSetter setter) func) {
    final setter = _${className}MultiSetter();
    func(setter);
    for (final key in setter._map.keys) {
      checkAllow(key);
    }
    // ignore: invalid_use_of_protected_member
    trigger.setMultiValues(setter._map);
  }
}
''';
  }
}
