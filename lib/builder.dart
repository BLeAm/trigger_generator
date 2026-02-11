import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'generator.dart';

Builder triggerBuilder(BuilderOptions options) =>
    // เปลี่ยนจาก SharedPartBuilder เป็น PartBuilder
    PartBuilder([TriggerGenerator()], '.g.dart');
