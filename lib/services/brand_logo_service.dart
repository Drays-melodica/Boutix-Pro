import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../theme/boutix_brand.dart';

/// Charge le logo BOUTIX (fichier personnalisé ou asset intégré).
class BrandLogoService {
  BrandLogoService._();
  static final BrandLogoService instance = BrandLogoService._();

  Future<Uint8List?> loadBytes({String? customPath}) async {
    final path = customPath?.trim() ?? '';
    if (path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return file.readAsBytes();
        }
      } catch (_) {
        // Fallback sur le logo intégré.
      }
    }

    try {
      final data = await rootBundle.load(BoutixBrand.logoAsset);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
