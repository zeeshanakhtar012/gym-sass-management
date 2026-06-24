import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/database/database_helper.dart';
import '../../auth/controllers/auth_service.dart';
import '../../../widgets/popups/app_popup.dart';

class KeyboardAttendanceView extends StatefulWidget {
  final String gymId;
  const KeyboardAttendanceView({super.key, this.gymId = ''});

  @override
  State<KeyboardAttendanceView> createState() => _KeyboardAttendanceViewState();
}

class _KeyboardAttendanceViewState extends State<KeyboardAttendanceView> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AuthService _authService = Get.find<AuthService>();
  final searchController = TextEditingController();

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  List<Map<String, dynamic>> _checkedInToday = [];
  bool _isLoading = true;
  bool _showSuccess = false;
  String _successName = '';
  int _todayCount = 0;
  Timer? _successTimer;
  Timer? _debounce;

  String get _gymId => widget.gymId.isNotEmpty ? widget.gymId : (_authService.currentGymId ?? '');

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final gymId = _gymId;
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final members = await db.query('members',
        where: 'gym_id = ? AND status = ?',
        whereArgs: [gymId, 'active'],
        orderBy: 'full_name ASC',
      );
      _members = members;
      _filteredMembers = members;

      final countResult = await db.rawQuery(
        "SELECT COUNT(*) as c FROM attendance WHERE gym_id = ? AND date = ?",
        [gymId, today],
      );
      _todayCount = (countResult.first['c'] as int?) ?? 0;

      final checkedIn = await db.query('attendance',
        where: 'gym_id = ? AND date = ? AND check_out IS NULL',
        whereArgs: [gymId, today],
      );
      _checkedInToday = checkedIn;
    } catch (e) {
      debugPrint('[KeyboardAttendance] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final query = searchController.text.trim().toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _filteredMembers = _members;
        } else {
          _filteredMembers = _members.where((m) {
            final name = (m['full_name'] as String? ?? '').toLowerCase();
            final phone = (m['phone'] as String? ?? '').toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList();
        }
      });
    });
  }

  Future<void> _checkIn(String memberId, String memberName) async {
    try {
      final db = await _dbHelper.database;
      final gymId = _gymId;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final now = DateTime.now().toIso8601String().substring(11, 16);

      final existing = await db.query('attendance',
        where: 'gym_id = ? AND member_id = ? AND date = ? AND check_out IS NULL',
        whereArgs: [gymId, memberId, today],
      );
      if (existing.isNotEmpty) {
        AppPopup.warning('Already checked in today');
        return;
      }

      await db.insert('attendance', {
        'gym_id': gymId,
        'member_id': memberId,
        'date': today,
        'check_in': now,
        'method': 'manual',
        'created_at': DateTime.now().toIso8601String(),
      });

      _todayCount++;
      _checkedInToday.add({'member_id': memberId});

      _successTimer?.cancel();
      setState(() {
        _showSuccess = true;
        _successName = memberName;
      });
      _successTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() {
          _showSuccess = false;
          _successName = '';
        });
      });
    } catch (e) {
      debugPrint('[KeyboardAttendance] checkIn error: $e');
      AppPopup.error('Check-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E11),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.x, color: Color(0xFF8C9BA3)),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '// KEYBOARD CHECK-IN',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
            ),
            child: Text(
              '$_todayCount TODAY',
              style: const TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF41)))
          : _showSuccess
              ? _buildSuccessScreen()
              : _buildSearchScreen(),
    );
  }

  Widget _buildSearchScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: searchController,
            autofocus: true,
            style: const TextStyle(
              color: Color(0xFF00FF41),
              fontSize: 20,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: '> type name or phone...',
              hintStyle: const TextStyle(
                color: Color(0xFF2C3A3F),
                fontSize: 20,
                fontFamily: 'monospace',
              ),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Color(0xFF2C3A3F), size: 24),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(PhosphorIconsRegular.x, color: Color(0xFF2C3A3F)),
                      onPressed: () => searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0D1B0D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00FF41)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
        Expanded(child: _buildMemberList()),
      ],
    );
  }

  Widget _buildMemberList() {
    if (_filteredMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchController.text.isNotEmpty ? PhosphorIconsRegular.userMinus : PhosphorIconsRegular.users,
              size: 64,
              color: const Color(0xFF2C3A3F),
            ),
            const SizedBox(height: 16),
            Text(
              searchController.text.isNotEmpty ? '> NO MATCHES' : '> NO ACTIVE MEMBERS',
              style: const TextStyle(color: Color(0xFF2C3A3F), fontSize: 14, fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredMembers.length,
      itemBuilder: (_, i) => _buildMemberCard(_filteredMembers[i]),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final memberId = member['member_id'] as String;
    final name = member['full_name'] as String? ?? 'Unknown';
    final phone = member['phone'] as String?;
    final isCheckedIn = _checkedInToday.any((c) => c['member_id'] == memberId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckedIn
              ? const Color(0xFF00FF41).withValues(alpha: 0.4)
              : const Color(0xFF1A2226),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isCheckedIn ? null : () => _checkIn(memberId, name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2226),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PhosphorIconsRegular.user,
                  color: isCheckedIn ? const Color(0xFF00FF41) : const Color(0xFF2C3A3F),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF8C9BA3),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCheckedIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'IN',
                    style: TextStyle(
                      color: Color(0xFF00FF41),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CHECK IN',
                    style: TextStyle(
                      color: Color(0xFF00FF41),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '> CHECKED IN',
            style: TextStyle(
              color: Color(0xFF00FF41),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Icon(PhosphorIconsRegular.checkCircle, size: 80, color: Color(0xFF00FF41)),
          const SizedBox(height: 24),
          Text(
            _successName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              _successTimer?.cancel();
              setState(() {
                _showSuccess = false;
                _successName = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2226),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C3A3F)),
              ),
              child: const Text(
                '> tap to continue',
                style: TextStyle(color: Color(0xFF8C9BA3), fontSize: 14, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
