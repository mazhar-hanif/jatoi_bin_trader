import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const maxLocalImageBytes = 2 * 1024 * 1024;

class LocalImageTooLarge implements Exception {
  const LocalImageTooLarge();
}

class LocalImageUnavailable implements Exception {
  const LocalImageUnavailable();
}

Future<Uint8List?> pickLocalImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final bytes = result.files.first.bytes;
  if (bytes == null) throw const LocalImageUnavailable();
  if (bytes.lengthInBytes > maxLocalImageBytes) {
    throw const LocalImageTooLarge();
  }
  return bytes;
}

String encodeLocalImage(Uint8List bytes) => base64Encode(bytes);

Uint8List? decodeLocalImage(String? encoded) {
  if (encoded == null || encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}
