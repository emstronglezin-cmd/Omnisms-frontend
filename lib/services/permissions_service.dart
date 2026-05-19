import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
    try {
      final status = await Permission.contacts.status;
      return status.isGranted || status.isLimited;
    } catch (e) {
      debugPrint('Error checking contacts permission: $e');
      // Fallback to flutter_contacts
      return await FlutterContacts.requestPermission(readonly: true);
    }
  }

  /// Get detailed permission status
  Future<PermissionStatusExtended> getContactsPermissionStatus() async {
    try {
      final status = await Permission.contacts.status;
      
      if (status.isGranted) {
        return PermissionStatusExtended.granted;
      } else if (status.isLimited) {
        return PermissionStatusExtended.limited;
      } else if (status.isPermanentlyDenied) {
        return PermissionStatusExtended.permanentlyDenied;
      } else if (status.isRestricted) {
        return PermissionStatusExtended.restricted;
      } else {
        return PermissionStatusExtended.denied;
      }
    } catch (e) {
      debugPrint('Error getting permission status: $e');
      return PermissionStatusExtended.denied;
    }
  }

  /// Request contacts permission
  Future<PermissionStatusExtended> requestContactsPermission() async {
    try {
      // First, try with permission_handler (more detailed)
      final status = await Permission.contacts.request();
      
      if (status.isGranted) {
        debugPrint('✅ Contacts permission granted');
        return PermissionStatusExtended.granted;
      } else if (status.isLimited) {
        debugPrint('⚠️ Contacts permission limited (iOS)');
        return PermissionStatusExtended.limited;
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ Contacts permission permanently denied');
        return PermissionStatusExtended.permanentlyDenied;
      } else if (status.isRestricted) {
        debugPrint('🔒 Contacts permission restricted');
        return PermissionStatusExtended.restricted;
      } else {
        debugPrint('❌ Contacts permission denied');
        return PermissionStatusExtended.denied;
      }
    } catch (e) {
      debugPrint('Error requesting permission with permission_handler: $e');
      
      // Fallback to flutter_contacts
      try {
        final granted = await FlutterContacts.requestPermission();
        return granted 
            ? PermissionStatusExtended.granted 
            : PermissionStatusExtended.denied;
      } catch (e2) {
        debugPrint('Error requesting permission with flutter_contacts: $e2');
        return PermissionStatusExtended.denied;
      }
    }
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  /// Check if should show rationale (Android)
  Future<bool> shouldShowRequestRationale() async {
    try {
      return await Permission.contacts.shouldShowRequestRationale;
    } catch (e) {
      return false;
    }
  }
}
