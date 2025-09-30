import 'dart:io';
import 'package:flutter/material.dart';

int calculateGridColumns(BuildContext context) {
  final double screenWidth = MediaQuery.of(context).size.width;
  if (Platform.isWindows) {
    // Default 4 columns for Windows, adjust based on screen width
    return (screenWidth / 200).floor().clamp(2, 6); // Min 2, max 6 columns
  } else {
    // Default 2 columns for Android, adjust for tablets
    return (screenWidth / 180).floor().clamp(2, 4); // Min 2, max 4 columns
  }
}