import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<String> exportBackup(String gymId) async {
    final db = await DatabaseHelper.instance.database;
    final dbPath = db.path;

    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory(p.join(tempDir.path, 'gym_backup_$gymId'));
    if (backupDir.existsSync()) backupDir.deleteSync(recursive: true);
    backupDir.createSync(recursive: true);

    final backupDbPath = p.join(backupDir.path, 'gym_erp.db');
    await db.execute("VACUUM INTO '$backupDbPath'");

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

    final backupDbPath = p.join(restoreDir.path, 'gym_erp.db');
    if (!File(backupDbPath).existsSync()) return false;

    await DatabaseHelper.instance.close();
    final docsDir = await getApplicationDocumentsDirectory();
    final targetPath = p.join(docsDir.path, 'gym_erp.db');
    await File(backupDbPath).copy(targetPath);
    await DatabaseHelper.instance.reopen();

    restoreDir.deleteSync(recursive: true);
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
