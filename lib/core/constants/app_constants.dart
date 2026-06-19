class AppConstants {
  AppConstants._();

  static const String appName = 'Gym ERP';
  static const String appVersion = '1.0.0';
  static const String dbName = 'gym_erp.db';
  static const int dbVersion = 3;

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
}
