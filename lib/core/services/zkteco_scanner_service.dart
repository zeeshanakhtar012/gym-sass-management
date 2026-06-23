import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:developer';

import 'package:ffi/ffi.dart';

import '../constants/app_constants.dart';
import 'dartafis_service.dart';
import 'fingerprint_scanner_service.dart';

const int ZKFP_ERR_OK = 0;
const int ZKFP_ERR_CAPTURE = -8;

const int MAX_TEMPLATE_SIZE = 4096;
const int IMG_WIDTH = 300;
const int IMG_HEIGHT = 375;

const int PARAM_IMG_WIDTH = 1;
const int PARAM_IMG_HEIGHT = 2;

typedef ZKFPM_InitNative = Int32 Function();
typedef ZKFPM_InitDart = int Function();

typedef ZKFPM_TerminateNative = Int32 Function();
typedef ZKFPM_TerminateDart = int Function();

typedef ZKFPM_GetDeviceCountNative = Int32 Function();
typedef ZKFPM_GetDeviceCountDart = int Function();

typedef ZKFPM_OpenDeviceNative = Pointer<Void> Function(Int32);
typedef ZKFPM_OpenDeviceDart = Pointer<Void> Function(int);

typedef ZKFPM_CloseDeviceNative = Int32 Function(Pointer<Void>);
typedef ZKFPM_CloseDeviceDart = int Function(Pointer<Void>);

typedef ZKFPM_GetParametersNative = Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Pointer<Uint32>);
typedef ZKFPM_GetParametersDart = int Function(Pointer<Void>, int, Pointer<Uint8>, Pointer<Uint32>);

typedef ZKFPM_AcquireFingerprintNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32, Pointer<Uint8>, Pointer<Uint32>);
typedef ZKFPM_AcquireFingerprintDart = int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint32>);

typedef ZKFPM_AcquireFingerprintImageNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef ZKFPM_AcquireFingerprintImageDart = int Function(Pointer<Void>, Pointer<Uint8>, int);

typedef ZKFPM_ExtractFromImageNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32, Pointer<Uint8>, Pointer<Uint32>);
typedef ZKFPM_ExtractFromImageDart = int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, Pointer<Uint32>);

typedef ZKFPM_GenRegTemplateNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>);
typedef ZKFPM_GenRegTemplateDart = int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>);

typedef ZKFPM_DBInitNative = Pointer<Void> Function();
typedef ZKFPM_DBInitDart = Pointer<Void> Function();

typedef ZKFPM_CreateDBCacheNative = Pointer<Void> Function();
typedef ZKFPM_CreateDBCacheDart = Pointer<Void> Function();

typedef ZKFPM_CloseDBCacheNative = Int32 Function(Pointer<Void>);
typedef ZKFPM_CloseDBCacheDart = int Function(Pointer<Void>);

typedef ZKFPM_AddRegTemplateToDBCacheNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef ZKFPM_AddRegTemplateToDBCacheDart = int Function(Pointer<Void>, Pointer<Uint8>, int);

typedef ZKFPM_DBFreeNative = Int32 Function(Pointer<Void>);
typedef ZKFPM_DBFreeDart = int Function(Pointer<Void>);

typedef ZKFPM_DBAddNative = Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>);
typedef ZKFPM_DBAddDart = int Function(Pointer<Void>, int, Pointer<Uint8>);

typedef ZKFPM_DBClearNative = Int32 Function(Pointer<Void>);
typedef ZKFPM_DBClearDart = int Function(Pointer<Void>);

typedef ZKFPM_DBCountNative = Int32 Function(Pointer<Void>);
typedef ZKFPM_DBCountDart = int Function(Pointer<Void>);

typedef ZKFPM_DBIdentifyNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>);
typedef ZKFPM_DBIdentifyDart = int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>);

typedef ZKFPM_DBMatchNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>);
typedef ZKFPM_DBMatchDart = int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Int32>, Pointer<Int32>);

typedef ZKFPM_MatchFingerNative = Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>);
typedef ZKFPM_MatchFingerDart = int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>);

typedef BIOKEY_ExtractGrayScaleDataNative = Int32 Function(Pointer<Uint8>, Int32, Int32, Pointer<Uint8>, Pointer<Uint32>);
typedef BIOKEY_ExtractGrayScaleDataDart = int Function(Pointer<Uint8>, int, int, Pointer<Uint8>, Pointer<Uint32>);

typedef BIOKEY_VerifyNative = Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>);
typedef BIOKEY_VerifyDart = int Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Int32>);

int _trimTrailingZeros(Pointer<Uint8> buf, int declaredLen) {
  while (declaredLen > 0 && buf[declaredLen - 1] == 0) {
    declaredLen--;
  }
  return declaredLen;
}

