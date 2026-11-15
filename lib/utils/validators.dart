/// Shared client-side validators mirroring the backend's signup rules, so the
/// same checks run in Sign Up and Edit Profile.
class Validators {
  static final _emailFormat = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmailFormat(String email) =>
      _emailFormat.hasMatch(email.trim());

  /// A student mailbox (…@*.students.amrita.edu). Staff must not sign up with
  /// one — students register with their roll number instead.
  static bool isStudentEmail(String email) {
    final at = email.trim().toLowerCase().lastIndexOf('@');
    if (at < 0) return false;
    final domain = email.trim().toLowerCase().substring(at + 1);
    return domain == 'students.amrita.edu' ||
        domain.endsWith('.students.amrita.edu');
  }

  /// Amrita institutional email: any address on the amrita.edu domain or one
  /// of its subdomains (e.g. cb.students.amrita.edu).
  static bool isAmritaEmail(String email) {
    final e = email.trim().toLowerCase();
    if (!_emailFormat.hasMatch(e)) return false;
    final domain = e.split('@').last;
    return domain == 'amrita.edu' || domain.endsWith('.amrita.edu');
  }

  /// Minimum password rule the app enforces client-side (the backend applies
  /// the authoritative policy). Returns an error string, or null when valid.
  static String? passwordIssue(String password) {
    if (password.length < 4) return 'Password must be at least 4 characters';
    return null;
  }

  /// Basic phone check — 10 to 15 digits after stripping non-digits.
  static bool isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 15;
  }
}
