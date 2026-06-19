import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<String> exportBackup(String gymId) async {
    final db = await DatabaseHelper.instance.database;
    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory(p.join(tempDir.path, 'gym_backup_$gymId'));
    if (backupDir.existsSync()) backupDir.deleteSync(recursive: true);
    backupDir.createSync(recursive: true);

    await db.execute("ATTACH DATABASE '${p.join(backupDir.path, 'gym_erp.db')}' AS backup");
    await db.execute("SELECT sql FROM sqlite_master WHERE type='table'");
    await db.execute("DETACH DATABASE backup");

    final archive = Archive();
    _addDirectoryToArchive(archive, backupDir, '');

    final zipData = ZipEncoder().encode(archive);
    final outputDir = await getApplicationDocumentsDirectory();
    final outputFile = File(p.join(outputDir.path, 'gym_backup_$gymId.zip'));
    await outputFile.writeAsBytes(zipData!);

    backupDir.deleteSync(recursive: true);
    return outputFile.path;
  }

  Future<bool> importBackup(String filePath, String gymId) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    final restoreDir = Directory(p.join(tempDir.path, 'restore_$gymId'));
    if (restoreDir.existsSync()) restoreDir.deleteSync(recursive: true);
    restoreDir.createSync(recursive: true);

    for (final entry in archive) {
      if (entry.isFile) {
        final file = File(p.join(restoreDir.path, entry.name));
        file.parent.createSync(recursive: true);
        await file.writeAsBytes(entry.content as List<int>);
      }
    }

    return true;
  }

  void _addDirectoryToArchive(Archive archive, Directory dir, String basePath) {
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final relativePath = p.join(basePath, p.basename(entity.path));
        archive.addFile(ArchiveFile(relativePath, entity.lengthSync(), entity.readAsBytesSync()));
      } else if (entity is Directory) {
        _addDirectoryToArchive(archive, entity, p.join(basePath, p.basename(entity.path)));
      }
    }
  }
}