Future<void> _initAndTestCapture(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final dllPath = args[1] as String;
  final lib = DynamicLibrary.open(dllPath);
  final init = lib.lookupFunction<ZKFPM_InitNative, ZKFPM_InitDart>('ZKFPM_Init');
  final getDeviceCount = lib.lookupFunction<ZKFPM_GetDeviceCountNative, ZKFPM_GetDeviceCountDart>('ZKFPM_GetDeviceCount');
  final openDevice = lib.lookupFunction<ZKFPM_OpenDeviceNative, ZKFPM_OpenDeviceDart>('ZKFPM_OpenDevice');
  final closeDevice = lib.lookupFunction<ZKFPM_CloseDeviceNative, ZKFPM_CloseDeviceDart>('ZKFPM_CloseDevice');
  final terminate = lib.lookupFunction<ZKFPM_TerminateNative, ZKFPM_TerminateDart>('ZKFPM_Terminate');
  final extractFromImage = lib.lookupFunction<ZKFPM_ExtractFromImageNative, ZKFPM_ExtractFromImageDart>('ZKFPM_ExtractFromImage');
  final acquireFP = lib.lookupFunction<ZKFPM_AcquireFingerprintNative, ZKFPM_AcquireFingerprintDart>('ZKFPM_AcquireFingerprint');

  DynamicLibrary? bioKeyLib;
  BIOKEY_ExtractGrayScaleDataDart? bioKeyExtract;
  try {
    bioKeyLib = DynamicLibrary.open('zkfpslibLow.dll');
    bioKeyExtract = bioKeyLib.lookupFunction<BIOKEY_ExtractGrayScaleDataNative, BIOKEY_ExtractGrayScaleDataDart>('BIOKEY_EXTRACT_GRAYSCALEDATA');
  } catch (_) {}

  if (init() != ZKFP_ERR_OK) { sendPort.send(null); return; }

  try {
    final count = getDeviceCount();
    if (count <= 0) { sendPort.send(null); return; }
    final dev = openDevice(0);
    if (dev == nullptr) { sendPort.send(null); return; }

    try {
      final imgSize = IMG_WIDTH * IMG_HEIGHT;
      final imgBuf = calloc<Uint8>(imgSize);
      final tmpBuf = calloc<Uint8>(MAX_TEMPLATE_SIZE);
      final tmpLen = calloc<Uint32>()..value = MAX_TEMPLATE_SIZE;

      try {
        for (int attempt = 0; attempt < AppConstants.fingerprintMaxScanAttempts; attempt++) {
          tmpLen.value = MAX_TEMPLATE_SIZE;
          int hr = acquireFP(dev, imgBuf, imgSize, tmpBuf, tmpLen);

          if (hr == ZKFP_ERR_OK) {
            final trimmedLen = _trimTrailingZeros(tmpBuf, tmpLen.value);
            if (trimmedLen > 0) {
              log('[ZKTeco] testCapture: SUCCESS on attempt ${attempt + 1}');
              final rawImage = Uint8List.fromList(imgBuf.asTypedList(imgSize));
              final mainResult = ZKFP_ERR_OK;
              final mainRawLen = tmpLen.value;
              final mainTrimmedLen = trimmedLen;
              final mainFirstBytes = trimmedLen > 0 ? Uint8List.fromList(tmpBuf.asTypedList(trimmedLen < 64 ? trimmedLen : 64)) : Uint8List(0);

              final results = <Map<String, dynamic>>[];

              if (bioKeyExtract != null) {
                final bkBuf = calloc<Uint8>(MAX_TEMPLATE_SIZE);
                final bkLen = calloc<Uint32>()..value = MAX_TEMPLATE_SIZE;
                final hr1 = bioKeyExtract(imgBuf, IMG_WIDTH, IMG_HEIGHT, bkBuf, bkLen);
                final rawLen1 = bkLen.value;
                final trimmed1 = hr1 == 0 ? _trimTrailingZeros(bkBuf, rawLen1) : 0;
                results.add({
                  'method': 'BIOKEY_EXTRACT_GRAYSCALEDATA',
                  'result': hr1,
                  'rawLen': rawLen1,
                  'trimmedLen': trimmed1,
                  'firstBytes': trimmed1 > 0 ? Uint8List.fromList(bkBuf.asTypedList(trimmed1 < 64 ? trimmed1 : 64)) : Uint8List(0),
                });
                log('[ZKTeco] testCapture: BioKey result=$hr1 rawLen=$rawLen1 trimmed=$trimmed1');
                calloc.free(bkBuf); calloc.free(bkLen);
              }

              final eiBuf = calloc<Uint8>(MAX_TEMPLATE_SIZE);
              final eiLen = calloc<Uint32>()..value = MAX_TEMPLATE_SIZE;
              final hr2 = extractFromImage(dev, imgBuf, imgSize, eiBuf, eiLen);
              final rawLen2 = eiLen.value;
              final trimmed2 = hr2 == ZKFP_ERR_OK ? _trimTrailingZeros(eiBuf, rawLen2) : 0;
              results.add({
                'method': 'ZKFPM_ExtractFromImage',
                'result': hr2,
                'rawLen': rawLen2,
                'trimmedLen': trimmed2,
                'firstBytes': trimmed2 > 0 ? Uint8List.fromList(eiBuf.asTypedList(trimmed2 < 64 ? trimmed2 : 64)) : Uint8List(0),
              });
              log('[ZKTeco] testCapture: ExtractFromImage result=$hr2 rawLen=$rawLen2 trimmed=$trimmed2');
              calloc.free(eiBuf); calloc.free(eiLen);

              results.add({
                'method': 'ZKFPM_AcquireFingerprint',
                'result': mainResult,
                'rawLen': mainRawLen,
                'trimmedLen': mainTrimmedLen,
                'firstBytes': mainFirstBytes,
              });

              sendPort.send({'rawImage': rawImage, 'results': results});
              return;
            }
            continue;
          }

          if (hr != ZKFP_ERR_CAPTURE) {
            log('[ZKTeco] testCapture: unexpected error $hr');
            sendPort.send(null);
            return;
          }

          await Future.delayed(const Duration(milliseconds: AppConstants.fingerprintScanRetryDelayMs));
        }
        log('[ZKTeco] testCapture: all ${AppConstants.fingerprintMaxScanAttempts} attempts returned CAPTURE');
        sendPort.send(null);
      } finally {
        calloc.free(imgBuf); calloc.free(tmpBuf); calloc.free(tmpLen);
      }
    } finally { closeDevice(dev); }
  } finally { terminate(); }
}

