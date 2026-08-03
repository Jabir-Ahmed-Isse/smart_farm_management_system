import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/journey_event.dart';

/// PDF + text export for a crop journey. Kept dependency-light: reuses the
/// `pdf` + `file_saver` packages already in the app (see report_export.dart).
class CropJourneyExport {
  static final _date = DateFormat('MMM d, yyyy');

  static String _stem(CropJourney j) =>
      'crop-journey-${j.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

  /// Builds and saves a one-file PDF of the whole journey.
  static Future<void> savePdf(CropJourney j) async {
    final doc = pw.Document();
    const green = PdfColor.fromInt(0xFF0D631B);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 130,
                child: pw.Text(k,
                    style: const pw.TextStyle(
                        color: PdfColors.grey700, fontSize: 10))),
            pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('Crop Journey — ${j.name}',
              style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: green)),
        ),
        pw.SizedBox(height: 8),
        if (j.variety != null) kv('Variety', j.variety!),
        if (j.plotName != null)
          kv('Plot', '${j.plotName}${j.isGreenhouse ? ' (Greenhouse)' : ''}'),
        kv('Stage', j.stage),
        if (j.plantingDate != null) kv('Planted', _date.format(j.plantingDate!)),
        if (j.expectedHarvest != null)
          kv('Est. harvest', _date.format(j.expectedHarvest!)),
        kv('Health score', '${j.healthScore}/100 (${j.healthLabel})'),
        pw.Divider(),
        pw.Text('Financial summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 4),
        kv('Total expenses', '\$${j.totalExpenses.toStringAsFixed(2)}'),
        kv('Total revenue', '\$${j.totalRevenue.toStringAsFixed(2)}'),
        kv('Net profit', '\$${j.netProfit.toStringAsFixed(2)}'),
        pw.Divider(),
        pw.Text('AI season summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text(j.aiSummary, style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(),
        pw.Text('Timeline (${j.events.length} events)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 6),
        for (final e in j.events)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(e.title,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(_date.format(e.date),
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                if (e.description != null && e.description!.isNotEmpty)
                  pw.Text(e.description!,
                      style: const pw.TextStyle(fontSize: 9)),
                for (final d in e.details)
                  pw.Text('${d.$1}: ${d.$2}',
                      style: const pw.TextStyle(fontSize: 9)),
                if (e.cost != null)
                  pw.Text('Cost: \$${e.cost!.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
      ],
    ));

    final bytes = await doc.save();
    await FileSaver.instance.saveFile(
      name: _stem(j),
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  /// Saves a plain-text timeline — the "Share" fallback until a native share
  /// sheet is wired in.
  static Future<void> saveText(CropJourney j) async {
    final b = StringBuffer()
      ..writeln('CROP JOURNEY — ${j.name}')
      ..writeln('Health: ${j.healthScore}/100 (${j.healthLabel})')
      ..writeln('Net profit: \$${j.netProfit.toStringAsFixed(2)}')
      ..writeln('')
      ..writeln(j.aiSummary)
      ..writeln('')
      ..writeln('TIMELINE');
    for (final e in j.events) {
      b.writeln('- ${_date.format(e.date)}  ${e.title}');
      for (final d in e.details) {
        b.writeln('    ${d.$1}: ${d.$2}');
      }
    }
    final bytes = Uint8List.fromList(utf8.encode(b.toString()));
    await FileSaver.instance.saveFile(
      name: _stem(j),
      bytes: bytes,
      ext: 'txt',
      mimeType: MimeType.text,
    );
  }
}
