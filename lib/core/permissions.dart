import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:io';

class PermissionHandler {
  static Future<bool> requestAllPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> statuses = {};

    // Define permissions based on Android version
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        statuses = await [
          Permission.photos,
          Permission.videos, // It's good practice to request both
          Permission.notification,
        ].request();
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11 & 12
        statuses = await [
          Permission.manageExternalStorage,
          Permission.notification,
        ].request();
      } else {
        // Older Android versions
        statuses = await [
          Permission.storage,
          Permission.notification,
        ].request();
      }
    } else {
      // For iOS or other platforms
      statuses = await [
        Permission.photos,
        Permission.notification,
      ].request();
    }


    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        // If any permission is permanently denied, show the dialog to open settings.
        if (status.isPermanentlyDenied) {
          _showPermissionDeniedDialog(context, '${permission.toString().split('.').last} permission is required to continue.');
        }
      }
    });

    return allGranted;
  }

  static Future<bool> checkStoragePermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.photos.isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true; // Non-Android platforms don't require these specific storage permissions
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
        content: Text(message),
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