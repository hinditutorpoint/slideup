// lib/models/database_config.dart
class DatabaseConfig {
  final String name;
  final String displayName;
  final String fileName;
  final bool isRequired;

  const DatabaseConfig({
    required this.name,
    required this.displayName,
    required this.fileName,
    this.isRequired = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatabaseConfig &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
