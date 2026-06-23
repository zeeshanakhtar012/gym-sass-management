# Fingerprint Integration Summary (ZKTeco SDK via FFI)

## Overview

Replaced the Windows Biometric Framework (`winbio.dll`) approach with the **ZKTeco ZKFinger SDK** (`libzkfp.dll`) for real fingerprint scanner support. The WBF approach failed because the ZKTeco USB device lacks a WBDI driver. The ZKTeco SDK works natively with all ZKTeco fingerprint scanners.

---

## Files Created

### `lib/core/services/zkteco_scanner_service.dart` (New)

Full Dart FFI binding to `libzkfp.dll` implementing `FingerprintScannerService`.

**FFI function bindings (14 functions):**

| Function | Purpose |
|---|---|
| `ZKFPM_Init` | Initialize SDK |
| `ZKFPM_Terminate` | Release SDK |
| `ZKFPM_GetDeviceCount` | Detect connected scanners |
| `ZKFPM_OpenDevice` | Open scanner by index |
| `ZKFPM_CloseDevice` | Close scanner |
| `ZKFPM_GetParameters` | Get image dimensions |
| `ZKFPM_AcquireFingerprint` | Capture fingerprint (image + template) |
| `ZKFPM_DBInit` | Create in-memory fingerprint DB |
| `ZKFPM_DBFree` | Free in-memory DB |
| `ZKFPM_DBAdd` | Add template to DB (by FID) |
| `ZKFPM_DBClear` | Clear all templates from DB |
| `ZKFPM_DBCount` | Count templates in DB |
| `ZKFPM_DBIdentify` | 1:N identification (returns FID + score) |
| `ZKFPM_DBMatch` | 1:1 template comparison |

**Architecture:**
- All blocking FFI calls run in **background isolates** via `Isolate.spawn` + `SendPort`
- `_enrollIsolateMain`: init → open device → get params → acquire → return template bytes
- `_identifyIsolateMain`: init → dbInit → add templates → open device → acquire → dbIdentify → return FID
- 60-second timeout on all isolate calls
- Main class `ZKTecoBiometricService` manages state and mapping between FID and stored templates

**Enrollment flow (single-scan):**
1. Spawn isolate → init SDK → open device → `AcquireFingerprint` → return template bytes
2. Template bytes stored in `fingerprint_template` column in SQLite

**Identification flow:**
1. Controller calls `loadTemplates(List<Uint8List> templates)` to register enrolled templates
2. Spawn isolate → init SDK → load all templates into in-memory DB → open device → `AcquireFingerprint` → `DBIdentify` → return matched FID
3. Service maps FID back to stored template bytes and returns them
4. Controller does byte comparison against its own member list to find the matched member

---

## Files Modified

### `lib/core/services/fingerprint_scanner_service.dart`

Added `loadTemplates(List<Uint8List> templates)` to the abstract interface — required for the SDK-based identification approach where templates must be loaded into the SDK's internal DB before matching.

```dart
abstract class FingerprintScannerService {
  Future<bool> isScannerConnected();
  Future<List<int>?> enrollFingerprint();
  Future<bool> verifyFingerprint(List<int> identity);
  Future<List<int>?> identifyFingerprint();
  void loadTemplates(List<Uint8List> templates);
  Future<void> disconnect();
}
```

### `lib/modules/members/controllers/member_form_controller.dart`

- Changed import: `windows_biometric_service.dart` → `zkteco_scanner_service.dart`
- Changed instance: `WindowsBiometricService()` → `ZKTecoBiometricService()`
- No logic changes — enrollment flow is identical (single-scan capture)

### `lib/modules/kiosk/controllers/kiosk_controller.dart`

- Changed import and instance type
- Added `_scanner.loadTemplates(fpTemplates)` call in `_initScanner()` — loads all enrolled member templates into the SDK before starting the continuous scan loop
- The byte-comparison logic in `_runScanLoop` stays the same because `identifyFingerprint()` returns the **stored template** of the matched member

### `lib/modules/attendance/controllers/attendance_controller.dart`

- Changed import and instance type
- Moved `getFingerprintMembers()` call before the identify call
- Added `_scanner.loadTemplates(fpTemplates)` — loads templates before scanning

### `lib/modules/attendance/screens/fingerprint_attendance_view.dart`

- Changed import and instance type
- Added `_loadTemplates()` method — queries DB for all members with fingerprints and loads them into the service
- Called before starting the scan loop

---

## Files Deleted

### `lib/core/services/windows_biometric_service.dart`

The old WBF (`winbio.dll`) implementation is no longer needed. It couldn't detect the ZKTeco device because it lacks a WBDI driver. All consumers now use `ZKTecoBiometricService`.

---

## SDK DLLs Being Used

All located in `C:\Windows\System32\`:

| DLL | Size | Purpose |
|---|---|---|
| `libzkfp.dll` | 277 KB | **Main SDK** — exports all `ZKFPM_*` functions |
| `zkfpslibLow.dll` | 113 KB | Algorithm library (loaded internally by `libzkfp.dll`) |
| `ZKFPCap.dll` | 97 KB | Capture library (loaded internally) |
| `libzkfpcsharp.dll` | 13 KB | C# bridge (not used by Dart FFI) |

---

## Build Status

```
flutter analyze → 0 errors, 99 warnings/info (pre-existing)
```

---

## Next Steps (Testing)

1. **Run the app** — enroll a member's fingerprint from the member form
2. **Test kiosk mode** — open kiosk to test continuous fingerprint check-in
3. **Test dedicated FP screen** — use the "FP Attendance" navigation entry
4. **If `libzkfp.dll` fails to load at runtime**, try loading from the full path:
   - `ZKTecoBiometricService(dllPath: r'C:\Windows\System32\libzkfp.dll')`
