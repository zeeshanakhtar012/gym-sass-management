import 'dart:developer';

import 'package:bcrypt/bcrypt.dart';
import 'auth_dao.dart';
import 'session_model.dart';

class AuthRepository {
  final AuthDao _authDao;

  AuthRepository(this._authDao);

  Future<SessionModel?> loginSuperAdmin(String username, String password) async {
    log('[AuthRepository] loginSuperAdmin called with username=$username');
    final admin = await _authDao.getSuperAdmin(username);
    if (admin == null) {
      log('[AuthRepository] loginSuperAdmin - admin not found');
      return null;
    }
    if (!BCrypt.checkpw(password, admin['password_hash'] as String)) {
      log('[AuthRepository] loginSuperAdmin - password mismatch');
      return null;
    }
    log('[AuthRepository] loginSuperAdmin successful');
    return SessionModel(
      userId: admin['id'].toString(),
      role: 'super_admin',
      username: admin['username'] as String,
      mustChangePassword: (admin['must_change_password'] as int) == 1,
    );
  }

  Future<SessionModel?> loginGym(String phone, String password) async {
    log('[AuthRepository] loginGym called with phone=$phone');
    final gym = await _authDao.getGymByPhone(phone);
    if (gym == null) {
      log('[AuthRepository] loginGym - gym not found');
      return null;
    }
    if (gym['status'] != 'active') {
      log('[AuthRepository] loginGym - gym not active');
      return null;
    }
    if (!BCrypt.checkpw(password, gym['password_hash'] as String)) {
      log('[AuthRepository] loginGym - password mismatch');
      return null;
    }
    log('[AuthRepository] loginGym successful');
    return SessionModel(
      userId: gym['gym_id'] as String,
      gymId: gym['gym_id'] as String,
      role: 'gym_admin',
      username: gym['name'] as String,
    );
  }

  Future<bool> changePassword(SessionModel session, String oldPassword, String newPassword) async {
    log('[AuthRepository] changePassword called for role=${session.role}');
    if (session.role == 'super_admin') {
      final admin = await _authDao.getSuperAdmin(session.username);
      if (admin == null) {
        log('[AuthRepository] changePassword - super_admin not found');
        return false;
      }
      if (!BCrypt.checkpw(oldPassword, admin['password_hash'] as String)) {
        log('[AuthRepository] changePassword - old password mismatch');
        return false;
      }
      final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
      await _authDao.updateSuperAdminPassword(admin['id'] as int, newHash);
      await _authDao.updateSuperAdminMustChangePassword(admin['id'] as int, 0);
      log('[AuthRepository] changePassword - super_admin password changed');
      return true;
    } else if (session.role == 'gym_admin') {
      final gymId = session.gymId;
      if (gymId == null) {
        log('[AuthRepository] changePassword - gymId is null');
        return false;
      }
      final gym = await _authDao.getGymById(gymId);
      if (gym == null) {
        log('[AuthRepository] changePassword - gym not found');
        return false;
      }
      if (!BCrypt.checkpw(oldPassword, gym['password_hash'] as String)) {
        log('[AuthRepository] changePassword - old password mismatch');
        return false;
      }
      final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
      await _authDao.updateGymPassword(gymId, newHash);
      log('[AuthRepository] changePassword - gym password changed');
      return true;
    }
    log('[AuthRepository] changePassword - unknown role');
    return false;
  }

  Future<bool> verifyPassword(SessionModel session, String password) async {
    log('[AuthRepository] verifyPassword called for role=${session.role}');
    if (session.role == 'super_admin') {
      final admin = await _authDao.getSuperAdmin(session.username);
      if (admin == null) {
        log('[AuthRepository] verifyPassword - super_admin not found');
        return false;
      }
      final result = BCrypt.checkpw(password, admin['password_hash'] as String);
      log('[AuthRepository] verifyPassword - super_admin result=$result');
      return result;
    } else if (session.role == 'gym_admin') {
      final gymId = session.gymId;
      if (gymId == null) {
        log('[AuthRepository] verifyPassword - gymId is null');
        return false;
      }
      final gym = await _authDao.getGymById(gymId);
      if (gym == null) {
        log('[AuthRepository] verifyPassword - gym not found');
        return false;
      }
      final result = BCrypt.checkpw(password, gym['password_hash'] as String);
      log('[AuthRepository] verifyPassword - gym_admin result=$result');
      return result;
    }
    log('[AuthRepository] verifyPassword - unknown role');
    return false;
  }
}
