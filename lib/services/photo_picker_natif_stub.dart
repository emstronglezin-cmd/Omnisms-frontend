/// Version web de [activerSelecteurPhotoSysteme] : intentionnellement vide.
///
/// Le package `image_picker_android` n'a aucune implémentation web — l'importer
/// tel quel casserait la compilation de la PWA. Ce fichier est sélectionné par
/// l'import conditionnel de `main.dart` dès que `dart.library.io` est absent,
/// ce qui garantit que le design et le comportement de la PWA ne changent pas.
Future<void> activerSelecteurPhotoSysteme() async {}
