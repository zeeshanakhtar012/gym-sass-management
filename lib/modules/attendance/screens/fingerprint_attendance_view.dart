import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/dartafis_service.dart';
import '../../../core/services/zkteco_scanner_service.dart';
import '../../../core/constants/app_constants.dart';

class FingerprintAttendanceView extends StatefulWidget {
  final String gymId;
  const FingerprintAttendanceView({super.key, this.gymId = ''});

  @override
  State<FingerprintAttendanceView> createState() => _FingerprintAttendanceViewState();
}

class _FingerprintAttendanceViewState extends State<FingerprintAttendanceView> {
  final ZKTecoBiometricService _scanner = ZKTecoBiometricService();
  final DartafisService _dartafis = DartafisService();

  bool _isDeviceConnected = false;
  bool _isScanning = false;
  bool _showSuccess = false;
  String _statusMessage = 'Initializing device...';
  String _detectedName = '';
  String _detectedPhone = '';
  String _detectedPackage = '';
  String _detectedExpiry = '';
  int _detectedDaysRemaining = 0;
  int _todayCount = 0;
  bool _scanLoopActive = false;

  /// Stable ordered list of members with enrolled fingerprint templates.
  List<_FingerprintMember> _fpMembers = [];

  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _initScanner();
    _loadTodayCount();
  }

  @override
  void dispose() {
    _scanLoopActive = false;
    _autoDismissTimer?.cancel();
    _scanner.disconnect();
    super.dispose();
  }

  Future<void> _initScanner() async {
    log('[FingerprintAttendance] _initScanner: checking connection...');
    final connected = await _scanner.isScannerConnected();
    log('[FingerprintAttendance] _initScanner: connected=$connected');
    if (!mounted) return;
    setState(() {
      _isDeviceConnected = connected;
      _statusMessage = connected
          ? 'Place your finger on the scanner'
          : 'Fingerprint device not connected';
    });
    if (connected) {
      log('[FingerprintAttendance] device connected, loading templates...');
      await _loadTemplates();
      if (_fpMembers.isEmpty) {
        log('[FingerprintAttendance] no members with fingerprints registered');
        if (mounted) {
          setState(() => _statusMessage = 'No fingerprints registered\nEnroll members first');
        }
        return;
      }
      log('[FingerprintAttendance] starting scan loop...');
      _startScanLoop();
    }
  }

  Future<void> _loadTemplates() async {
    try {
      log('[FingerprintAttendance] _loadTemplates: querying database...');
      final db = await DatabaseHelper.instance.database;
      final gymId = widget.gymId;

      final rows = await db.rawQuery('''
        SELECT m.member_id, m.full_name, m.phone, m.fingerprint_data,
               m.fingerprint_image, m.package_id, m.expiry_date,
               p.name AS package_name
        FROM members m
        LEFT JOIN packages p ON m.package_id = p.package_id
        WHERE m.status = 'active'
          AND (m.fingerprint_data IS NOT NULL OR m.fingerprint_image IS NOT NULL)
        ${gymId.isNotEmpty ? 'AND m.gym_id = ?' : ''}
        ORDER BY m.full_name ASC
      ''', gymId.isNotEmpty ? [gymId] : []);

      final members = <_FingerprintMember>[];
      int migrated = 0;

      for (final row in rows) {
        var fpData = row['fingerprint_data'] as Uint8List?;

        // On-the-fly migration from legacy fingerprint_image
        if (fpData == null) {
          final fpImage = row['fingerprint_image'] as Uint8List?;
          if (fpImage != null && fpImage.length == AppConstants.fingerprintImageSize) {
            log('[FingerprintAttendance] migrating legacy fingerprint for '
                '${row['member_id']}');
            final serialized = await _dartafis.migrateLegacyImage(fpImage);
            if (serialized != null && _dartafis.isValidTemplate(serialized)) {
              await db.update(
                'members',
                {'fingerprint_data': serialized},
                where: 'member_id = ?',
                whereArgs: [row['member_id']],
              );
              fpData = serialized;
              migrated++;
              log('[FingerprintAttendance] migrated legacy fingerprint for '
                  '${row['member_id']}');
            }
          }
        }

        if (fpData != null && fpData.isNotEmpty && _dartafis.isValidTemplate(fpData)) {
          members.add(_FingerprintMember(
            memberId: row['member_id'] as String,
            fullName: row['full_name'] as String? ?? 'Unknown',
            phone: row['phone'] as String? ?? '',
            template: fpData,
            packageName: row['package_name'] as String? ?? '',
            expiryDate: row['expiry_date'] as String? ?? '',
          ));
        }
      }

      if (migrated > 0) {
        log('[FingerprintAttendance] migrated $migrated legacy records');
      }

      _fpMembers = members;
      log('[FingerprintAttendance] loaded ${_fpMembers.length} members '
          'with fingerprint templates');
    } catch (e) {
      log('[FingerprintAttendance] _loadTemplates error: $e');
    }
  }

  void _startScanLoop() {
    if (_scanLoopActive) return;
    _scanLoopActive = true;
    _runScanLoop();
  }

  Future<void> _runScanLoop() async {
    log('[FingerprintAttendance] _runScanLoop started');
    while (_scanLoopActive && mounted) {
      try {
        if (!_isDeviceConnected) {
          log('[FingerprintAttendance] device not connected, waiting...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        setState(() {
          _isScanning = true;
          _statusMessage = 'Waiting for finger...';
        });

        log('[FingerprintAttendance] calling identifyByDartafis...');
        final candidateTemplates =
            _fpMembers.map((m) => m.template).toList();
        final matchResult = await _scanner.identifyByDartafis(
          candidateTemplates: candidateTemplates,
          scoreThreshold: AppConstants.fingerprintMatchThreshold,
        );
        log('[FingerprintAttendance] identifyByDartafis returned '
            'result=$matchResult');

        if (!_scanLoopActive || !mounted) break;

        if (matchResult == null ||
            !matchResult.isMatched ||
            matchResult.templateIndex < 0 ||
            matchResult.templateIndex >= _fpMembers.length) {
          log('[FingerprintAttendance] no match '
              '(threshold=${AppConstants.fingerprintMatchThreshold})');
          setState(() {
            _isScanning = false;
            _statusMessage = 'Unknown fingerprint. Try again.';
          });
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            setState(() => _statusMessage = 'Place your finger on the scanner');
          }
          continue;
        }

        final matchedMember = _fpMembers[matchResult.templateIndex];
        log('[FingerprintAttendance] Match score: '
            '${matchResult.score.toStringAsFixed(1)} '
            'for template #${matchResult.templateIndex}');
        log('[FingerprintAttendance] User matched: '
            '${matchedMember.fullName} '
            '(score=${matchResult.score.toStringAsFixed(1)}, '
            'threshold=${AppConstants.fingerprintMatchThreshold})');

        setState(() {
          _statusMessage = 'Identifying...';
        });

        if (!_scanLoopActive || !mounted) break;

        _detectedName = matchedMember.fullName;
        _detectedPhone = matchedMember.phone;
        _detectedPackage = matchedMember.packageName;
        _detectedExpiry = matchedMember.expiryDate;
        if (_detectedExpiry.isNotEmpty) {
          final parsed = DateTime.tryParse(_detectedExpiry);
          _detectedDaysRemaining =
              parsed != null ? parsed.difference(DateTime.now()).inDays : 0;
        } else {
          _detectedDaysRemaining = 0;
        }

        final alreadyCheckedIn =
            await _isAlreadyCheckedIn(matchedMember.memberId);

        if (!alreadyCheckedIn) {
          await _recordAttendance(matchedMember.memberId);
        }

        if (!mounted) return;
        setState(() {
          _showSuccess = true;
          _isScanning = false;
          _statusMessage =
              alreadyCheckedIn ? 'Already checked in today' : 'Check-in recorded';
        });

        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() {
              _showSuccess = false;
              _statusMessage = 'Place your finger on the scanner';
              _detectedName = '';
              _detectedPhone = '';
              _detectedPackage = '';
              _detectedExpiry = '';
              _detectedDaysRemaining = 0;
            });
          }
        });
      } catch (e, stack) {
        log('[FingerprintAttendance] scan loop error: $e $stack');
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Scan error, retrying...';
          });
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<bool> _isAlreadyCheckedIn(String memberId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final result = await db.query(
        'attendance',
        where: 'member_id = ? AND date = ? AND check_out IS NULL',
        whereArgs: [memberId, today],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordAttendance(String memberId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm').format(now);
      final createdAtStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      await db.insert('attendance', {
        'gym_id': widget.gymId.isNotEmpty
            ? widget.gymId
            : (await _getDefaultGymId()),
        'member_id': memberId,
        'date': dateStr,
        'check_in': timeStr,
        'method': 'fingerprint',
        'created_at': createdAtStr,
      });

      await _loadTodayCount();
      log('[FingerprintAttendance] recorded for memberId=$memberId');
    } catch (e, stack) {
      log('[FingerprintAttendance] record error: $e $stack');
    }
  }

  Future<String> _getDefaultGymId() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('gyms', limit: 1);
      if (result.isNotEmpty) return result.first['gym_id'] as String;
    } catch (_) {}
    return '';
  }

  Future<void> _loadTodayCount() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final gymId = await _getDefaultGymId();
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM attendance WHERE date = ? AND gym_id = ?',
        [today, gymId],
      );
      if (mounted) {
        setState(() {
          _todayCount = (result.first['c'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  // ─────── UI ───────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E11),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _showSuccess ? _buildSuccessScreen() : _buildScanScreen(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.manual,
                overlays: SystemUiOverlay.values,
              );
              Get.back();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2226),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C3A3F)),
              ),
              child: const Icon(
                PhosphorIconsRegular.x,
                color: Color(0xFF8C9BA3),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                const Text(
                  '// FINGERPRINT ATTENDANCE',
                  style: TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isDeviceConnected ? 'DEVICE ACTIVE' : 'DEVICE DISCONNECTED',
                  style: TextStyle(
                    color: _isDeviceConnected
                        ? const Color(0xFF00FF41)
                        : const Color(0xFF8C9BA3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isDeviceConnected
                  ? const Color(0xFF00FF41)
                  : const Color(0xFF8C9BA3),
              boxShadow: _isDeviceConnected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00FF41).withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildScannerIcon(),
        const SizedBox(height: 32),
        Text(
          _statusMessage,
          style: TextStyle(
            color: _isDeviceConnected
                ? const Color(0xFF00FF41)
                : const Color(0xFF8C9BA3),
            fontSize: 16,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_detectedName.isNotEmpty && !_showSuccess)
          Text(
            '> DETECTED: $_detectedName',
            style: const TextStyle(
              color: Color(0xFF8C9BA3),
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        if (_isScanning) ...[
          const SizedBox(height: 32),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF00FF41),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScannerIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Opacity(
          opacity: _isScanning ? 1.0 : 0.4 + (value * 0.6),
          child: Transform.scale(
            scale: _isScanning ? 1.0 : 0.95 + (value * 0.05),
            child: Icon(
              PhosphorIconsRegular.fingerprint,
              size: 96,
              color: _isDeviceConnected
                  ? const Color(0xFF00FF41)
                  : const Color(0xFF2C3A3F),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessScreen() {
    final isExpired = _detectedExpiry.isNotEmpty && _detectedDaysRemaining < 0;
    final isExpiring = _detectedExpiry.isNotEmpty &&
        _detectedDaysRemaining >= 0 &&
        _detectedDaysRemaining <= 7;
    final subColor = isExpired
        ? const Color(0xFFFF4444)
        : (isExpiring
            ? const Color(0xFFFFAA00)
            : const Color(0xFF00FF41));
    final subText =
        isExpired ? 'EXPIRED' : (isExpiring ? 'EXPIRING SOON' : 'ACTIVE');

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const Text(
            '> ACCESS GRANTED',
            style: TextStyle(
              color: Color(0xFF00FF41),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Icon(
            PhosphorIconsRegular.checkCircle,
            size: 72,
            color: Color(0xFF00FF41),
          ),
          const SizedBox(height: 16),
          Text(
            _detectedName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
          if (_detectedPhone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _detectedPhone,
              style: const TextStyle(
                color: Color(0xFF8C9BA3),
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00FF41).withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'CHECKED IN',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 4,
              ),
            ),
          ),
          if (_detectedPackage.isNotEmpty || _detectedExpiry.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2226),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: subColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  if (_detectedPackage.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Package',
                            style: TextStyle(
                                color: Color(0xFF8C9BA3),
                                fontSize: 12,
                                fontFamily: 'monospace')),
                        Text(_detectedPackage,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_detectedExpiry.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expiry',
                            style: TextStyle(
                                color: Color(0xFF8C9BA3),
                                fontSize: 12,
                                fontFamily: 'monospace')),
                        Text(_detectedExpiry,
                            style: TextStyle(
                                color: subColor,
                                fontSize: 14,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status',
                          style: TextStyle(
                              color: Color(0xFF8C9BA3),
                              fontSize: 12,
                              fontFamily: 'monospace')),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: subColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: subColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(subText,
                            style: TextStyle(
                                color: subColor,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ),
                    ],
                  ),
                  if (!isExpired && _detectedExpiry.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Days Left',
                            style: TextStyle(
                                color: Color(0xFF8C9BA3),
                                fontSize: 12,
                                fontFamily: 'monospace')),
                        Text('$_detectedDaysRemaining days',
                            style: TextStyle(
                                color: subColor,
                                fontSize: 14,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                    PhosphorIconsRegular.signIn,
                    color: Color(0xFF00FF41),
                    size: 18),
                const SizedBox(width: 8),
                Text(
                  '$_todayCount TODAY',
                  style: const TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B0D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C3A3F)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                    PhosphorIconsRegular.fingerprint,
                    color: Color(0xFF00FF41),
                    size: 18),
                const SizedBox(width: 8),
                Text(
                  _isDeviceConnected ? 'SCANNER ACTIVE' : 'NO DEVICE',
                  style: const TextStyle(
                    color: Color(0xFF8C9BA3),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight holder for a member's biometric data used during attendance.
class _FingerprintMember {
  final String memberId;
  final String fullName;
  final String phone;
  final Uint8List template;
  final String packageName;
  final String expiryDate;

  const _FingerprintMember({
    required this.memberId,
    required this.fullName,
    required this.phone,
    required this.template,
    required this.packageName,
    required this.expiryDate,
  });
}
