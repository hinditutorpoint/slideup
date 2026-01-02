import 'package:disk_space_plus/disk_space_plus.dart';

class DiskInfo {
  final double totalGB;
  final double freeGB;

  DiskInfo(this.totalGB, this.freeGB);

  double get usedGB => totalGB - freeGB;
  double get usedFraction => usedGB / totalGB;
}

Future<DiskInfo> getStorageInfo() async {
  DiskSpacePlus diskSpacePlus = DiskSpacePlus();
  final total = await diskSpacePlus.getTotalDiskSpace ?? 0;
  final free = await diskSpacePlus.getFreeDiskSpace ?? 0;

  return DiskInfo(
    total / 1024, // MB → GB
    free / 1024,
  );
}
