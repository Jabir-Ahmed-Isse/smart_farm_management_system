import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/format.dart';
import '../../../models/farm_report.dart';

const _green = PdfColor.fromInt(0xFF0D631B);
const _grey = PdfColor.fromInt(0xFF666666);
const _right = pw.Alignment.centerRight;
final _headerStyle = pw.TextStyle(
    color: PdfColors.white, fontWeight: pw.FontWeight.bold);
const _headerDeco = pw.BoxDecoration(color: _green);

/// Builds and saves a [FarmReport] as a PDF or an Excel workbook. On web this
/// downloads the file; on mobile it saves to the device.
class ReportExporter {
  static String _fileStem(FarmReport r) {
    final range = '${DateFormat('yyyyMMdd').format(r.start)}-'
        '${DateFormat('yyyyMMdd').format(r.end)}';
    final safeName = r.farmName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return 'SFMS_${safeName}_$range';
  }

  static String _rangeLabel(FarmReport r) =>
      '${DateFormat('d MMM yyyy').format(r.start)} — '
      '${DateFormat('d MMM yyyy').format(r.end)}';

  // ------------------------------------------------------------------ PDF

  static pw.Widget _table(List<String> headers, List<List<String>> data,
      {Map<int, pw.Alignment>? aligns}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: _headerStyle,
      headerDecoration: _headerDeco,
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: aligns,
    );
  }

  static Future<void> exportPdf(FarmReport r) async {
    final doc = pw.Document();

    pw.Widget heading(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: _green)),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Farm Report',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: _green)),
                  pw.SizedBox(height: 2),
                  pw.Text(r.farmName, style: const pw.TextStyle(fontSize: 13)),
                  pw.Text(_rangeLabel(r),
                      style: const pw.TextStyle(fontSize: 10, color: _grey)),
                ],
              ),
              pw.Text(
                  'Generated ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: _grey)),
            ],
          ),
          pw.Divider(color: const PdfColor.fromInt(0xFFCCCCCC)),
          heading('Summary'),
          _table(const ['Metric', 'Value'], [
            ['Total revenue', formatMoney(r.revenue)],
            ['Total expenses', formatMoney(r.expenses)],
            ['Net profit', formatMoney(r.profit)],
            ['Profit margin', '${(r.margin * 100).toStringAsFixed(1)}%'],
            ['Sales recorded', '${r.salesCount}'],
            ['Expenses recorded', '${r.expenseCount}'],
            ['Harvests recorded', '${r.harvestCount}'],
          ], aligns: const {1: _right}),
          if (r.monthly.isNotEmpty) ...[
            heading('Monthly revenue vs expenses'),
            _table(const ['Month', 'Revenue', 'Expenses', 'Profit'], [
              for (final m in r.monthly)
                [
                  m.label,
                  formatMoney(m.revenue),
                  formatMoney(m.expenses),
                  formatMoney(m.revenue - m.expenses),
                ],
            ], aligns: const {1: _right, 2: _right, 3: _right}),
          ],
          if (r.byCategory.isNotEmpty) ...[
            heading('Expenses by category'),
            _table(const ['Category', 'Amount'], [
              for (final c in r.byCategory) [c.name, formatMoney(c.amount)],
            ], aligns: const {1: _right}),
          ],
          if (r.crops.isNotEmpty) ...[
            heading('Crop performance'),
            _table(const ['Crop', 'Revenue', 'Expenses', 'Profit'], [
              for (final c in r.crops)
                [
                  c.crop,
                  formatMoney(c.revenue),
                  formatMoney(c.expenses),
                  formatMoney(c.profit),
                ],
            ], aligns: const {1: _right, 2: _right, 3: _right}),
          ],
          if (r.harvests.isNotEmpty) ...[
            heading('Harvest summary'),
            _table(const ['Crop', 'Quantity', 'Unit'], [
              for (final h in r.harvests)
                [h.crop, h.quantity.toString(), h.unit],
            ]),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    await _save(bytes, _fileStem(r), 'pdf', MimeType.pdf);
  }

  // ---------------------------------------------------------------- Excel

  static Future<void> exportExcel(FarmReport r) async {
    final book = Excel.createExcel();

    final summary = book['Summary'];
    summary.appendRow([TextCellValue('Farm'), TextCellValue(r.farmName)]);
    summary.appendRow([TextCellValue('Period'), TextCellValue(_rangeLabel(r))]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow(
        [TextCellValue('Total revenue'), DoubleCellValue(r.revenue.toDouble())]);
    summary.appendRow([
      TextCellValue('Total expenses'),
      DoubleCellValue(r.expenses.toDouble())
    ]);
    summary.appendRow(
        [TextCellValue('Net profit'), DoubleCellValue(r.profit.toDouble())]);
    summary.appendRow(
        [TextCellValue('Profit margin %'), DoubleCellValue(r.margin * 100)]);
    if (book.getDefaultSheet() != 'Summary') {
      book.setDefaultSheet('Summary');
    }

    final monthly = book['Monthly'];
    monthly.appendRow([
      TextCellValue('Month'),
      TextCellValue('Revenue'),
      TextCellValue('Expenses'),
      TextCellValue('Profit'),
    ]);
    for (final m in r.monthly) {
      monthly.appendRow([
        TextCellValue(m.label),
        DoubleCellValue(m.revenue.toDouble()),
        DoubleCellValue(m.expenses.toDouble()),
        DoubleCellValue((m.revenue - m.expenses).toDouble()),
      ]);
    }

    final cats = book['By Category'];
    cats.appendRow([TextCellValue('Category'), TextCellValue('Amount')]);
    for (final c in r.byCategory) {
      cats.appendRow(
          [TextCellValue(c.name), DoubleCellValue(c.amount.toDouble())]);
    }

    final crops = book['Crop Performance'];
    crops.appendRow([
      TextCellValue('Crop'),
      TextCellValue('Revenue'),
      TextCellValue('Expenses'),
      TextCellValue('Profit'),
    ]);
    for (final c in r.crops) {
      crops.appendRow([
        TextCellValue(c.crop),
        DoubleCellValue(c.revenue.toDouble()),
        DoubleCellValue(c.expenses.toDouble()),
        DoubleCellValue(c.profit.toDouble()),
      ]);
    }

    final harvests = book['Harvests'];
    harvests.appendRow([
      TextCellValue('Crop'),
      TextCellValue('Quantity'),
      TextCellValue('Unit'),
    ]);
    for (final h in r.harvests) {
      harvests.appendRow([
        TextCellValue(h.crop),
        DoubleCellValue(h.quantity.toDouble()),
        TextCellValue(h.unit),
      ]);
    }

    if (book.sheets.containsKey('Sheet1')) {
      book.delete('Sheet1');
    }

    final bytes = book.encode();
    if (bytes == null) return;
    await _save(Uint8List.fromList(bytes), _fileStem(r), 'xlsx',
        MimeType.microsoftExcel);
  }

  static Future<void> _save(
      Uint8List bytes, String name, String ext, MimeType mime) async {
    await FileSaver.instance
        .saveFile(name: name, bytes: bytes, ext: ext, mimeType: mime);
  }
}
