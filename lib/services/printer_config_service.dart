import 'package:printing/printing.dart';

import '../database/database_helper.dart';

/// Clés de configuration en base (app_settings).
const kReceiptPrinterKey = 'printer_receipt_name';
const kBarcodePrinterKey = 'printer_barcode_name';

/// Service central de résolution des imprimantes configurées.
///
/// Cherche l'imprimante par nom enregistré en DB.
/// Si aucune config ou imprimante introuvable → retourne null.
class PrinterConfigService {
  PrinterConfigService._();
  static final PrinterConfigService instance = PrinterConfigService._();

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Liste toutes les imprimantes Windows (cache 5 s).
  Future<List<Printer>> listAll() => Printing.listPrinters();

  /// Cherche l'imprimante dont le nom matche exactement.
  Future<Printer?> _findByName(String name) async {
    if (name.trim().isEmpty) return null;
    final printers = await listAll();
    for (final p in printers) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Fallback : 1re imprimante non-virtuelle disponible.
  Printer? _fallback(List<Printer> printers) {
    for (final p in printers) {
      if (p.isAvailable && !_isVirtual(p)) return p;
    }
    for (final p in printers) {
      if (!_isVirtual(p)) return p;
    }
    return null;
  }

  static bool _isVirtual(Printer printer) {
    final n = '${printer.name} ${printer.model ?? ''}'.toLowerCase();
    return n.contains('pdf') ||
        n.contains('xps') ||
        n.contains('onenote') ||
        n.contains('fax') ||
        n.contains('print to') ||
        n.contains('imprimer dans') ||
        n.contains('vers pdf');
  }

  // ── Résolution ───────────────────────────────────────────────────────────

  /// Résout l'imprimante ticket de caisse.
  Future<Printer?> resolveReceiptPrinter() async {
    final name = await DatabaseHelper.instance.getSetting(kReceiptPrinterKey, '');
    final byName = await _findByName(name);
    if (byName != null) return byName;
    // Pas de config → fallback intelligent
    final all = await listAll();
    return _fallback(all);
  }

  /// Résout l'imprimante étiquettes code-barres.
  Future<Printer?> resolveBarcodePrinter() async {
    final name = await DatabaseHelper.instance.getSetting(kBarcodePrinterKey, '');
    final byName = await _findByName(name);
    if (byName != null) return byName;
    // Pas de fallback pour les étiquettes → l'utilisateur doit configurer
    return null;
  }

  // ── Sauvegarde ───────────────────────────────────────────────────────────

  Future<void> saveReceiptPrinter(String printerName) async {
    await DatabaseHelper.instance.setSetting(kReceiptPrinterKey, printerName);
  }

  Future<void> saveBarcodePrinter(String printerName) async {
    await DatabaseHelper.instance.setSetting(kBarcodePrinterKey, printerName);
  }

  Future<String> getReceiptPrinterName() async {
    return DatabaseHelper.instance.getSetting(kReceiptPrinterKey, '');
  }

  Future<String> getBarcodePrinterName() async {
    return DatabaseHelper.instance.getSetting(kBarcodePrinterKey, '');
  }
}
