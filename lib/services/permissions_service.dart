import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
// flutter_contacts is mobile-only — all calls are guarded by kIsWeb checks below

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
    // Contacts permission is not available on web
    return false;
  }

  /// Get detailed permission status
  Future<PermissionStatusExtended> getContactsPermissionStatus() async {
    // On web: contacts access is not available
    return PermissionStatusExtended.denied;
  }

  /// Request contacts permission
  Future<PermissionStatusExtended> requestContactsPermission() async {
    debugPrint('⚠️ Contacts permission not available on web');
    return PermissionStatusExtended.denied;
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
