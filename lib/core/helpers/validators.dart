class Validators {
  Validators._();

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? cnic(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');
    if (!cnicRegex.hasMatch(value.trim())) {
      return 'Enter valid CNIC format (XXXXX-XXXXXXX-X)';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Value']) {
    if (value == null || value.trim().isEmpty) return null;
    final num? parsed = num.tryParse(value);
    if (parsed == null || parsed < 0) {
      return '$field must be a positive number';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String field = 'Password']) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }
}
