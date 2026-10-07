import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import 'printer_config_service.dart';

/// Impression d'étiquettes code-barres autocollantes.
///
/// Dimensions par défaut : 50 × 30 mm — format standard étiquettes
/// thermiques autocollantes (compatible Xprinter, TSC, Zebra, etc.).
class BarcodePrintService {
  BarcodePrintService._();
  static final BarcodePrintService instance = BarcodePrintService._();

  static const double _labelWidthMm = 50;
  static const double _labelHeightMm = 30;
  static const double _marginMm = 2;

  /// Imprime une étiquette code-barres pour un article.
  ///
  /// L'étiquette contient :
  /// - Le nom de l'article (tronqué si trop long)
  /// - Le prix de vente
  /// - Le code-barres en format Code128 (lisible par scanner)
  /// - Le numéro du code-barres en texte
  Future<void> printBarcode({
    required String productName,
    required String barcode,
    required double salePrice,
    required String currency,
    int copies = 1,
  }) async {
    if (barcode.trim().isEmpty) {
      throw Exception('Aucun code-barres à imprimer.');
    }

    final target = await PrinterConfigService.instance.resolveBarcodePrinter();
    if (target == null) {
      throw Exception(
        'Aucune imprimante étiquettes configurée.\n'
        'Allez dans Paramètres > IMPRIMANTES pour en choisir une.',
      );
    }

    final bytes = await _buildLabel(
      productName: productName,
      barcode: barcode,
      salePrice: salePrice,
      currency: currency,
    );

    final format = PdfPageFormat(
      _labelWidthMm * PdfPageFormat.mm,
      _labelHeightMm * PdfPageFormat.mm,
      marginLeft: _marginMm * PdfPageFormat.mm,
      marginRight: _marginMm * PdfPageFormat.mm,
      marginTop: _marginMm * PdfPageFormat.mm,
      marginBottom: _marginMm * PdfPageFormat.mm,
    );

    for (var i = 0; i < copies; i++) {
      final ok = await Future.sync(
        () => Printing.directPrintPdf(
          printer: target,
          name: 'Etiquette_$barcode',
          format: format,
          dynamicLayout: false,
          forceCustomPrintPaper: false,
          usePrinterSettings: true,
          onLayout: (_) async => bytes,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'Délai d\'impression dépassé (${target.name}).',
        ),
      );

      if (ok != true) {
        throw Exception(
          'L\'imprimante n\'a pas accepté l\'étiquette (${target.name}).',
        );
      }
    }
  }

  Future<Uint8List> _buildLabel({
    required String productName,
    required String barcode,
    required double salePrice,
    required String currency,
  }) async {
    final doc = pw.Document();

    final format = PdfPageFormat(
      _labelWidthMm * PdfPageFormat.mm,
      _labelHeightMm * PdfPageFormat.mm,
      marginLeft: _marginMm * PdfPageFormat.mm,
      marginRight: _marginMm * PdfPageFormat.mm,
      marginTop: _marginMm * PdfPageFormat.mm,
      marginBottom: _marginMm * PdfPageFormat.mm,
    );

    // Tronquer le nom si trop long
    var displayName = productName;
    if (displayName.length > 28) {
      displayName = '${displayName.substring(0, 27)}…';
    }

    final priceStr = '${salePrice.toStringAsFixed(2)} $currency';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(
          base: pw.Font.courier(),
          bold: pw.Font.courierBold(),
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Nom de l'article
              pw.Text(
                displayName,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
              ),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              // Prix
              pw.Text(
                priceStr,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
              // Code-barres visuel
              pw.BarcodeWidget(
                data: barcode,
                barcode: pw.Barcode.code128(),
                width: (_labelWidthMm - 2 * _marginMm - 4) * PdfPageFormat.mm,
                height: 10 * PdfPageFormat.mm,
                drawText: false,
              ),
              pw.SizedBox(height: 0.8 * PdfPageFormat.mm),
              // Numéro code-barres
              pw.Text(
                barcode,
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
