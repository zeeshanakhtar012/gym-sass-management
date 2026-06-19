import 'dart:developer';

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import 'package_dao.dart';
import 'package_model.dart';

class PackageRepository {
  final PackageDao _packageDao;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  PackageRepository(this._packageDao);

  Future<List<PackageModel>> getAll(String gymId) async {
    log('[PackageRepository] getAll called gymId=$gymId');
    final data = await _packageDao.getAll(gymId);
    final packages = data.map((e) => PackageModel.fromJson(e)).toList();
    log('[PackageRepository] getAll returned ${packages.length} packages');
    return packages;
  }

  Future<PackageModel> create(PackageModel pkg) async {
    log('[PackageRepository] create called name=${pkg.name}');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final packageId = const Uuid().v4();
    final data = pkg.copyWith(packageId: packageId, createdAt: now);
    await _packageDao.insert(data.toJson());
    log('[PackageRepository] create successful packageId=$packageId');
    return data;
  }

  Future<void> update(PackageModel pkg) async {
    log('[PackageRepository] update called packageId=${pkg.packageId}');
    await _packageDao.update(pkg.toJson());
    log('[PackageRepository] update completed');
  }

  Future<bool> delete(String id) async {
    log('[PackageRepository] delete called id=$id');
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM members WHERE package_id = ?', [id],
      );
      final count = result.first['c'] as int? ?? 0;
      if (count > 0) {
        log('[PackageRepository] delete - package has $count active members');
        return false;
      }
      await _packageDao.delete(id);
      log('[PackageRepository] delete successful');
      return true;
    } catch (e, stack) {
      log('[PackageRepository] delete failed: $e');
      log('[PackageRepository] stack: $stack');
      return false;
    }
  }
}