Future<void> _initAndTestMatch(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final dllPath = args[1] as String;
  final storedTemplates = (args[2] as List<dynamic>).cast<List<int>>();
  final lib = DynamicLibrary.open(dllPath);
  final init = lib.lookupFunction<ZKFPM_InitNative, ZKFPM_InitDart>('ZKFPM_Init');
  final getDeviceCount = lib.lookupFunction<ZKFPM_GetDeviceCountNative, ZKFPM_GetDeviceCountDart>('ZKFPM_GetDeviceCount');
  final openDevice = lib.lookupFunction<ZKFPM_OpenDeviceNative, ZKFPM_OpenDeviceDart>('ZKFPM_OpenDevice');
  final closeDevice = lib.lookupFunction<ZKFPM_CloseDeviceNative, ZKFPM_CloseDeviceDart>('ZKFPM_CloseDevice');
  final terminate = lib.lookupFunction<ZKFPM_TerminateNative, ZKFPM_TerminateDart>('ZKFPM_Terminate');
  final acquireFP = lib.lookupFunction<ZKFPM_AcquireFingerprintNative, ZKFPM_AcquireFingerprintDart>('ZKFPM_AcquireFingerprint');

  ZKFPM_MatchFingerDart? matchFinger;
  ZKFPM_DBInitDart? dbInit;
  ZKFPM_DBAddDart? dbAdd;
  ZKFPM_DBIdentifyDart? dbIdentify;
  ZKFPM_DBFreeDart? dbFree;
  try { matchFinger = lib.lookupFunction<ZKFPM_MatchFingerNative, ZKFPM_MatchFingerDart>('ZKFPM_MatchFinger'); } catch (_) {}
  try { dbInit = lib.lookupFunction<ZKFPM_DBInitNative, ZKFPM_DBInitDart>('ZKFPM_DBInit'); } catch (_) {}
  try { dbAdd = lib.lookupFunction<ZKFPM_DBAddNative, ZKFPM_DBAddDart>('ZKFPM_DBAdd'); } catch (_) {}
  try { dbIdentify = lib.lookupFunction<ZKFPM_DBIdentifyNative, ZKFPM_DBIdentifyDart>('ZKFPM_DBIdentify'); } catch (_) {}
  try { dbFree = lib.lookupFunction<ZKFPM_DBFreeNative, ZKFPM_DBFreeDart>('ZKFPM_DBFree'); } catch (_) {}

  if (init() != ZKFP_ERR_OK) { sendPort.send(null); return; }
  try {
    final count = getDeviceCount();
    if (count <= 0) { sendPort.send(null); return; }
    final dev = openDevice(0);
    if (dev == nullptr) { sendPort.send(null); return; }
    try {
      final imgSize = IMG_WIDTH * IMG_HEIGHT;
      final imgBuf = calloc<Uint8>(imgSize);
      final tmpBuf = calloc<Uint8>(MAX_TEMPLATE_SIZE);
      final tmpLen = calloc<Uint32>()..value = MAX_TEMPLATE_SIZE;
      try {
        for (int attempt = 0; attempt < AppConstants.fingerprintMaxScanAttempts; attempt++) {
          tmpLen.value = MAX_TEMPLATE_SIZE;
          final hr = acquireFP(dev, imgBuf, imgSize, tmpBuf, tmpLen);
          if (hr == ZKFP_ERR_OK && tmpLen.value > 0) {
            final capturedLen = _trimTrailingZeros(tmpBuf, tmpLen.value);
            if (capturedLen > 0) {
              log('[ZKTeco] testMatch: captured template len=$capturedLen on attempt ${attempt + 1}');
              final matchResults = <Map<String, dynamic>>[];

              Pointer<Void>? hDB;
              int dbIdResult = -999;
              int dbIdFid = -1;
              int dbIdScore = 0;

              if (dbInit != null && dbAdd != null && dbFree != null) {
                hDB = dbInit();
                for (int i = 0; i < storedTemplates.length; i++) {
                  final stored = calloc<Uint8>(storedTemplates[i].length);
                  stored.asTypedList(storedTemplates[i].length).setAll(0, storedTemplates[i]);
                  dbAdd(hDB, i, stored);
                  calloc.free(stored);
                }

                if (dbIdentify != null) {
                  final fidPtr = calloc<Int32>()..value = -1;
                  final scorePtr = calloc<Int32>()..value = 0;
                  dbIdResult = dbIdentify(hDB, tmpBuf, fidPtr, scorePtr);
                  dbIdFid = fidPtr.value;
                  dbIdScore = scorePtr.value;
                  log('[ZKTeco] testMatch: DBIdentify result=$dbIdResult fid=$dbIdFid score=$dbIdScore');
                  calloc.free(fidPtr);
                  calloc.free(scorePtr);
                }
              }

              for (int i = 0; i < storedTemplates.length; i++) {
                int mfScore = 0;

                if (matchFinger != null) {
                  final storedBuf = calloc<Uint8>(storedTemplates[i].length);
                  storedBuf.asTypedList(storedTemplates[i].length).setAll(0, storedTemplates[i]);
                  final scorePtr = calloc<Int32>()..value = 0;
                  matchFinger(dev, imgBuf, storedBuf, scorePtr);
                  mfScore = scorePtr.value;
                  log('[ZKTeco] testMatch: MatchFinger #$i score=$mfScore');
                  calloc.free(storedBuf);
                  calloc.free(scorePtr);
                }

                matchResults.add({
                  'templateIndex': i,
                  'matchFingerScore': mfScore,
                  'dbIdentify': dbIdResult,
                  'dbIdentifyFid': dbIdFid,
                  'dbIdentifyScore': dbIdScore,
                });
              }

              if (hDB != null && dbFree != null) dbFree(hDB);

              sendPort.send({'matchResults': matchResults});
              return;
            }
            continue;
          }
          if (hr != ZKFP_ERR_CAPTURE) { sendPort.send(null); return; }
          await Future.delayed(const Duration(milliseconds: AppConstants.fingerprintScanRetryDelayMs));
        }
        sendPort.send(null);
      } finally {
        calloc.free(imgBuf); calloc.free(tmpBuf); calloc.free(tmpLen);
      }
    } finally { closeDevice(dev); }
  } finally { terminate(); }
}

