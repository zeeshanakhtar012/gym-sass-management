import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/dartafis_service.dart';
import '../../../core/services/zkteco_scanner_service.dart';
import '../../../core/constants/app_constants.dart';

class FingerprintTestController extends GetxController {
  final ZKTecoBiometricService _scanner = ZKTecoBiometricService();
  final DartafisService _dartafis = DartafisService();

  final connected = false.obs;
  final isCapturing = false.obs;
  final rawImageBytes = Rxn<Uint8List>();
  final testResults = <Map<String, dynamic>>[].obs;
  final logs = <String>[].obs;

  void _log(String msg) {
    log('[FingerprintTest] $msg');
    logs.add(msg);
  }

  Future<void> checkConnection() async {
    _log('Checking connection...');
    final ok = await _scanner.isScannerConnected();
    connected.value = ok;
    _log(ok ? 'Device connected' : 'Device NOT connected');
  }

  Future<void> capture() async {
    isCapturing.value = true;
    rawImageBytes.value = null;
    testResults.clear();
    _log('Starting capture...');

    final result = await _scanner.testCapture();

    if (result == null) {
      _log('Capture returned null (no image captured in 30 attempts)');
      isCapturing.value = false;
      return;
    }

    final img = result['rawImage'];
    final rawImg = (img is Uint8List) ? img : (img is List<int> ? Uint8List.fromList(img) : null);
    final results = result['results'] as List<dynamic>?;

    if (rawImg != null && rawImg.length == AppConstants.fingerprintImageSize) {
      rawImageBytes.value = rawImg;
      _log('Raw image captured: ${rawImg.length} bytes '
          '(${AppConstants.fingerprintImageWidth}x${AppConstants.fingerprintImageHeight} grayscale)');

      // Also extract dartafis template for diagnostics
      final tpl = await _dartafis.extractAndSerialize(rawImg);
      final valid = _dartafis.isValidTemplate(tpl);
      _log('Dartafis template: ${tpl.length} bytes, valid=$valid');
    } else {
      _log('Raw image: ${rawImg?.length ?? 0} bytes '
          '(expected ${AppConstants.fingerprintImageSize})');
    }

    if (results != null) {
      for (final r in results) {
        final method = r['method'] as String;
        final res = r['result'] as int;
        final rawLen = r['rawLen'] as int;
        final trimmedLen = r['trimmedLen'] as int;
        final fb = r['firstBytes'];
        final firstBytes = (fb is Uint8List) ? fb.toList() : ((fb is List<int>) ? fb : <int>[]);

        final hexPreview = firstBytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        _log('[$method] result=$res rawLen=$rawLen trimmedLen=$trimmedLen');
        if (trimmedLen > 0) {
          _log('[$method] first 16 bytes: $hexPreview');
          _log('[$method] full hex: ${firstBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        }
        testResults.add(r);
      }
    }

    _log('Capture complete');
    isCapturing.value = false;
  }

  Future<void> saveTemplateFromResult(int resultIndex) async {
    if (resultIndex < 0 || resultIndex >= testResults.length) return;
    final r = testResults[resultIndex];
    final trimmedLen = r['trimmedLen'] as int;
    final fb = r['firstBytes'];
    final firstBytes = (fb is Uint8List) ? fb.toList() : ((fb is List<int>) ? fb : <int>[]);
    if (trimmedLen == 0) {
      _log('Cannot save - template is empty');
      Get.snackbar('Error', 'Template is empty, nothing to save');
      return;
    }
    _log('Save template: method=${r['method']} len=$trimmedLen');
    Get.snackbar('Template Data',
      'Method: ${r['method']}\n'
      'Result: ${r['result']}\n'
      'RawLen: ${r['rawLen']}\n'
      'TrimmedLen: $trimmedLen\n'
      'First 16: ${firstBytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      backgroundColor: Colors.blueGrey, colorText: Colors.white, duration: const Duration(seconds: 6),
    );
  }

  /// Test ZK SDK template-based matching (diagnostic only – ZK matching is
  /// broken on ZK9500).
  Future<void> testMatching() async {
    _log('=== ZK SDK MATCH TEST ===');
    isCapturing.value = true;
    testResults.clear();

    // Load stored ZK templates from DB
    List<Uint8List> storedTemplates = [];
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('members',
        where: 'fingerprint_template IS NOT NULL AND fingerprint_template != ?',
        whereArgs: [''],
      );
      for (final row in rows) {
        final t = row['fingerprint_template'];
        if (t is Uint8List && t.isNotEmpty) {
          storedTemplates.add(t);
          final name = row['full_name'] ?? 'unknown';
          _log('Stored ZK template: $name len=${t.length}');
        }
      }
      _log('Loaded ${storedTemplates.length} stored ZK templates');
    } catch (e) {
      _log('DB error: $e');
    }

    // Also load dartafis templates
    List<Uint8List> dartafisTemplates = [];
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('members',
        where: 'fingerprint_data IS NOT NULL',
      );
      for (final row in rows) {
        final t = row['fingerprint_data'];
        if (t is Uint8List && t.isNotEmpty) {
          dartafisTemplates.add(t);
          final name = row['full_name'] ?? 'unknown';
          _log('Stored dartafis template: $name len=${t.length}');
        }
      }
      _log('Loaded ${dartafisTemplates.length} dartafis templates');
    } catch (e) {
      _log('DB error for dartafis templates: $e');
    }

    if (storedTemplates.isEmpty) {
      _log('No stored ZK templates found');
    }

    // ZK SDK matching test
    if (storedTemplates.isNotEmpty) {
      final result = await _scanner.testMatch(storedTemplates);

      if (result == null) {
        _log('ZK testMatch returned null');
      } else {
        final matchResults = result['matchResults'] as List<dynamic>?;
        if (matchResults != null) {
          for (final mr in matchResults) {
            final templateIndex = mr['templateIndex'] as int;
            final matchFingerScore = mr['matchFingerScore'] as int? ?? 0;
            final dbIdentify = mr['dbIdentify'] as int;
            final dbIdentifyFid = mr['dbIdentifyFid'] as int;
            final dbIdentifyScore = mr['dbIdentifyScore'] as int;
            final cacheMatch = mr['cacheMatch'] as int?;
            final cacheMatchScore = mr['cacheMatchScore'] as int?;
            _log('ZK Match[$templateIndex]:');
            _log('  MatchFinger(template) score=$matchFingerScore');
            _log('  DBIdentify=$dbIdentify fid=$dbIdentifyFid score=$dbIdentifyScore');
            if (cacheMatch != null) {
              _log('  DBCache=$cacheMatch score=$cacheMatchScore');
            }
          }

          int bestIndex = -1;
          int bestScore = 0;
          for (final mr in matchResults) {
            final mfScore = mr['matchFingerScore'] as int? ?? 0;
            final dbIdScore = mr['dbIdentifyScore'] as int;
            final cacheScore = mr['cacheMatchScore'] as int? ?? 0;
            final maxScore = [mfScore, dbIdScore, cacheScore].reduce((a, b) => a > b ? a : b);
            if (maxScore > bestScore) {
              bestScore = maxScore;
              bestIndex = mr['templateIndex'] as int;
            }
          }

          if (bestIndex >= 0 && bestScore >= 40) {
            _log('ZK MATCHED at index $bestIndex score=$bestScore');
            try {
              final db = await DatabaseHelper.instance.database;
              final rows = await db.query('members',
                where: 'fingerprint_template IS NOT NULL',
              );
              if (bestIndex < rows.length) {
                final member = rows[bestIndex];
                _log('>>> ZK USER: ${member['full_name']} (${member['phone']})');
                Get.snackbar('ZK Match Found',
                  'User: ${member['full_name']}\nScore: $bestScore',
                  backgroundColor: Colors.green, colorText: Colors.white,
                  duration: const Duration(seconds: 10));
              }
            } catch (e) {
              _log('DB lookup error: $e');
            }
          } else {
            _log('No ZK match - best score $bestScore');
          }
        }
      }
    }

    // Dartafis template matching test
    if (dartafisTemplates.isNotEmpty && rawImageBytes.value != null) {
      _log('=== DARTAFIS TEMPLATE MATCH TEST ===');
      try {
        final best = await _dartafis.identify(
          rawImageBytes.value!,
          dartafisTemplates,
          threshold: AppConstants.fingerprintMatchThreshold,
        );
        if (best != null) {
          _log('Dartafis matched index=${best.index} '
              'score=${best.score.toStringAsFixed(1)}');
          try {
            final db = await DatabaseHelper.instance.database;
            final rows = await db.query('members',
              where: 'fingerprint_data IS NOT NULL',
            );
            if (best.index < rows.length) {
              final member = rows[best.index];
              _log('>>> DARTAFIS USER: ${member['full_name']}');
              Get.snackbar('Dartafis Match',
                'User: ${member['full_name']}\nScore: ${best.score.toStringAsFixed(1)}',
                backgroundColor: Colors.green, colorText: Colors.white,
                duration: const Duration(seconds: 10));
            }
          } catch (e) {
            _log('DB lookup error: $e');
          }
        } else {
          _log('Dartafis: no match above threshold');
          Get.snackbar('No Dartafis Match',
            'Fingerprint not recognized',
            backgroundColor: Colors.red, colorText: Colors.white);
        }
      } catch (e) {
        _log('Dartafis match error: $e');
      }
    }

    _log('=== MATCH TEST DONE ===');
    isCapturing.value = false;
  }

