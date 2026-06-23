class AppConstants {
  AppConstants._();

  static const String appName = 'Gym ERP';
  static const String appVersion = '1.0.0';
  static const String dbName = 'gym_erp.db';
  static const int dbVersion = 6;

  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'admin123';

  static const int pageSize = 20;
  static const int kioskAutoDismissMs = 4000;
  static const int expiryWarningDays = 7;
  static const int maintenanceWarningDays = 7;
  static const double kioskMinBodyFont = 18.0;
  static const double kioskNameFont = 28.0;

  static const List<String> expenseCategories = [
    'Electricity',
    'Water',
    'Rent',
    'Salaries',
    'Internet',
    'Repairs',
    'Miscellaneous',
  ];

  static const List<String> paymentMethods = [
    'Cash',
    'Bank Transfer',
    'EasyPaisa',
    'JazzCash',
  ];

  static const List<String> equipmentConditions = [
    'New',
    'Good',
    'Fair',
    'Needs Repair',
  ];

  static const List<String> equipmentStatuses = [
    'In Use',
    'Under Maintenance',
    'Retired',
  ];

  static const List<String> genders = ['Male', 'Female', 'Other'];

  static const List<String> fitnessGoals = [
    'Weight Loss',
    'Weight Gain',
    'Muscle Building',
    'General Fitness',
    'Rehabilitation',
  ];

  static const String backupDirName = 'Backups';
  static const int maxBackupCopies = 10;

  // === Fingerprint / Biometric Configuration ===
  /// Minimum matching score for dartafis-based fingerprint identification.
  /// Scores below this are rejected as "Unknown User".
  /// Recommended range: 25-50 (higher = stricter).
  static const double fingerprintMatchThreshold = 20.0;

  /// Verification threshold used when checking if a newly enrolled fingerprint
  /// already exists in the database (template deduplication).
  static const double fingerprintEnrollDedupeThreshold = 40.0;

  /// Maximum number of scan attempts before giving up.
  static const int fingerprintMaxScanAttempts = 150;

  /// Delay (ms) between scan retry attempts.
  static const int fingerprintScanRetryDelayMs = 200;

  /// The width/height of the raw fingerprint image from the ZK9500 scanner.
  static const int fingerprintImageWidth = 300;
  static const int fingerprintImageHeight = 375;
  static const int fingerprintImageSize = 300 * 375; // 112500
}