Future<void> _initAndCapture(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final dllPath = args[1] as String;
  final lib = DynamicLibrary.open(dllPath);
  final init = lib.lookupFunction<ZKFPM_InitNative, ZKFPM_InitDart>('ZKFPM_Init');
  final getDeviceCount = lib.lookupFunction<ZKFPM_GetDeviceCountNative, ZKFPM_GetDeviceCountDart>('ZKFPM_GetDeviceCount');
  final openDevice = lib.lookupFunction<ZKFPM_OpenDeviceNative, ZKFPM_OpenDeviceDart>('ZKFPM_OpenDevice');
  final closeDevice = lib.lookupFunction<ZKFPM_CloseDeviceNative, ZKFPM_CloseDeviceDart>('ZKFPM_CloseDevice');
  final terminate = lib.lookupFunction<ZKFPM_TerminateNative, ZKFPM_TerminateDart>('ZKFPM_Terminate');
  final acquireFP = lib.lookupFunction<ZKFPM_AcquireFingerprintNative, ZKFPM_AcquireFingerprintDart>('ZKFPM_AcquireFingerprint');

  log('[ZKTeco] _initAndCapture: DLL opened');

  if (init() != ZKFP_ERR_OK) {
    log('[ZKTeco] _initAndCapture: init failed');
    sendPort.send(null);
    return;
  }

  try {
    final count = getDeviceCount();
    log('[ZKTeco] _initAndCapture: deviceCount=$count');
    if (count <= 0) { sendPort.send(null); return; }
    final dev = openDevice(0);
    if (dev == nullptr) { sendPort.send(null); return; }

    try {
      final imgSize = IMG_WIDTH * IMG_HEIGHT;
      final imgBuf = calloc<Uint8>(imgSize);
      final tmpBuf = calloc<Uint8>(MAX_TEMPLATE_SIZE);
      final tmpLen = calloc<Uint32>()..value = MAX_TEMPLATE_SIZE;

      try {
        for (int attempt = 0; attempt < AppConstants.fingerprintMaxScanAttempts; attempt++) {
          tmpLen.value = MAX_TEMPLATE_SIZE;
          final hr = acquireFP(dev, imgBuf, imgSize, tmpBuf, tmpLen);

          if (hr == ZKFP_ERR_OK && tmpLen.value > 0) {
            final actualLen = _trimTrailingZeros(tmpBuf, tmpLen.value);
            if (actualLen > 0) {
              log('[ZKTeco] _initAndCapture: captured template len=$actualLen '
                  'on attempt ${attempt + 1}');
              final rawList = imgBuf.asTypedList(imgSize).toList();
              final tmpList = tmpBuf.asTypedList(actualLen).toList();
              sendPort.send({
                'rawImage': rawList,
                'template': tmpList,
              });
              return;
            }
            continue;
          }

          if (hr != ZKFP_ERR_CAPTURE) {
            log('[ZKTeco] _initAndCapture: unexpected error $hr');
            sendPort.send(null);
            return;
          }

          await Future.delayed(const Duration(milliseconds: AppConstants.fingerprintScanRetryDelayMs));
        }
        log('[ZKTeco] _initAndCapture: all ${AppConstants.fingerprintMaxScanAttempts} '
            'attempts returned CAPTURE');
        sendPort.send(null);
      } finally {
        calloc.free(imgBuf); calloc.free(tmpBuf); calloc.free(tmpLen);
      }
    } finally { closeDevice(dev); }
  } finally { terminate(); }
}

