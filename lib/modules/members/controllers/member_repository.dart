import 'dart:developer';

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'member_dao.dart';
import 'member_stats_dao.dart';
import 'member_model.dart';
import 'member_stats.dart';

class MemberRepository {
  final MemberDao _memberDao;
  final MemberStatsDao _memberStatsDao;

  MemberRepository(this._memberDao, this._memberStatsDao);

  Future<List<MemberModel>> getAllMembers(String gymId) async {
    log('[MemberRepository] getAllMembers called gymId=$gymId');
    final data = await _memberDao.getAll(gymId);
    final members = data.map((e) => MemberModel.fromJson(e)).toList();
    log('[MemberRepository] getAllMembers returned ${members.length} members');
    return members;
  }

  Future<MemberModel?> getMemberById(String id) async {
    log('[MemberRepository] getMemberById called id=$id');
    final data = await _memberDao.getById(id);
    if (data == null) {
      log('[MemberRepository] getMemberById - not found');
      return null;
    }
    final member = MemberModel.fromJson(data);
    log('[MemberRepository] getMemberById found name=${member.fullName}');
    return member;
  }

  Future<MemberModel> createMember(MemberModel member) async {
    log('[MemberRepository] createMember called name=${member.fullName}');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final memberId = const Uuid().v4();
    final data = member.copyWith(
      memberId: memberId,
      registrationDate: now,
      createdAt: now,
      updatedAt: now,
    );
    await _memberDao.insert(data.toJson());
    log('[MemberRepository] createMember successful memberId=$memberId');
    return data;
  }

  Future<void> updateMember(MemberModel member) async {
    log('[MemberRepository] updateMember called memberId=${member.memberId}');
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final data = member.copyWith(updatedAt: now);
    await _memberDao.update(data.toJson());
    log('[MemberRepository] updateMember completed');
  }

  Future<bool> deleteMember(String id) async {
    log('[MemberRepository] deleteMember called id=$id');
    try {
      await _memberDao.delete(id);
      log('[MemberRepository] deleteMember successful');
      return true;
    } catch (e, stack) {
      log('[MemberRepository] deleteMember failed: $e');
      log('[MemberRepository] stack: $stack');
      return false;
    }
  }

  Future<List<MemberModel>> searchMembers(String gymId, String query) async {
    log('[MemberRepository] searchMembers called gymId=$gymId query=$query');
    final data = await _memberDao.search(gymId, query);
    final members = data.map((e) => MemberModel.fromJson(e)).toList();
    log('[MemberRepository] searchMembers returned ${members.length} results');
    return members;
  }

  Future<List<MemberModel>> getByStatus(String gymId, String status) async {
    log('[MemberRepository] getByStatus called gymId=$gymId status=$status');
    final data = await _memberDao.getByStatus(gymId, status);
    final members = data.map((e) => MemberModel.fromJson(e)).toList();
    log('[MemberRepository] getByStatus returned ${members.length} members');
    return members;
  }

  Future<List<MemberModel>> getExpiringSoon(String gymId, int days) async {
    log('[MemberRepository] getExpiringSoon called gymId=$gymId days=$days');
    final data = await _memberDao.getExpiringSoon(gymId, days);
    final members = data.map((e) => MemberModel.fromJson(e)).toList();
    log('[MemberRepository] getExpiringSoon returned ${members.length} members');
    return members;
  }

  Future<MemberModel?> getByPhone(String gymId, String phone) async {
    log('[MemberRepository] getByPhone called gymId=$gymId phone=$phone');
    final data = await _memberDao.getByPhone(gymId, phone);
    if (data == null) {
      log('[MemberRepository] getByPhone - not found');
      return null;
    }
    final member = MemberModel.fromJson(data);
    log('[MemberRepository] getByPhone found name=${member.fullName}');
    return member;
  }

  Future<MemberStats> getMemberStats(String id) async {
    log('[MemberRepository] getMemberStats called id=$id');
    return _memberStatsDao.getMemberStats(id);
  }
}
