import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:io';

class PermissionHandler {
  static Future<bool> requestAllPermissions(BuildContext context) async {
    bool allPermissionsGranted = true;

    // Request storage-related permissions
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      bool isPermissionGranted = false;

      if (androidInfo.version.sdkInt >= 33) {
        // Request photos permission for Android 13+
        final photoStatus = await Permission.photos.status;
        if (!photoStatus.isGranted) {
          final newStatus = await Permission.photos.request();
          isPermissionGranted = newStatus.isGranted;
        } else {
          isPermissionGranted = true;
        }
      } else if (androidInfo.version.sdkInt >= 30) {
        // Request manageExternalStorage for Android 11+
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        if (!manageStorageStatus.isGranted) {
          final newStatus = await Permission.manageExternalStorage.request();
          isPermissionGranted = newStatus.isGranted;
        } else {
          isPermissionGranted = true;
        }
      } else {
        // Request storage for older Android versions
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          final newStatus = await Permission.storage.request();
          isPermissionGranted = newStatus.isGranted;
        } else {
          isPermissionGranted = true;
        }
      }

      if (!isPermissionGranted) {
        allPermissionsGranted = false;
        _showPermissionDeniedDialog(context, 'Storage or media permission denied.');
      }
    }

    // Request notification permission
    if (Platform.isAndroid) {
      final notificationStatus = await AwesomeNotifications().requestPermissionToSendNotifications();
      if (!notificationStatus) {
        allPermissionsGranted = false;
        _showPermissionDeniedDialog(context, 'Notification permission denied.');
      }
    }

    return allPermissionsGranted;
  }

  static Future<bool> checkStoragePermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.photos.status.isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        return await Permission.manageExternalStorage.status.isGranted;
      } else {
        return await Permission.storage.status.isGranted;
      }
    }
    return true; // Non-Android platforms don't require storage permissions
  }

  static Future<void> requestFirstRunPermissions(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('isFirstRun') ?? true;

    if (isFirstRun) {
      await requestAllPermissions(context);
      await prefs.setBool('isFirstRun', false);
    }
  }

  static void _showPermissionDeniedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text('$message Please grant the required permissions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}