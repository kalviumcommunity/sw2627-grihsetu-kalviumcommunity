class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final RegExp _phone = RegExp(r'^[6-9]\d{9}$');

  static String? notEmpty(String? value, String field) =>
      value == null || value.trim().isEmpty ? '$field is required' : null;

  static String? name(String? value) {
    final error = notEmpty(value, 'Name');
    if (error != null) return error;
    return value!.trim().length < 2 ? 'Enter your full name' : null;
  }

  static String? email(String? value) {
    final error = notEmpty(value, 'Email');
    if (error != null) return error;
    return _email.hasMatch(value!.trim())
        ? null
        : 'Enter a valid email address';
  }

  static String? phone(String? value) {
    final error = notEmpty(value, 'Phone number');
    if (error != null) return error;
    return _phone.hasMatch(value!.trim())
        ? null
        : 'Enter a valid 10-digit mobile number';
  }

  static String? password(String? value) {
    final error = notEmpty(value, 'Password');
    if (error != null) return error;
    if (value!.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final error = notEmpty(value, 'Please confirm your password');
    if (error != null) return error;
    return value == original ? null : 'Passwords do not match';
  }
}
