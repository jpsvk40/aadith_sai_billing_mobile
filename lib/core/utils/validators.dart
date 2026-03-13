class Validators {
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final regex = RegExp(r'^[0-9]{10}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static String? positiveNumber(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) return '${fieldName ?? 'Value'} is required';
    final num = double.tryParse(value.trim());
    if (num == null) return 'Enter a valid number';
    if (num <= 0) return '${fieldName ?? 'Value'} must be greater than 0';
    return null;
  }
}
