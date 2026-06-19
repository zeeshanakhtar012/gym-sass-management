import 'dart:developer';

import 'package:bcrypt/bcrypt.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'gym_dao.dart';
import 'gym_model.dart';

class GymRepository {
  final GymDao _gymDao;

  GymRepository(this._gymDao);

  Future<List<GymModel>> getAllGyms() async {
    log('[GymRepository] getAllGyms called');
    final data = await _gymDao.getAll();
    final gyms = data.map((e) => GymModel.fromJson(e)).toList();
    log('[GymRepository] getAllGyms returned ${gyms.length} gyms');
    return gyms;
  }

  Future<GymModel?> getGymById(String id) async {
    log('[GymRepository] getGymById called id=$id');
    final data = await _gymDao.getById(id);
    if (data == null) {
      log('[GymRepository] getGymById - not found');
      return null;
    }
    final gym = GymModel.fromJson(data);
    log('[GymRepository] getGymById found name=${gym.name}');
    return gym;
  }

  Future<GymModel> createGym(GymModel gym, String password) async {
    log('[GymRepository] createGym called name=${gym.name}');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final gymId = const Uuid().v4();
    final data = gym.copyWith(
      gymId: gymId,
      createdAt: now,
      updatedAt: now,
      passwordHash: hash,
    );
    await _gymDao.insert(data.toJson());
    log('[GymRepository] createGym successful gymId=$gymId');
    return data;
  }

  Future<void> updateGym(GymModel gym) async {
    log('[GymRepository] updateGym called gymId=${gym.gymId}');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final data = gym.copyWith(updatedAt: now).toJson();
    data.remove('password_hash');
    await _gymDao.update(data);
    log('[GymRepository] updateGym completed');
  }

  Future<bool> deleteGym(String id) async {
    log('[GymRepository] deleteGym called id=$id');
    try {
      await _gymDao.delete(id);
      log('[GymRepository] deleteGym successful');
      return true;
    } catch (e, stack) {
      log('[GymRepository] deleteGym failed: $e');
      log('[GymRepository] stack: $stack');
      return false;
    }
  }

  Future<void> toggleGymStatus(String id) async {
    log('[GymRepository] toggleGymStatus called id=$id');
    await _gymDao.toggleStatus(id);
    log('[GymRepository] toggleGymStatus completed');
  }

  Future<int> getMemberCount(String id) async {
    log('[GymRepository] getMemberCount called id=$id');
    return _gymDao.getMemberCount(id);
  }

  Future<Map<String, int>> getSystemStats() async {
    log('[GymRepository] getSystemStats called');
    return _gymDao.getStats();
  }
}
