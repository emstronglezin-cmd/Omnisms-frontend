import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';

/// Entrée brute du carnet d'adresses du téléphone.
class DeviceContactEntry {
  final String name;
  final String phone;

  const DeviceContactEntry({required this.name, required this.phone});

  @override
  String toString() => 'DeviceContactEntry($name, $phone)';
}

/// Résultat d'une demande de permission contacts.
enum NativeContactsPermission {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unsupported,
}

/// NativeContactsService — accès direct au carnet d'adresses du téléphone.
///
/// Remplace le stub `ContactsService.getPhoneContacts()` qui renvoyait
/// toujours une liste vide (« Mobile: would use FlutterContacts.getContacts() »).
///
/// Rôle : lire les contacts de l'appareil (nom + numéros) pour les envoyer à
/// `POST /api/contacts/sync { contacts, country: 'BF' }` — exactement comme
/// la PWA le fait avec un fichier VCF (`syncContacts()` dans public/app.js).
///
/// Le backend garde la responsabilité de la normalisation, de la
/// déduplication et de l'association numéro → utilisateur OmniSMS :
/// ce service ne fait que lire et nettoyer.
class NativeContactsService {
  /// Les contacts de l'appareil n'existent que sur mobile (pas sur le web).
  bool get isSupported => !kIsWeb;

  // ── Permissions ──────────────────────────────────────────────
  Future<NativeContactsPermission> checkPermission() async {
    if (!isSupported) return NativeContactsPermission.unsupported;
    try {
      final status =
          await FlutterContacts.permissions.check(PermissionType.read);
      return _map(status);
    } catch (e) {
      return NativeContactsPermission.denied;
    }
  }

  /// Demande l'accès en lecture au carnet d'adresses.
  Future<NativeContactsPermission> requestPermission() async {
    if (!isSupported) return NativeContactsPermission.unsupported;
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      return _map(status);
    } catch (e) {
      return NativeContactsPermission.denied;
    }
  }

  /// Ouvre les réglages système (permission refusée définitivement).
  Future<void> openSettings() async {
    if (!isSupported) return;
    try {
      await FlutterContacts.permissions.openSettings();
    } catch (_) {}
  }

  static NativeContactsPermission _map(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return NativeContactsPermission.granted;
      case PermissionStatus.permanentlyDenied:
        return NativeContactsPermission.permanentlyDenied;
      case PermissionStatus.restricted:
        return NativeContactsPermission.restricted;
      case PermissionStatus.denied:
      case PermissionStatus.notDetermined:
        return NativeContactsPermission.denied;
    }
  }

  // ── Lecture du carnet ────────────────────────────────────────
  /// Lit tous les contacts disposant d'au moins un numéro de téléphone.
  ///
  /// Nettoyage appliqué (côté client uniquement) :
  ///   • suppression des espaces et séparateurs ;
  ///   • ignore les numéros trop courts (< 6 chiffres : urgences, SIP, …) ;
  ///   • déduplication sur les 8 derniers chiffres.
  ///
  /// Le numéro reste BRUT (sans indicatif forcé) : le backend le normalise
  /// avec `country: 'BF'`, comme pour l'import VCF de la PWA.
  Future<List<DeviceContactEntry>> fetchContacts() async {
    if (!isSupported) return const [];

    final contacts =
        await FlutterContacts.getAll(properties: {ContactProperty.phone});

    final entries = <DeviceContactEntry>[];
    final seen = <String>{};

    for (final contact in contacts) {
      final name = (contact.displayName ?? '').trim();
      for (final phone in contact.phones) {
        final cleaned = _cleanNumber(phone.number);
        if (cleaned == null) continue;

        final key = _dedupKey(cleaned);
        if (!seen.add(key)) continue;

        entries.add(DeviceContactEntry(
          name: name.isNotEmpty ? name : cleaned,
          phone: cleaned,
        ));
      }
    }
    return entries;
  }

  /// Nettoie un numéro : conserve « + » et les chiffres, supprime le reste.
  /// Renvoie null si le numéro est inexploitable.
  static String? _cleanNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return null; // urgences, codes courts, SIP…
    return cleaned;
  }

  /// Clé de déduplication : les 8 derniers chiffres.
  static String _dedupKey(String cleaned) {
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 8 ? digits : digits.substring(digits.length - 8);
  }
}
