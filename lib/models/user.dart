class AppUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final num balance;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.balance = 0,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
