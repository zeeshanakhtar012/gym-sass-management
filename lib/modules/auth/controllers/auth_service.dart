import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'auth_dao.dart';
import 'session_model.dart';
import 'auth_repository.dart';

class AuthService extends GetxService {
  final AuthRepository _authRepository;
  final AuthDao _authDao;

  AuthService(this._authRepository, this._authDao);

  final Rx<SessionModel?> currentSession = Rx<SessionModel?>(null);

  bool get isLoggedIn => currentSession.value != null;
  bool get isSuperAdmin => currentSession.value?.role == 'super_admin';
  String? get currentGymId => currentSession.value?.gymId;
  bool get mustChangePassword => currentSession.value?.mustChangePassword ?? false;

  @override
  void onInit() {
    super.onInit();
    log('[AuthService] onInit');
  }

  @override
  void onClose() {
    log('[AuthService] onClose');
    super.onClose();
  }

  Future<SessionModel> login(String username, String password, {bool isGym = false}) async {
    log('[AuthService] login called username=$username isGym=$isGym');
    late SessionModel? session;
    if (isGym) {
      session = await _authRepository.loginGym(username, password);
    } else {
      session = await _authRepository.loginSuperAdmin(username, password);
    }
    if (session == null) {
      log('[AuthService] login - invalid credentials');
      throw Exception('Invalid credentials');
    }
    currentSession.value = session;
    log('[AuthService] login successful userId=${session.userId} role=${session.role}');
    if (isGym) {
      await _persistSession(session);
      log('[AuthService] gym session persisted');
    }
    return session;
  }

  Future<void> logout() async {
    log('[AuthService] logout called');
    currentSession.value = null;
    await _clearPersistedSession();
    log('[AuthService] logout completed');
  }

  Future<bool> changePassword(String old, String newPwd) async {
    log('[AuthService] changePassword called');
    if (currentSession.value == null) {
      log('[AuthService] changePassword - no active session');
      return false;
    }
    final result = await _authRepository.changePassword(
      currentSession.value!,
      old,
      newPwd,
    );
    if (result) {
      final updated = currentSession.value!.copyWith(mustChangePassword: false);
      currentSession.value = updated;
      log('[AuthService] changePassword successful');
    } else {
      log('[AuthService] changePassword failed');
    }
    return result;
  }

  Future<void> _persistSession(SessionModel session) async {
    await _authDao.saveSession(jsonEncode(session.toJson()));
  }

  Future<void> _clearPersistedSession() async {
    await _authDao.clearSession();
  }

  Future<bool> resetGymPassword(String gymId, String newPassword) async {
    log('[AuthService] resetGymPassword called gymId=$gymId');
    return _authRepository.resetGymPassword(gymId, newPassword);
  }

  Future<SessionModel?> restoreSession() async {
    log('[AuthService] restoreSession called');
    try {
      final data = await _authDao.getSession();
      if (data == null) {
        log('[AuthService] restoreSession - no saved session');
        return null;
      }
      final json = jsonDecode(data) as Map<String, dynamic>;
      final session = SessionModel.fromJson(json);
      if (session.role == 'super_admin') {
        log('[AuthService] restoreSession - super admin session found, clearing it');
        await _clearPersistedSession();
        return null;
      }
      currentSession.value = session;
      log('[AuthService] restoreSession - gym session restored gymId=${session.gymId}');
      return session;
    } catch (e) {
      log('[AuthService] restoreSession - error: $e');
      await _clearPersistedSession();
      return null;
    }
  }
}
