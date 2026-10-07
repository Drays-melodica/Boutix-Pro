import '../database/database_helper.dart';

/// Génération de codes-barres internes (compatible BoutixPro C#).
class ProductBarcodeHelper {
  ProductBarcodeHelper._();

  /// Format: VTyyMMdd + numéro séquentiel (ex. VT260901000001).
  static Future<String> nextInternalBarcode() async {
    final products = await DatabaseHelper.instance.getProducts();
    final now = DateTime.now();
    final prefix =
        'VT${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seq = (products.length + 1).toString().padLeft(6, '0');
    return '$prefix$seq';
  }

  /// EAN-13 interne à partir de l'id produit (préfixe 200).
  static String ean13FromProductId(int productId) {
    final base = '200${productId.toString().padLeft(9, '0')}';
    final base12 = base.length >= 12 ? base.substring(0, 12) : base.padLeft(12, '0');
    final digits = base12.split('').map(int.parse).toList();
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += digits[i] * (i.isEven ? 1 : 3);
    }
    final check = (10 - (sum % 10)) % 10;
    return '$base12$check';
  }

  /// Génère un code unique (réessaie si collision).
  static Future<String> nextUniqueBarcode({int maxAttempts = 5}) async {
    for (var i = 0; i < maxAttempts; i++) {
      final code = await nextInternalBarcode();
      final existing = await DatabaseHelper.instance.getProductByBarcode(code);
      if (existing == null) return code;
    }
    final fallback = await nextInternalBarcode();
    return '${fallback}_${DateTime.now().millisecondsSinceEpoch % 10000}';
  }
}
