import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickProfileImage({
  ImageSource source = ImageSource.gallery,
}) async {
  final file = await ImagePicker().pickImage(
    source: source,
    imageQuality: 80,
    maxWidth: 600,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
