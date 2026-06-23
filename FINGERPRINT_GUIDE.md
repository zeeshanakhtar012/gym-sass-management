# Fingerprint System Guide

## Overview

This gym management app uses the **ZK9500 optical fingerprint scanner** for both **enrollment** (registering a member's fingerprint) and **attendance** (identifying a member by their fingerprint at check-in).

### Key Architecture

```
┌──────────────────┐     ZK SDK (libzkfp.dll)     ┌──────────────────┐
│  ZK9500 Scanner  │◄────────────────────────────►│ _initAndCapture  │
│  (USB/FFI)       │     AcquireFingerprint()     │   (isolate)      │
└──────────────────┘                               └────────┬─────────┘
                                                            │
                                          sends {rawImage, template}
                                                            │
                                                            ▼
┌──────────────────┐                              ┌──────────────────┐
│  dartafis (pure  │◄──── raw image ──────────────│  Main Isolate    │
│  Dart, no DLL)   │     featureExtract + match    │                  │
└──────────────────┘                              └──────────────────┘
```

## Two Separate Systems

### 1. Capture — ZK SDK (`libzkfp.dll`)
- **Works**: `ZKFPM_AcquireFingerprint()` captures fingerprint image (300×375 grayscale, 112500 bytes) + ZK template
- Used in `_initAndCapture` isolate (`zkteco_scanner_service.dart:334`)
- Returns `{'rawImage': [...], 'template': [...]}`

### 2. Matching — dartafis (pure Dart)
- **Replaces**: All ZK SDK matching (`MatchFinger`, `DBIdentify`, `DBMatch`, DBCache) — all broken on ZK9500
- **Library**: `dartafis: ^0.1.0` (Dart port of SourceAFIS)
- **Works on**: Raw 300×375 grayscale image bytes (no DLL needed)
- **No matching engine in `libzkfp.dll`** — the SDK on this device only does capture

## Workflow

### Enrollment (Register Fingerprint)
1. Member form UI calls `enrollFingerprint()` in `ZKTecoBiometricService`
2. Spawns `_initAndCapture` isolate → captures raw image + ZK template via `ZKFPM_AcquireFingerprint`
3. Returns `Map{'rawImage': List<int>, 'template': List<int>}` to the controller
4. Controller stores:
   - `fingerprint_template` (BLOB) — ZK template (kept for backward compat)
   - `fingerprint_image` (BLOB) — raw 300×375 grayscale image (used for dartafis matching)

### Attendance (Fingerprint Check-in)
1. App loads members with `fingerprint_image IS NOT NULL`
2. Calls `identifyByDartafis(candidateRawImages, scoreThreshold: 20.0)`
3. Internally:
   - `captureRawImage()` spawns `_initAndCapture` → gets raw image from scanner
   - `DartafisService.findBestMatch(probeRawImage, candidateRawImages)`:
     - Extracts `SearchTemplate` from probe image via `featureExtract()`
     - For each candidate image, extracts template and matches via `SearchMatcher`
     - Returns `(index, score)` of best match above threshold
4. Attendance is recorded for the matched member

## Database Schema

`members` table — fingerprint columns:

| Column | Type | Purpose |
|--------|------|---------|
| `fingerprint_template` | BLOB | ZK SDK template (legacy, ~500 bytes) |
| `fingerprint_image` | BLOB (added v5) | Raw 300×375 grayscale image (112500 bytes) |

## Threshold Tuning

- dartafis scores are typically **0–100** (not 0–1000 like ZK SDK)
- Good matches: **20–50+**
- Bad/random matches: **<10**
- Default threshold: **20.0** (adjustable via `scoreThreshold` parameter)
- If too many false matches: **raise** to 30–40
- If too many false rejections: **lower** to 10–15

## Key Files

| File | Purpose |
|------|---------|
| `lib/core/services/zkteco_scanner_service.dart` | ZK SDK FFI + dartafis integration |
| `lib/core/services/fingerprint_scanner_service.dart` | Abstract interface |
| `lib/core/services/dartafis_service.dart` | dartafis extract/match/serialize |
| `lib/modules/members/controllers/member_form_controller.dart` | Enrollment flow |
| `lib/modules/attendance/screens/fingerprint_attendance_view.dart` | Kiosk-style attendance |
| `lib/modules/attendance/controllers/attendance_controller.dart` | Manual attendance |
| `lib/modules/kiosk/controllers/kiosk_controller.dart` | Kiosk mode attendance |
| `lib/core/database/database_helper.dart` | DB migrations (v5 added `fingerprint_image`) |

## Troubleshooting

**Scanner not detected:**
- Check USB connection
- Ensure `libzkfp.dll` is in the working directory or PATH
- Run as administrator

**Enrollment fails:**
- Confirm scanner LED is on
- `_initAndCapture` logs will show capture errors
- Raw image should be exactly 112500 bytes

**No match found (dartafis returns null):**
- Check that member's `fingerprint_image` is not null in DB
- Try lowering `scoreThreshold` (e.g., 10.0)
- Verify same finger was used for enrollment and matching
- dartafis extracts ~20–80 minutiae; poor quality images yield fewer features

**Build errors after changes:**
- Run `flutter pub get`
- Run `flutter analyze` to check for errors
