class StorageInfo {
  final String name;
  final String path;
  final StorageType type;
  final int totalSpace;
  final int freeSpace;
  final bool isAccessible;

  const StorageInfo({
    required this.name,
    required this.path,
    required this.type,
    required this.totalSpace,
    required this.freeSpace,
    required this.isAccessible,
  });

  double get usedPercentage {
    if (totalSpace == 0) return 0.0;
    return (totalSpace - freeSpace) / totalSpace;
  }
}

enum StorageType { internal, external, usb, network }