Future<void> _initAndIdentify(List<dynamic> args) async {
  final dllPath = args[0] as String;
  final templateArgs = (args[1] as List<dynamic>).cast<List<int>>();
  final sendPort = args[2] as SendPort;
  final threshold = args[3] as int;

  final lib = DynamicLibrary.open(dllPath);
  final init = lib.lookupFunction<ZKFPM_InitNative, ZKFPM_InitDart>('ZKFPM_Init');
  final getDeviceCount = lib.lookupFunction<ZKFPM_GetDeviceCountNative, ZKFPM_GetDeviceCountDart>('ZKFPM_GetDeviceCount');
  final openDevice = lib.lookupFunction<ZKFPM_OpenDeviceNative, ZKFPM_OpenDeviceDart>('ZKFPM_OpenDevice');
  final closeDevice = lib.lookupFunction<ZKFPM_CloseDeviceNative, ZKFPM_CloseDeviceDart>('ZKFPM_CloseDevice');
  final terminate = lib.lookupFunction<ZKFPM_TerminateNative, ZKFPM_TerminateDart>('ZKFPM_Terminate');
  final acquireFP = lib.lookupFunction<ZKFPM_AcquireFingerprintNative, ZKFPM_AcquireFingerprintDart>('ZKFPM_AcquireFingerprint');

  ZKFPM_MatchFingerDart? matchFinger;
  ZKFPM_DBInitDart? dbInit;
  ZKFPM_DBAddDart? dbAdd;
  ZKFPM_DBIdentifyDart? dbIdentify;
  ZKFPM_DBFreeDart? dbFree;
  try { matchFinger = lib.lookupFunction<ZKFPM_MatchFingerNative, ZKFPM_MatchFingerDart>('ZKFPM_MatchFinger'); } catch (_) {}
  try { dbInit = lib.lookupFunction<ZKFPM_DBInitNative, ZKFPM_DBInitDart>('ZKFPM_DBInit'); } catch (_) {}
  try { dbAdd = lib.lookupFunction<ZKFPM_DBAddNative, ZKFPM_DBAddDart>('ZKFPM_DBAdd'); } catch (_) {}
  try { dbIdentify = lib.lookupFunction<ZKFPM_DBIdentifyNative, ZKFPM_DBIdentifyDart>('ZKFPM_DBIdentify'); } catch (_) {}
  try { dbFree = lib.lookupFunction<ZKFPM_DBFreeNative, ZKFPM_DBFreeDart>('ZKFPM_DBFree'); } catch (_) {}

  if (init() != ZKFP_ERR_OK) {
    log('[ZKTeco] _initAndIdentify: init failed');
    sendPort.send(null);
    return;
  }

  try {
    final count = getDeviceCount();
    if (count <= 0) {
      log('[ZKTeco] _initAndIdentify: no devices found');
      sendPort.send(null);
      return;
    }
    final dev = openDevice(0);
    if (dev == nullptr) {
      log('[ZKTeco] _initAndIdentify: openDevice failed');
      sendPort.send(null);
      return;
    }

    try {
      final imgSize = IMG_WIDTH * IMG_HEIGHT;
      final imgBuf = calloc<Uint8>(imgSize);
      final tmpBuf = calloc<Uint8>(MAX_TEMPLATE_SIZE);
      final tmpLen = calloc<Uint32>()..value = MAX_TEMPLATE_SIZE;
      final scorePtr = calloc<Int32>()..value = 0;

      try {
        const maxAttempts = 300;
        log('[ZKTeco] identify: waiting for finger (up to ${maxAttempts ~/ 5}s)...');

        for (int attempt = 0; attempt < maxAttempts; attempt++) {
          tmpLen.value = MAX_TEMPLATE_SIZE;
          int hr = acquireFP(dev, imgBuf, imgSize, tmpBuf, tmpLen);

          if (hr == ZKFP_ERR_OK && tmpLen.value > 0) {
            final capturedLen = _trimTrailingZeros(tmpBuf, tmpLen.value);
            if (capturedLen > 0) {
              log('[ZKTeco] Scan received: finger detected');
              log('[ZKTeco] Template generated: ${capturedLen} bytes from captured fingerprint');

              if (templateArgs.isEmpty) {
                log('[ZKTeco] No stored templates to match against');
                await Future.delayed(const Duration(milliseconds: 200));
                continue;
              }

              Pointer<Void>? hDB;
              if (dbInit != null && dbAdd != null && dbFree != null) {
                hDB = dbInit();
                for (int i = 0; i < templateArgs.length; i++) {
                  final stored = calloc<Uint8>(templateArgs[i].length);
                  stored.asTypedList(templateArgs[i].length).setAll(0, templateArgs[i]);
                  dbAdd(hDB, i, stored);
                  calloc.free(stored);
                }
                log('[ZKTeco] Loaded ${templateArgs.length} templates into SDK DB');
              }

              int bestIndex = -1;
              int bestScore = 0;

              if (matchFinger != null) {
                log('[ZKTeco] Trying MatchFinger (image comparison)...');
                for (int i = 0; i < templateArgs.length; i++) {
                  final storedLen = templateArgs[i].length;
                  final storedBuf = calloc<Uint8>(storedLen);
                  storedBuf.asTypedList(storedLen).setAll(0, templateArgs[i]);
                  scorePtr.value = 0;
                  final mr = matchFinger(dev, imgBuf, storedBuf, scorePtr);
                  calloc.free(storedBuf);
                  log('[ZKTeco] MatchFinger #$i: result=$mr score=${scorePtr.value}');
                  if (mr == ZKFP_ERR_OK && scorePtr.value > bestScore) {
                    bestIndex = i;
                    bestScore = scorePtr.value;
                  }
                }
                if (bestIndex >= 0) {
                  log('[ZKTeco] Match score: $bestScore for template #$bestIndex (MatchFinger)');
                } else {
                  log('[ZKTeco] MatchFinger: no match found');
                }
              }

              if (bestIndex < 0 && hDB != null && dbIdentify != null) {
                log('[ZKTeco] Trying DBIdentify (1:N)...');
                final fidPtr = calloc<Int32>()..value = -1;
                scorePtr.value = 0;
                final idr = dbIdentify(hDB, tmpBuf, fidPtr, scorePtr);
                if (idr == ZKFP_ERR_OK && fidPtr.value >= 0 && scorePtr.value > 0) {
                  bestIndex = fidPtr.value;
                  bestScore = scorePtr.value;
                  log('[ZKTeco] Match score: $bestScore for template #$bestIndex (DBIdentify)');
                } else {
                  log('[ZKTeco] DBIdentify: no match (result=$idr, fid=${fidPtr.value}, score=${scorePtr.value})');
                }
                calloc.free(fidPtr);
              }

              if (hDB != null && dbFree != null) {
                dbFree(hDB);
                log('[ZKTeco] Freed SDK DB');
              }

              if (bestIndex >= 0 && bestScore >= threshold) {
                log('[ZKTeco] User matched: template #$bestIndex with score $bestScore (threshold=$threshold)');
                sendPort.send({'index': bestIndex, 'score': bestScore});
                return;
              }

              log('[ZKTeco] Verification failed: best score $bestScore below threshold $threshold for all ${templateArgs.length} templates');
              await Future.delayed(const Duration(milliseconds: 200));
              continue;
            }
            continue;
          }

          if (hr != ZKFP_ERR_CAPTURE) {
            log('[ZKTeco] identify: unexpected error $hr');
            sendPort.send(null);
            return;
          }
          await Future.delayed(const Duration(milliseconds: 200));
        }
        log('[ZKTeco] identify: all $maxAttempts attempts exhausted, no match found');
        sendPort.send(null);
      } finally {
        calloc.free(imgBuf); calloc.free(tmpBuf); calloc.free(tmpLen);
        calloc.free(scorePtr);
      }
    } finally { closeDevice(dev); }
  } finally { terminate(); }
}

