# Trigger Generator

[![Pub Version](https://img.shields.io/pub/v/trigger_generator)](https://pub.dev/packages/trigger_generator)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A powerful code generator for **Trigger**, a high-performance state management library for Flutter and Dart. It automates the generation of `Trigger` classes, providing O(1) field access, unmodifiable views for collections, and seamless state binding.

## 🚀 Features

- **⚡ O(1) Performance**: Generates optimized getters and setters for instant field access.
- **🛡️ Data Integrity**: Automatically wraps `List`, `Map`, and `Set` in unmodifiable views for safer state management.
- **🔄 Multi-Setter**: Batch update multiple fields efficiently with a single notification.
- **🎯 Master Effects**: Declare side effects directly in annotations for automatic attachment.
- **🏗️ Boilerplate-Free**: No more manual index handling or repetitive trigger setup.

## 📦 Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  trigger: latest_version

dev_dependencies:
  trigger_generator: latest_version
  build_runner: ^2.4.0
```

## 🛠️ Usage

### 1. Define your State Class

Create a class with the `Anno` suffix (recommended) and annotate it with `@TriggerGen`.

```dart
import 'package:trigger/trigger.dart';

part 'counter.g.dart';

@TriggerGen(name: 'Counter')
class CounterAnno {
  int count = 0;
  String title = 'Initial Count';
  List<int> history = [];
}
```

### 2. Run the Generator

Run the following command in your terminal:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Use the Generated Class

The generator will create a `Counter` class based on your `CounterAnno` definition.

```dart
void main() {
  final counter = Counter();

  // O(1) field access
  counter.count = 1;
  print(counter.count); // 1

  // Batch updates
  counter.multiSet((setter) {
    setter.count = 10;
    setter.title = 'Updated Count';
  });

  // Collections are protected by unmodifiable views
  // counter.history.add(1); // Throws UnsupportedError
}
```

## 💎 Advanced Features

### Custom Class Names

Provide a `name` property to `@TriggerGen` to customize the generated class name.

```dart
@TriggerGen(name: 'MyState')
class StateDefinition { ... }
```

### Declaring Master Effects

You can specify "Master Effects" that will be automatically attached to the state instance.

```dart
@TriggerGen(fx: [LoggerEffect, AnalyticsEffect])
class AuthStateAnno { ... }
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
