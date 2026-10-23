class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final RegExp _phone = RegExp(r'^[6-9]\d{9}$');

  /// Validates that a string is not null, not empty, and not whitespace-only.
  /// Supports optional length limits and custom error messages.
  static String? requiredText(
    String? value, {
    String field = 'This field',
    String? message,
    int? minLength,
    int? maxLength,
    String? minLengthError,
    String? maxLengthError,
  }) {
    if (value == null || value.trim().isEmpty) {
      return message ?? '$field is required';
    }
    final trimmed = value.trim();
    if (minLength != null && trimmed.length < minLength) {
      return minLengthError ?? '$field must be at least $minLength characters';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return maxLengthError ?? '$field must be $maxLength characters or fewer';
    }
    return null;
  }

  /// Validates an optional text field. If present and non-empty, rejects
  /// whitespace-only input and enforces optional length constraints.
  static String? optionalText(
    String? value, {
    String field = 'This field',
    int? minLength,
    int? maxLength,
    String? whitespaceError,
    String? minLengthError,
    String? maxLengthError,
  }) {
    if (value == null || value.isEmpty) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return whitespaceError ?? '$field cannot contain only whitespace';
    }
    if (minLength != null && trimmed.length < minLength) {
      return minLengthError ?? '$field must be at least $minLength characters';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return maxLengthError ?? '$field cannot exceed $maxLength characters';
    }
    return null;
  }

  /// Backward-compatible alias for [requiredText] with standard message.
  static String? notEmpty(String? value, String field) =>
      requiredText(value, field: field);

  /// Validates a parsed numeric amount ([num]), checking presence,
  /// finite/non-NaN values, and optional [min] and [max] bounds.
  static String? amountValue(
    num? amount, {
    String field = 'Amount',
    bool isRequired = true,
    num? min,
    num? max,
    String? requiredError,
    String? minError,
    String? maxError,
    String? malformedError,
  }) {
    if (amount == null) {
      return isRequired ? (requiredError ?? '$field is required') : null;
    }
    if (amount.isNaN || amount.isInfinite) {
      return malformedError ?? '$field must be a valid number';
    }
    if (min != null && amount < min) {
      return minError ?? '$field must be at least $min';
    }
    if (max != null && amount > max) {
      return maxError ?? '$field cannot exceed $max';
    }
    return null;
  }

  /// Parses and validates a numeric string (suitable for [TextFormField] validators).
  static String? amount(
    String? value, {
    String field = 'Amount',
    bool isRequired = true,
    num? min,
    num? max,
    String? requiredError,
    String? minError,
    String? maxError,
    String? malformedError,
  }) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? (requiredError ?? '$field is required') : null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return malformedError ?? 'Enter a valid amount';
    }
    return amountValue(
      parsed,
      field: field,
      isRequired: isRequired,
      min: min,
      max: max,
      requiredError: requiredError,
      minError: minError,
      maxError: maxError,
      malformedError: malformedError,
    );
  }

  /// Safely parses a double from a string, returning `null` if invalid, NaN, or infinite.
  static double? tryParseAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return parsed;
  }

  /// Normalizes a date to calendar midnight (year, month, day).
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Validates a [DateTime] value with customizable constraints:
  /// - [isRequired]: if false, `null` is accepted as valid.
  /// - [allowPast]: if false, dates before [now] are rejected.
  /// - [allowToday]: if false (when [allowPast] is false), dates on today are also rejected.
  /// - [now]: reference timestamp for deterministic testing.
  /// - [minDate]: minimum allowed calendar date.
  /// - [maxDate]: maximum allowed calendar date.
  /// - [maxDaysAhead]: maximum allowed days ahead from [now].
  static String? date(
    DateTime? value, {
    String field = 'Date',
    bool isRequired = true,
    DateTime? now,
    bool allowPast = false,
    bool allowToday = true,
    DateTime? minDate,
    DateTime? maxDate,
    int? maxDaysAhead,
    String? requiredError,
    String? pastError,
    String? minDateError,
    String? maxDateError,
  }) {
    if (value == null) {
      return isRequired ? (requiredError ?? '$field is required') : null;
    }

    final target = dateOnly(value);
    final ref = dateOnly(now ?? DateTime.now());

    if (!allowPast) {
      if (allowToday) {
        if (target.isBefore(ref)) {
          return pastError ?? '$field cannot be in the past';
        }
      } else {
        if (!target.isAfter(ref)) {
          return pastError ?? '$field must be after today';
        }
      }
    }

    if (minDate != null) {
      final min = dateOnly(minDate);
      if (target.isBefore(min)) {
        return minDateError ??
            '$field cannot be before ${min.day}/${min.month}/${min.year}';
      }
    }

    final effectiveMax = maxDate != null
        ? dateOnly(maxDate)
        : (maxDaysAhead != null ? ref.add(Duration(days: maxDaysAhead)) : null);

    if (effectiveMax != null) {
      if (target.isAfter(effectiveMax)) {
        return maxDateError ??
            (maxDaysAhead != null
                ? '$field cannot be more than $maxDaysAhead days ahead'
                : '$field cannot be after ${effectiveMax.day}/${effectiveMax.month}/${effectiveMax.year}');
      }
    }

    return null;
  }

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