  /// Identify a fingerprint using dartafis template matching (production path).
  Future<void> identify() async {
    _log('=== DARTAFIS IDENTIFY ===');
    isCapturing.value = true;

    // Load dartafis templates from DB
    List<Map<String, dynamic>> fpMembers = [];
    try {
      final db = await DatabaseHelper.instance.database;
      fpMembers = await db.query('members',
        where: 'fingerprint_data IS NOT NULL',
        orderBy: 'full_name ASC',
      );
      _log('Loaded ${fpMembers.length} members with dartafis templates');
    } catch (e) {
      _log('DB error: $e');
      isCapturing.value = false;
      return;
    }

    if (fpMembers.isEmpty) {
      _log('No dartafis templates in DB, trying legacy fingerprint_image...');
      try {
        final db = await DatabaseHelper.instance.database;
        fpMembers = await db.query('members',
          where: 'fingerprint_image IS NOT NULL',
          orderBy: 'full_name ASC',
        );
        _log('Loaded ${fpMembers.length} members with legacy images');

        // Migrate on-the-fly
        for (final row in fpMembers) {
          final img = row['fingerprint_image'] as Uint8List?;
          if (img != null && img.length == AppConstants.fingerprintImageSize) {
            final serialized = await _dartafis.migrateLegacyImage(img);
            if (serialized != null) {
              await db.update(
                'members',
                {'fingerprint_data': serialized},
                where: 'member_id = ?',
                whereArgs: [row['member_id']],
              );
              row['fingerprint_data'] = serialized;
              _log('Migrated ${row['full_name']}');
            }
          }
        }
      } catch (e) {
        _log('DB error on legacy: $e');
      }
    }

    if (fpMembers.isEmpty) {
      _log('No members with fingerprint data in DB');
      Get.snackbar('No Data', 'No fingerprint members registered',
        backgroundColor: Colors.orange, colorText: Colors.white);
      isCapturing.value = false;
      return;
    }

    final templates = fpMembers
        .map((m) => m['fingerprint_data'] as Uint8List)
        .toList();
    _scanner.loadTemplates(templates);

    _log('Place your finger on the scanner...');
    final matchResult = await _scanner.identifyByDartafis(
      candidateTemplates: templates,
      scoreThreshold: AppConstants.fingerprintMatchThreshold,
    );

    if (matchResult == null || !matchResult.isMatched) {
      _log('No match found (threshold=${AppConstants.fingerprintMatchThreshold})');
      Get.snackbar('No Match', 'Fingerprint not recognized. Try again.',
        backgroundColor: Colors.red, colorText: Colors.white,
        duration: const Duration(seconds: 5));
      isCapturing.value = false;
      return;
    }

    if (matchResult.templateIndex < 0 || matchResult.templateIndex >= fpMembers.length) {
      _log('Match index ${matchResult.templateIndex} out of range');
      Get.snackbar('Error', 'Invalid match result',
        backgroundColor: Colors.red, colorText: Colors.white);
      isCapturing.value = false;
      return;
    }

    final member = fpMembers[matchResult.templateIndex];
    final name = member['full_name'] as String? ?? 'Unknown';
    final phone = member['phone'] as String? ?? '';
    _log('>>> MATCHED: $name '
        '(index=${matchResult.templateIndex}, '
        'score=${matchResult.score.toStringAsFixed(1)}, '
        'threshold=${AppConstants.fingerprintMatchThreshold})');
    Get.snackbar('MATCH FOUND',
      'User: $name\nPhone: $phone\nScore: ${matchResult.score.toStringAsFixed(1)}',
      backgroundColor: Colors.green, colorText: Colors.white,
      duration: const Duration(seconds: 15));
    isCapturing.value = false;
  }
}
