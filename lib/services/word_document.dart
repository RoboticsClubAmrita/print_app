/// Turns a Word document into printable PDF pages, on the device.
///
/// A .docx is a zip of OOXML; `word/document.xml` holds the body. This reads
/// that directly — paragraphs, headings, bold/italic runs, lists, tables and
/// explicit page breaks — and lays it out on A4 here.
///
/// It is a re-layout, not a rendering of Word's own pagination. Word decides
/// where pages break using the installed fonts, the printer driver and layout
/// rules the file does not carry, so its page count is not knowable from the
/// document alone. What is produced here *is* the document: it gets previewed,
/// counted, priced and printed, so those four can never disagree — which is
/// the whole point.
///
/// What is deliberately not reproduced: exact fonts and sizes, colours,
/// images, headers/footers, columns, text boxes, and Word's own page breaks.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

/// A Word document could not be read, or had nothing to print.
class WordDocumentException implements Exception {
  final String message;
  WordDocumentException(this.message);
  @override
  String toString() => message;
}

enum _BlockKind { paragraph, heading, bullet, tableRow }

class _Run {
  final String text;
  final bool bold;
  final bool italic;
  const _Run(this.text, {this.bold = false, this.italic = false});
}

class _Block {
  final _BlockKind kind;
  final List<_Run> runs;
  final int level;
  final List<String> cells;
  final bool breakBefore;
  const _Block({
    required this.kind,
    this.runs = const [],
    this.level = 0,
    this.cells = const [],
    this.breakBefore = false,
  });
}

Iterable<XmlElement> _named(XmlElement parent, String name) =>
    parent.childElements.where((e) => e.name.local == name);

XmlElement? _first(XmlElement? parent, String name) {
  if (parent == null) return null;
  final matches = _named(parent, name);
  return matches.isEmpty ? null : matches.first;
}

/// OOXML marks a property on by presence; `w:val="0"`/`"false"` turns it off.
bool _isOn(XmlElement? props, String name) {
  final el = _first(props, name);
  if (el == null) return false;
  final val = el.getAttribute('w:val');
  return val != '0' && val != 'false';
}

({List<_Run> runs, bool breakBefore}) _readRuns(XmlElement paragraph) {
  final runs = <_Run>[];
  var breakBefore = false;

  for (final run in _named(paragraph, 'r')) {
    final props = _first(run, 'rPr');
    final bold = _isOn(props, 'b');
    final italic = _isOn(props, 'i');

    for (final child in run.childElements) {
      switch (child.name.local) {
        case 't':
          runs.add(_Run(child.innerText, bold: bold, italic: italic));
        case 'tab':
          runs.add(_Run('    ', bold: bold, italic: italic));
        case 'br':
          // A page break belongs to the paragraph; a plain break is space.
          if (child.getAttribute('w:type') == 'page') {
            breakBefore = true;
          } else {
            runs.add(_Run(' ', bold: bold, italic: italic));
          }
      }
    }
  }

  return (runs: runs, breakBefore: breakBefore);
}

_Block? _readParagraph(XmlElement paragraph) {
  final props = _first(paragraph, 'pPr');
  final style = (_first(props, 'pStyle')?.getAttribute('w:val') ?? '').toLowerCase();
  final numbered = _first(props, 'numPr') != null;

  final read = _readRuns(paragraph);
  final text = read.runs.map((r) => r.text).join().trim();
  if (text.isEmpty && !read.breakBefore) return null;

  var kind = _BlockKind.paragraph;
  var level = 0;
  final heading = RegExp(r'^heading(\d)$').firstMatch(style);
  if (style == 'title') {
    kind = _BlockKind.heading;
    level = 1;
  } else if (heading != null) {
    kind = _BlockKind.heading;
    level = int.parse(heading.group(1)!).clamp(1, 3);
  } else if (numbered || style.contains('listparagraph')) {
    kind = _BlockKind.bullet;
  }

  return _Block(kind: kind, runs: read.runs, level: level, breakBefore: read.breakBefore);
}

