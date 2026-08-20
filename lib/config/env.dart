import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads the backend base URL from `.env` (see .env at the project root).
/// Swap between local/server backends there — only one line should be
/// uncommented at a time.
class Env {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api';

  /// Largest upload the backend will accept, in megabytes.
  ///
  /// The server is the real authority here (`MAX_UPLOAD_MB` in the backend's
  /// .env, enforced by multer and the body parser). This mirrors it only so an
  /// oversized document is caught before we spend time merging and uploading
  /// bytes the server is guaranteed to reject. Keep the two values in step.
  static int get maxUploadMb =>
      int.tryParse(dotenv.env['MAX_UPLOAD_MB'] ?? '') ?? 50;

  static int get maxUploadBytes => maxUploadMb * 1024 * 1024;
}