/// ZKTeco-based biometric service implementation.
///
/// Enrollment captures a fingerprint via the ZK SDK and returns both the
/// raw image and the ZK template. The caller is responsible for extracting
/// a dartafis template from the raw image via [DartafisService] and storing
/// only the serialised template bytes.
///
/// Identification uses the dartafis matcher against pre-serialised templates
/// stored in the database – no raw images are compared.
class ZKTecoBiometricService implements FingerprintScannerService {
  final String _dllPath;
  final _dartafisService = DartafisService();
  List<Uint8List> _templates = [];
  Isolate? _identifyIsolate;

  ZKTecoBiometricService({String dllPath = 'libzkfp.dll'}) : _dllPath = dllPath;

  @override
  Future<bool> isScannerConnected() async {
    try {
      final lib = DynamicLibrary.open(_dllPath);
      final init = lib.lookupFunction<ZKFPM_InitNative, ZKFPM_InitDart>('ZKFPM_Init');
      final getDeviceCount = lib.lookupFunction<ZKFPM_GetDeviceCountNative, ZKFPM_GetDeviceCountDart>('ZKFPM_GetDeviceCount');
      final openDevice = lib.lookupFunction<ZKFPM_OpenDeviceNative, ZKFPM_OpenDeviceDart>('ZKFPM_OpenDevice');
      final closeDevice = lib.lookupFunction<ZKFPM_CloseDeviceNative, ZKFPM_CloseDeviceDart>('ZKFPM_CloseDevice');
      final terminate = lib.lookupFunction<ZKFPM_TerminateNative, ZKFPM_TerminateDart>('ZKFPM_Terminate');

      if (init() != ZKFP_ERR_OK) {
        log('[ZKTeco] isScannerConnected: init failed');
        return false;
      }
      final count = getDeviceCount();
      if (count <= 0) {
        terminate();
        log('[ZKTeco] isScannerConnected: deviceCount=$count');
        return false;
      }
      final dev = openDevice(0);
      final connected = dev != nullptr;
      if (connected) closeDevice(dev);
      terminate();
      log('[ZKTeco] isScannerConnected: count=$count opened=${dev != nullptr}');
      return connected;
    } catch (e) {
      log('[ZKTeco] isScannerConnected error: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> enrollFingerprint() async {
    log('[ZKTeco] enrollFingerprint called');
    try {
      final rp = ReceivePort();
      await Isolate.spawn(_initAndCapture, [rp.sendPort, _dllPath]);
      final result = await rp.first;
      rp.close();
      if (result is Map<String, dynamic>) {
        final template = result['template'] as List<int>?;
        if (template != null && template.isNotEmpty) {
          log('[ZKTeco] enroll success, templateLen=${template.length}');
          return result;
        }
      }
      log('[ZKTeco] enroll failed');
      return null;
    } catch (e) {
      log('[ZKTeco] enroll error: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> captureRawImage() async {
    log('[ZKTeco] captureRawImage called');
    try {
      final rp = ReceivePort();
      await Isolate.spawn(_initAndCapture, [rp.sendPort, _dllPath]);
      final result = await rp.first;
      rp.close();
      if (result is Map<String, dynamic>) {
        final rawImage = result['rawImage'] as List<int>?;
        if (rawImage != null && rawImage.length == IMG_WIDTH * IMG_HEIGHT) {
          log('[ZKTeco] captureRawImage success, len=${rawImage.length}');
          return Uint8List.fromList(rawImage);
        }
      }
      log('[ZKTeco] captureRawImage failed');
      return null;
    } catch (e) {
      log('[ZKTeco] captureRawImage error: $e');
      return null;
    }
  }

  @override
  Future<FingerprintMatchResult?> identifyByDartafis({
    required List<Uint8List> candidateTemplates,
    double scoreThreshold = AppConstants.fingerprintMatchThreshold,
  }) async {
    log('[ZKTeco] identifyByDartafis called with '
        '${candidateTemplates.length} candidate templates, '
        'threshold=$scoreThreshold');
    try {
      final rawImage = await captureRawImage();
      if (rawImage == null) {
        log('[ZKTeco] identifyByDartafis: capture failed');
        return null;
      }

      log('[ZKTeco] identifyByDartafis: extracting probe and matching...');
      final best = await _dartafisService.identify(
        rawImage,
        candidateTemplates,
        threshold: scoreThreshold,
      );

      if (best == null) {
        log('[ZKTeco] identifyByDartafis: no match above threshold=$scoreThreshold');
        return null;
      }

      log('[ZKTeco] identifyByDartafis: best match index=${best.index} '
          'score=${best.score.toStringAsFixed(1)}');
      return FingerprintMatchResult(
        templateIndex: best.index,
        score: best.score,
        threshold: scoreThreshold,
      );
    } catch (e) {
      log('[ZKTeco] identifyByDartafis error: $e');
      return null;
    }
  }

  @override
  void loadTemplates(List<Uint8List> templates) {
    _templates = templates;
    log('[ZKTeco] loaded ${templates.length} templates for ZK SDK matching');
  }

  @override
  Future<FingerprintMatchResult?> identifyFingerprint({int threshold = 40}) async {
    log('[ZKTeco] identifyFingerprint called (threshold=$threshold)');
    if (_templates.isEmpty) {
      log('[ZKTeco] identifyFingerprint: no templates loaded');
      return null;
    }

    final templateArgs = _templates.map((t) => t.toList()).toList();
    log('[ZKTeco] identifyFingerprint: ${templateArgs.length} templates available');

    try {
      final rp = ReceivePort();
      _identifyIsolate = await Isolate.spawn(
        _initAndIdentify,
        [_dllPath, templateArgs, rp.sendPort, threshold],
      );
      final result = await rp.first;
      rp.close();
      _identifyIsolate = null;

      if (result is Map<String, dynamic>) {
        final index = result['index'] as int;
        final score = result['score'] as int;
        log('[ZKTeco] identify success: index=$index, score=$score (threshold=$threshold)');
        return FingerprintMatchResult(
          templateIndex: index,
          score: score.toDouble(),
          threshold: threshold.toDouble(),
        );
      }

      log('[ZKTeco] identifyFingerprint: no match found');
      return null;
    } catch (e) {
      log('[ZKTeco] identifyFingerprint error: $e');
      return null;
    }
  }

  @override
  Future<void> disconnect() async {
    log('[ZKTeco] disconnect called');
    _templates = [];
    _identifyIsolate?.kill(priority: Isolate.immediate);
    _identifyIsolate = null;
  }

  /// Capture and run ZK SDK template extraction diagnostics.
  Future<Map<String, dynamic>?> testCapture() async {
    log('[ZKTeco] testCapture called');
    try {
      final rp = ReceivePort();
      await Isolate.spawn(_initAndTestCapture, [rp.sendPort, _dllPath]);
      final result = await rp.first.timeout(
        const Duration(seconds: 30),
        onTimeout: () => null,
      );
      rp.close();
      if (result is Map<String, dynamic>) {
        final rawImg = result['rawImage'];
        final len = (rawImg is Uint8List) ? rawImg.length : ((rawImg is List<int>) ? rawImg.length : 0);
        log('[ZKTeco] testCapture success, imageBytes=$len');
        return result;
      }
      log('[ZKTeco] testCapture failed');
      return null;
    } catch (e) {
      log('[ZKTeco] testCapture error: $e');
      return null;
    }
  }

  /// Capture and run ZK SDK matching diagnostics.
  Future<Map<String, dynamic>?> testMatch(List<Uint8List> storedTemplates) async {
    log('[ZKTeco] testMatch called with ${storedTemplates.length} templates');
    try {
      final templateArgs = storedTemplates.map((t) => t.toList()).toList();
      final rp = ReceivePort();
      await Isolate.spawn(_initAndTestMatch, [rp.sendPort, _dllPath, templateArgs]);
      final result = await rp.first;
      rp.close();
      if (result is Map<String, dynamic>) {
        log('[ZKTeco] testMatch success');
        return result;
      }
      log('[ZKTeco] testMatch failed');
      return null;
    } catch (e) {
      log('[ZKTeco] testMatch error: $e');
      return null;
    }
  }
}