List<_Block> _readTable(XmlElement table) {
  final rows = <_Block>[];
  for (final row in _named(table, 'tr')) {
    final cells = _named(row, 'tc')
        .map((cell) => _named(cell, 'p')
            .map((p) => _readRuns(p).runs.map((r) => r.text).join())
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim())
        .toList();
    if (cells.any((c) => c.isNotEmpty)) {
      rows.add(_Block(kind: _BlockKind.tableRow, cells: cells));
    }
  }
  return rows;
}

List<_Block> _readBlocks(Uint8List bytes, String fileName) {
  // A .docx is a zip archive. Without this check a text file renamed to .docx
  // reaches the unzipper and fails with something unreadable, instead of the
  // user being told their file is not a Word document.
  if (bytes.length < 4 ||
      bytes[0] != 0x50 || bytes[1] != 0x4b || bytes[2] != 0x03 || bytes[3] != 0x04) {
    throw WordDocumentException(
      '$fileName is not a readable .docx document. If it was saved in the older .doc '
      'format, open it and use "Save As" to write a .docx — or export it as a PDF.',
    );
  }

  ArchiveFile? entry;
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') entry = file;
    }
  } catch (_) {
    throw WordDocumentException(
      '$fileName could not be read. If it is password-protected, remove the password '
      'and try again.',
    );
  }

  if (entry == null) {
    throw WordDocumentException(
      '$fileName does not contain a Word document body. If it is password-protected, '
      'remove the password and try again.',
    );
  }

  XmlDocument parsed;
  try {
    // Decoded as UTF-8: OOXML is UTF-8 and treating the bytes as code units
    // would mangle every accented or non-Latin character in the document.
    parsed = XmlDocument.parse(
      utf8.decode(entry.content as List<int>, allowMalformed: true),
    );
  } catch (_) {
    throw WordDocumentException('$fileName could not be read — its contents are damaged.');
  }

  // Matched on the local name: the body is `w:body`, and findAllElements
  // compares qualified names, so it would not find it.
  final body = _first(parsed.rootElement, 'body') ?? parsed.rootElement;
  final blocks = <_Block>[];
  for (final child in body.childElements) {
    if (child.name.local == 'p') {
      final block = _readParagraph(child);
      if (block != null) blocks.add(block);
    } else if (child.name.local == 'tbl') {
      blocks.addAll(_readTable(child));
    }
  }

  if (blocks.isEmpty) {
    throw WordDocumentException('$fileName has no text in it — there would be nothing to print.');
  }
  return blocks;
}

pw.TextStyle _styleFor(_Block block, _Run run) {
  final size = switch (block.kind) {
    _BlockKind.heading => switch (block.level) { 1 => 17.0, 2 => 14.0, _ => 12.0 },
    _ => 11.0,
  };
  return pw.TextStyle(
    fontSize: size,
    fontWeight:
        run.bold || block.kind == _BlockKind.heading ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: run.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
  );
}

/// Renders [bytes] as a PDF and returns the document.
Future<Uint8List> wordDocumentToPdf({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blocks = _readBlocks(bytes, fileName);
  final doc = pw.Document();

  // A hard page break starts a new MultiPage; everything between two breaks
  // flows naturally across as many pages as it needs.
  final sections = <List<_Block>>[[]];
  for (final block in blocks) {
    if (block.breakBefore && sections.last.isNotEmpty) sections.add([]);
    sections.last.add(block);
  }

  for (final section in sections.where((s) => s.isNotEmpty)) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56),
        build: (context) => section.map<pw.Widget>((block) {
          if (block.kind == _BlockKind.tableRow) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: block.cells
                    .map((cell) => pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ))
                    .toList(),
              ),
            );
          }

          final text = pw.RichText(
            text: pw.TextSpan(
              children: block.runs
                  .map((run) => pw.TextSpan(text: run.text, style: _styleFor(block, run)))
                  .toList(),
            ),
          );

          return pw.Padding(
            padding: pw.EdgeInsets.only(
              left: block.kind == _BlockKind.bullet ? 18 : 0,
              top: block.kind == _BlockKind.heading ? 8 : 0,
              bottom: 6,
            ),
            child: block.kind == _BlockKind.bullet
                ? pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 6),
                        child: pw.Text('•', style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Expanded(child: text),
                    ],
                  )
                : text,
          );
        }).toList(),
      ),
    );
  }

  return Uint8List.fromList(await doc.save());
}
