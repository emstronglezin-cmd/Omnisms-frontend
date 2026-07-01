import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

enum PermissionStatusExtended {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  /// Check if contacts permission is granted
  Future<bool> hasContactsPermission() async {
    if (kIsWeb) return false; // Web doesn't have contacts permission
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      debugPrint('Error checking contacts permission: $e');
      return false;
    }
  }

  /// Get detailed permission status
  Future<PermissionStatusExtended> getContactsPermissionStatus() async {
    if (kIsWeb) return PermissionStatusExtended.denied;
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      return granted
          ? PermissionStatusExtended.granted
          : PermissionStatusExtended.denied;
    } catch (e) {
      debugPrint('Error getting permission status: $e');
      return PermissionStatusExtended.denied;
    }
  }

  /// Request contacts permission
  Future<PermissionStatusExtended> requestContactsPermission() async {
    if (kIsWeb) {
      debugPrint('⚠️ Contacts permission not available on web');
      return PermissionStatusExtended.denied;
    }
    try {
      final granted = await FlutterContacts.requestPermission();
      if (granted) {
        debugPrint('✅ Contacts permission granted');
        return PermissionStatusExtended.granted;
      } else {
        debugPrint('❌ Contacts permission denied');
        return PermissionStatusExtended.denied;
      }
    } catch (e) {
      debugPrint('Error requesting contacts permission: $e');
      return PermissionStatusExtended.denied;
    }
  }

  /// Open app settings (no-op on web)
  Future<void> openAppSettings() async {
    if (kIsWeb) return;
    debugPrint('⚠️ openAppSettings: mobile only');
  }

  /// Check if should show rationale (Android only)
  Future<bool> shouldShowRequestRationale() async {
    if (kIsWeb) return false;
    return false;
  }
}
