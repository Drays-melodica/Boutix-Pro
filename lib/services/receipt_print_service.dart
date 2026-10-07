import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import 'brand_logo_service.dart';
import 'printer_config_service.dart';

class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPriceTtc,
    required this.lineTotalTtc,
  });

  final String name;
  final int qty;
  final double unitPriceTtc;
  final double lineTotalTtc;
}

/// Impression ticket thermique 80 mm (imprimante par défaut).
class ReceiptPrintService {
  ReceiptPrintService._();
  static final ReceiptPrintService instance = ReceiptPrintService._();

  static const double _paperWidthMm = 80;
  static const double _marginMm = 2;
  static const double _charsPerLine = 42;

  final _money = NumberFormat('#,##0.00', 'fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  static const _textStyle = pw.TextStyle(fontSize: 8, lineSpacing: 1.15);
  static const _titleStyle =
      pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  static const _totalStyle =
      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  Future<void> printSaleReceipt({
    required int saleId,
    required DateTime createdAt,
    required List<ReceiptLine> lines,
    required double subtotalTtc,
    required double discountAmount,
    required double totalTtc,
    required String paymentMethod,
    double received = 0,
    double changeDue = 0,
  }) async {
    final db = DatabaseHelper.instance;
    final shopName = await db.getSetting('shop_name', 'Ma Boutique');
    final shopPhone = (await db.getSetting('shop_phone', '')).trim();
    final shopAddress = (await db.getSetting('shop_address', '')).trim();
    final logoPath = (await db.getSetting('logo_path', '')).trim();
    final currency = await db.getSetting('currency_label', 'DA');
    final logoBytes =
        await BrandLogoService.instance.loadBytes(customPath: logoPath);

    final built = await _buildReceipt(
      logoBytes: logoBytes,
      shopName: shopName,
      shopPhone: shopPhone,
      shopAddress: shopAddress,
      saleId: saleId,
      createdAt: createdAt,
      lines: lines,
      subtotalTtc: subtotalTtc,
      discountAmount: discountAmount,
      totalTtc: totalTtc,
      currency: currency,
      paymentMethod: paymentMethod,
      received: received,
      changeDue: changeDue,
    );

    await _printToDefaultPrinter(
      built.bytes,
      format: built.format,
      jobName: 'Ticket_$saleId',
    );
  }

  PdfPageFormat _ticketFormat(double heightMm) {
    final height = heightMm.clamp(40, 1500);
    return PdfPageFormat(
      _paperWidthMm * PdfPageFormat.mm,
      height * PdfPageFormat.mm,
      marginLeft: _marginMm * PdfPageFormat.mm,
      marginRight: _marginMm * PdfPageFormat.mm,
      marginTop: _marginMm * PdfPageFormat.mm,
      marginBottom: 4 * PdfPageFormat.mm,
    );
  }

  double _estimateHeightMm({
    required int itemCount,
    required bool hasLogo,
    required bool hasPhone,
    required bool hasAddress,
    required bool hasDiscount,
    required bool hasCashDetails,
  }) {
    var h = 16.0;
    if (hasLogo) h += 18;
    if (hasPhone) h += 4;
    if (hasAddress) h += 6;
    h += 12;
    h += itemCount * 8.5;
    h += 16;
    if (hasDiscount) h += 8;
    if (hasCashDetails) h += 8;
    h += 10;
    return h;
  }

  Future<({Uint8List bytes, PdfPageFormat format})> _buildReceipt({
    required Uint8List? logoBytes,
    required String shopName,
    required String shopPhone,
    required String shopAddress,
    required int saleId,
    required DateTime createdAt,
    required List<ReceiptLine> lines,
    required double subtotalTtc,
    required double discountAmount,
    required double totalTtc,
    required String currency,
    required String paymentMethod,
    required double received,
    required double changeDue,
  }) async {
    final hasCash = paymentMethod == 'cash' && received > 0;
    final hasDiscount = discountAmount > 0;
    final format = _ticketFormat(
      _estimateHeightMm(
        itemCount: lines.length,
        hasLogo: logoBytes != null,
        hasPhone: shopPhone.isNotEmpty,
        hasAddress: shopAddress.isNotEmpty,
        hasDiscount: hasDiscount,
        hasCashDetails: hasCash,
      ),
    );

    final doc = pw.Document();
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final divider = pw.Text(
      '-' * _charsPerLine.toInt(),
      style: _textStyle,
      textAlign: pw.TextAlign.center,
    );

    doc.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(
          base: pw.Font.courier(),
          bold: pw.Font.courierBold(),
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (logo != null) ...[
                pw.Center(
                  child: pw.Image(
                    logo,
                    height: 14 * PdfPageFormat.mm,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 2 * PdfPageFormat.mm),
              ],
              pw.Text(
                shopName,
                style: _titleStyle,
                textAlign: pw.TextAlign.center,
              ),
              if (shopPhone.isNotEmpty)
                pw.Text(shopPhone, style: _textStyle, textAlign: pw.TextAlign.center),
              if (shopAddress.isNotEmpty)
                pw.Text(
                  shopAddress,
                  style: _textStyle,
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Text('Ticket #$saleId', style: _textStyle, textAlign: pw.TextAlign.center),
              pw.Text(
                _dateFmt.format(createdAt),
                style: _textStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
              divider,
              pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
              ...lines.map((line) => _lineWidget(line, currency)),
              pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
              divider,
              pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
              if (hasDiscount) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sous-total', style: _textStyle),
                    pw.Text('${_money.format(subtotalTtc)} $currency', style: _textStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('REMISE', style: _textStyle),
                    pw.Text('-${_money.format(discountAmount)} $currency', style: _textStyle),
                  ],
                ),
                pw.SizedBox(height: 1 * PdfPageFormat.mm),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL TTC', style: _totalStyle),
                  pw.Text(
                    '${_money.format(totalTtc)} $currency',
                    style: _totalStyle,
                  ),
                ],
              ),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Text(
                'Paiement: ${_paymentLabel(paymentMethod)}',
                style: _textStyle,
              ),
              if (hasCash) ...[
                pw.Text(
                  'Encaissé: ${_money.format(received)} $currency',
                  style: _textStyle,
                ),
                pw.Text(
                  'Rendu:   ${_money.format(changeDue)} $currency',
                  style: _textStyle,
                ),
              ],
              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Text(
                'Merci pour votre achat.',
                style: _textStyle,
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return (bytes: await doc.save(), format: format);
  }

  pw.Widget _lineWidget(ReceiptLine line, String currency) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 1.2 * PdfPageFormat.mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            '${line.qty} x ${_wrap(line.name)}',
            style: _textStyle,
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '@ ${_money.format(line.unitPriceTtc)}',
                style: _textStyle,
              ),
              pw.Text(
                '${_money.format(line.lineTotalTtc)} $currency',
                style: _textStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _wrap(String text) {
    if (text.length <= _charsPerLine) return text;
    return '${text.substring(0, _charsPerLine.toInt() - 1)}…';
  }

  String _paymentLabel(String method) => switch (method) {
        'cash' => 'Espèces',
        'card' => 'Carte',
        'mobile' => 'Mobile',
        _ => method,
      };

  Future<void> _printToDefaultPrinter(
    Uint8List bytes, {
    required PdfPageFormat format,
    required String jobName,
  }) async {
    final target = await PrinterConfigService.instance.resolveReceiptPrinter();
    if (target == null) {
      throw Exception(
        'Aucune imprimante ticket configurée.\n'
        'Allez dans Paramètres > IMPRIMANTES (F5) pour en choisir une.',
      );
    }

    final ok = await Future.sync(
      () => Printing.directPrintPdf(
        printer: target,
        name: jobName,
        format: format,
        dynamicLayout: false,
        forceCustomPrintPaper: false,
        usePrinterSettings: true,
        onLayout: (_) async => bytes,
      ),
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(
        'Délai d\'impression dépassé (${target.name}).',
      ),
    );

    if (ok != true) {
      throw Exception(
        'L\'imprimante n\'a pas accepté le ticket (${target.name}).',
      );
    }
  }
}
