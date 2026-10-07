import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 (200 000 itérations), compatible BoutixPro C#.
class PasswordHasher {
  PasswordHasher._();

  static const int iterations = 200000;

  static (String hashHex, String saltHex) create(String password) {
    final salt = _randomBytes(16);
    final hash = _pbkdf2(password, salt);
    return (_toHex(hash), _toHex(salt));
  }

  static String hash(String password, String saltHex) {
    final salt = _fromHex(saltHex);
    return _toHex(_pbkdf2(password, salt));
  }

  static bool verify(String password, String storedHashHex, String saltHex) {
    try {
      final computed = hash(password, saltHex);
      return _fixedTimeEquals(
        _fromHex(computed),
        _fromHex(storedHashHex),
      );
    } catch (_) {
      return false;
    }
  }

  static Uint8List _pbkdf2(String password, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    return _pbkdf2Impl(hmac, salt, iterations, 32);
  }

  static Uint8List _pbkdf2Impl(
    Hmac hmac,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) {
    final blocks = (keyLength + 31) ~/ 32;
    final result = BytesBuilder();
    for (var block = 1; block <= blocks; block++) {
      final blockBytes = ByteData(4)..setUint32(0, block, Endian.big);
      final u = hmac.convert([...salt, ...blockBytes.buffer.asUint8List()]);
      var t = Uint8List.fromList(u.bytes);
      var r = Uint8List.fromList(u.bytes);
      for (var i = 1; i < iterations; i++) {
        final next = hmac.convert(r);
        r = Uint8List.fromList(next.bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= r[j];
        }
      }
      result.add(t);
    }
    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static bool _fixedTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
