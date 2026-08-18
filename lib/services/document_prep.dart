/// What happens to a document on the device before the backend sees any of it.
///
/// The phone is the only place the document exists until the order is paid
/// for, so the app owns three jobs the server used to do:
///
///   * conversion — whatever was picked becomes one PDF (merged by
///     pdf_combiner in the picker flow), and that PDF is what gets previewed,
///     counted, priced and printed;
///   * page detection — counted off the real PDF here, and allowed to fail
///     loudly rather than fall back to a guess that would then be billed;
///   * hashing — a sha256 quoted at registration and re-checked by the backend
///     when the bytes finally go up, so the printed document is provably the
///     one that was priced.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:printing/printing.dart';


/// Extensions the picker offers.
///
/// Word/PowerPoint/Excel are deliberately absent: converting them faithfully
/// on a phone isn't something we can do, and an approximate conversion means
/// the printout doesn't match the preview and the page count is wrong. Users
/// export to PDF first and get an exact preview and price.
const kPrintableExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// Formats we recognise but can't convert here, mapped to what to call them.
const _convertYourself = <String, String>{
  'doc': 'Word',
  'docx': 'Word',
  'ppt': 'PowerPoint',
  'pptx': 'PowerPoint',
  'xls': 'Excel',
  'xlsx': 'Excel',
  'txt': 'text',
  'rtf': 'rich text',
  'odt': 'OpenDocument',
};

/// A document could not be prepared for printing.
class DocumentPrepException implements Exception {
  final String message;
  DocumentPrepException(this.message);
  @override
  String toString() => message;
}

/// A PDF's page count could not be determined. Never swallowed — the count is
/// what the user is charged for.
class PageDetectionException implements Exception {
  final String message;
  PageDetectionException([this.message = 'page detection failed']);
  @override
  String toString() => message;
}

String extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
}

bool isPrintable(String fileName) => kPrintableExtensions.contains(extensionOf(fileName));

/// The message to show for a file we cannot turn into a PDF on the device.
String unsupportedFileMessage(String fileName) {
  final label = _convertYourself[extensionOf(fileName)];
  return label != null
      ? '$fileName is a $label document. Save it as a PDF first — that way the preview, '
          'the page count and the printout all match exactly.'
      : '$fileName is not a supported file type. Choose a PDF, JPG or PNG.';
}

/// Throws if any picked file can't become a PDF here. Called before merging so
/// the user is told what to do rather than watching the merge fail.
void assertAllPrintable(Iterable<String> fileNames) {
  for (final name in fileNames) {
    if (!isPrintable(name)) throw DocumentPrepException(unsupportedFileMessage(name));
  }
}

/// Lowercase hex sha256 — the same digest the backend recomputes on upload.
String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

/// Exact page count for a PDF, read by rasterising it.
///
/// Rendering runs at 1 dpi: we want the number of pages, not the pixels, so
/// each page costs almost nothing. This goes through the platform's own PDF
/// engine, which handles compressed cross-reference streams and the other
/// structures a hand-rolled parser gets wrong.
///
/// Throws [PageDetectionException] rather than returning a fallback: a
/// wrong-but-plausible page count gets billed, an honest failure does not.
Future<int> countPdfPages(Uint8List bytes) async {
  int pages;
  try {
    pages = await Printing.raster(bytes, dpi: 1).length;
  } catch (error) {
    throw PageDetectionException('page detection failed ($error)');
  }

  if (pages <= 0) {
    throw PageDetectionException('page detection failed — the document reported no pages');
  }
  return pages;
}

/// The single PDF an order is placed against.
class PreparedDocument {
  final Uint8List bytes;
  final String fileName;
  final int totalPages;

  /// Lowercase hex sha256 of [bytes].
  final String checksum;

  const PreparedDocument({
    required this.bytes,
    required this.fileName,
    required this.totalPages,
    required this.checksum,
  });

  int get sizeKb => (bytes.length / 1024).ceil();
}

/// Counts and fingerprints the merged PDF, producing what the order is placed
/// against. Fails if the bytes aren't a readable PDF.
Future<PreparedDocument> describeDocument({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (bytes.length < 5 ||
      bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
    // %PDF — the merge produced something that isn't a PDF at all.
    throw DocumentPrepException('The prepared document is not a valid PDF.');
  }

  final totalPages = await countPdfPages(bytes);

  return PreparedDocument(
    bytes: bytes,
    fileName: fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf',
    totalPages: totalPages,
    checksum: sha256Hex(bytes),
  );
}
