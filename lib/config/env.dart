import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads the backend base URL from `.env` (see .env at the project root).
/// Swap between local/server backends there — only one line should be
/// uncommented at a time.
class Env {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api';
}
