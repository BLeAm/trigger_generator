import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
// import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:trigger/src/annotations.dart';

String makeUnModify(String type, String content) {
  // ใช้ RegExp r'<[^>]*>'
  // <      : เริ่มต้นด้วย <
  // [^>]* : ตามด้วยตัวอักษรอะไรก็ได้ที่ไม่ใช่ > จำนวนกี่ตัวก็ได้
  // >      : ปิดท้ายด้วย >
  type = type.replaceAll(RegExp(r'<[^>]*>'), '');
  content = 'Unmodifiable${type}View($content)';
  return content;
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

    String rawName = element.name!;

    // --- ส่วนที่แก้ไข: ดึงชื่อจาก Annotation ---
    // ถ้ามีการใส่ @TriggerGen("MyName") ค่าจะถูกดึงมา
    // ถ้าไม่ได้ใส่ (null) จะใช้ logic ตัด "Anno" แบบเดิม
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
      fxInit.writeln('$fx(this);');
    }
    String className =
        annotationName ??
        (rawName.endsWith('Anno')
            ? rawName.substring(0, rawName.length - 4)
            : rawName);
    // ---------------------------------------

    final gettersSetters = StringBuffer();
    final constName = StringBuffer();
    final initVal = StringBuffer();
    final fBody = StringBuffer();
    final stBody = StringBuffer();
    final efBody = StringBuffer();

    for (var field in element.fields) {
      if (field.isStatic || field.isExternal) continue;

      final name = field.name;
      String defaultValue = 'null';

      constName.writeln('static const String _$name = "$name";');

      // ดึง Default Value จาก AST (โค้ดส่วนเดิมของคุณ)
      final library = field.library;
      final session = library.session;
      final parsedLib =
          session.getParsedLibraryByElement(library!) as ParsedLibraryResult;

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
      // ใน loop ที่วน field
      final dartType = field.type;
      final typeStr = dartType.getDisplayString();
      var content = "getValue(_$name) as $typeStr";
      if (['List', 'Map', 'Set'].any(typeStr.startsWith))
        content = makeUnModify(typeStr, content);
      gettersSetters.writeln("\t$typeStr get $name => $content;");
      // gettersSetters.writeln(
      //   "\t$typeStr get $name => getValue('$name') as $typeStr;",
      // );
      gettersSetters.writeln(
        "\tset $name($typeStr val) => setValue(_$name, val);",
      );

      // initVal.writeln("\t\tsetValue('$name', $defaultValue);");
      initVal.writeln("\t\t$name = $defaultValue;");

      fBody.writeln('''
      ${className}Fields get $name {
        addField('$name');
        return this;
      }''');

      stBody.writeln('\tset $name($typeStr val) => _map["$name"] = val;');

      efBody.write(''' 
      $typeStr get $name => trigger.$name;
      set $name($typeStr val) {
        checkAllow('$name');
        trigger.$name = val;
      }
      ''');
    }

    return '''
typedef _${className}EffectCreator = void Function(${className} t);

final class $className extends Trigger {

  $constName

  static final $className _instance = $className._internal();
  static ${className}Fields get fields => ${className}Fields();

  bool _fxAttached = false;

  $className._internal([bool register=true]): super(register:register) {
    $initVal
    if (register) {
      $fxInit
      _fxAttached = true;
    }
  }

  /// Attaches all master effects declared in @TriggerGen(fx: [...])
/// 
/// - Must be called before any listeners are added
/// - Can be called only once per instance
/// - If no effects are declared → acts as no-op and locks further calls
  void attachMasterFx() {
    if (_fxAttached) {throw StateError("Multiple attachment attempts are not allowed. This process is restricted to a single occurrence.");}
    if (hasListeners()) {
    throw StateError(
      "Cannot attach master effects after listeners have been registered. "
      "Attach effects before any listening occurs."
    );
  }
    $fxInit
    _fxAttached = true;
  }

  // ignore: library_private_types_in_public_api
  void attachFx(List<_${className}EffectCreator> fxs) {
    if (_fxAttached) {throw StateError("Multiple attachment attempts are not allowed. This process is restricted to a single occurrence.");}
    if (hasListeners()) {
    throw StateError(
      "Cannot attach master effects after listeners have been registered. "
      "Attach effects before any listening occurs."
    );
  }
    for (var fx in fxs) {
      fx(this);
    }
    _fxAttached = true;
  }

  //this will be used to spawn a new MainStates instance that is not singleton.
  factory $className.spawn() => $className._internal(false);
  factory $className() => _instance;

  $gettersSetters

  // ignore: library_private_types_in_public_api
  void multiSet(void Function(_${className}MultiSetter setter) func) {
    final setter = _${className}MultiSetter();
    func(setter);
    setMultiValues(setter._map);
  }
}

final class ${className}Fields extends TriggerFields<${className}> {
$fBody
}

class _${className}MultiSetter {
  final _map = <String, dynamic>{};
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
