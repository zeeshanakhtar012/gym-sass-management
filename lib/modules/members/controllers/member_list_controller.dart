import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_service.dart';
import 'member_repository.dart';
import 'member_model.dart';
import '../../../widgets/popups/app_popup.dart';

class MemberListController extends GetxController {
  final MemberRepository _memberRepository = Get.find<MemberRepository>();
  final AuthService _authService = Get.find<AuthService>();

  final RxList<MemberModel> members = <MemberModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final RxString statusFilter = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    log('[MemberListController] onInit');
    loadMembers('');
  }

  @override
  void onClose() {
    log('[MemberListController] onClose');
    super.onClose();
  }

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  Future<void> loadMembers(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[MemberListController] loadMembers called gymId=$gymId');
    isLoading.value = true;
    try {
      final data = await _memberRepository.getAllMembers(gymId);
      members.value = data;
      log('[MemberListController] loadMembers loaded ${data.length} members');
    } catch (e, stack) {
      log('[MemberListController] loadMembers failed: $e');
      log('[MemberListController] stack: $stack');
      AppPopup.error('Failed to load members');
    } finally {
      isLoading.value = false;
    }
  }

  List<MemberModel> get filteredMembers {
    final query = searchQuery.value.trim().toLowerCase();
    final filter = statusFilter.value;
    var list = members;
    if (filter != 'all') {
      list = members.where((m) => m.status == filter).toList().obs;
    }
    if (query.isEmpty) return list;
    return list.where((m) {
      return m.fullName.toLowerCase().contains(query) ||
          (m.phone?.contains(query) ?? false) ||
          (m.cnic?.contains(query) ?? false);
    }).toList();
  }

  Future<bool> deleteMember(String id) async {
    log('[MemberListController] deleteMember called id=$id');
    try {
      final success = await _memberRepository.deleteMember(id);
      if (success) {
        members.removeWhere((m) => m.memberId == id);
        log('[MemberListController] deleteMember successful');
        AppPopup.success('Member deleted successfully');
      } else {
        log('[MemberListController] deleteMember failed');
        AppPopup.error('Failed to delete member');
      }
      return success;
    } catch (e, stack) {
      log('[MemberListController] deleteMember failed: $e');
      log('[MemberListController] stack: $stack');
      AppPopup.error('Failed to delete member');
      return false;
    }
  }
}
