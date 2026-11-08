import 'dart:io';

import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Active le **sélecteur photo système** d'Android (Photo Picker).
///
/// Pourquoi : par défaut `image_picker` passe par une intention
/// `ACTION_GET_CONTENT`, qui exige `READ_EXTERNAL_STORAGE` (Android ≤ 12) ou
/// `READ_MEDIA_IMAGES` (Android 13+). Le Photo Picker, lui, donne accès à la
/// galerie **sans aucune permission** et affiche une interface moderne.
///
/// Sans effet sur iOS (aucune configuration équivalente n'existe) et jamais
/// appelé sur le web — voir `photo_picker_natif_stub.dart`.
Future<void> activerSelecteurPhotoSysteme() async {
  if (!Platform.isAndroid) return;

  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}
