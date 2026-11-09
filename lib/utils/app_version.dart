/// Version de l'application — **source unique** côté code Dart.
///
/// Contrainte : `pubspec.yaml` reste la source de vérité pour Flutter
/// (Android `versionName`/`versionCode`, iOS `CFBundleShortVersionString`).
/// Les valeurs ci-dessous doivent donc lui être identiques.
///
/// Plutôt que de compter sur la relecture humaine, un test automatisé
/// (`test/app_version_test.dart`) lit `pubspec.yaml` et échoue si les deux
/// sources divergent. C'est ce test qui garantit la cohérence : sans lui, un
/// écran pourrait afficher « 2.5.0 » dans un binaire réellement en 3.0.0.
///
/// Aucune dépendance n'a été ajoutée pour lire la version depuis le binaire
/// (`package_info_plus`) : elle aurait aussi modifié le bundle de la PWA,
/// alors que la consigne est de ne pas toucher au web.
abstract final class AppVersion {
  /// Version affichable, par exemple `3.0.0`.
  static const String version = '3.0.0';

  /// Numéro de build (monotone), par exemple `3`.
  static const int build = 3;

  /// Nom commercial de la version.
  static const String nom = 'OmniSMS V3';

  /// Version complète, par exemple `3.0.0 (3)`.
  static String get complete => '$version ($build)';

  /// Chaîne attendue dans `pubspec.yaml`, par exemple `3.0.0+3`.
  static String get pubspec => '$version+$build';

  /// Étiquette courte pour les écrans : `V3.0.0`.
  static String get courte => 'V$version';
}
