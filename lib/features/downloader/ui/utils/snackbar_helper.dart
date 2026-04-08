import 'package:flutter/material.dart';

class SnackbarHelper {
  static void showModernSnackBar({
    required BuildContext context,
    required String message,
    required IconData icon,
    bool isError = false,
  }) {
    final color = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: isError ? color.onError : color.onInverseSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? color.error : color.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(milliseconds: isError ? 4000 : 2500),
      ),
    );
  }
}
