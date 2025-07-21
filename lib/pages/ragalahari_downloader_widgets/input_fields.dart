import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputFields extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController folderController;
  final FocusNode urlFocusNode;
  final FocusNode folderFocusNode;
  final VoidCallback onPaste;
  final VoidCallback onSetFolder;
  final bool isValidUrl;
  final VoidCallback onClearUrl;

  const InputFields({
    super.key,
    required this.urlController,
    required this.folderController,
    required this.urlFocusNode,
    required this.folderFocusNode,
    required this.onPaste,
    required this.onSetFolder,
    required this.isValidUrl,
    required this.onClearUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: folderController,
          focusNode: folderFocusNode,
          decoration: InputDecoration(
            labelText: 'Enter Main Folder Name',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_box_rounded),
              onPressed: onSetFolder,
            ),
          ),
          autofocus: false,
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 8.0),
        TextField(
          controller: urlController,
          focusNode: urlFocusNode,
          decoration: InputDecoration(
            labelText: 'Enter Ragalahari Gallery URL',
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: urlController.text.isNotEmpty && !isValidUrl
                    ? Colors.red
                    : Theme.of(context).primaryColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: urlController.text.isNotEmpty && !isValidUrl
                    ? Colors.red
                    : Theme.of(context).primaryColor,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            errorText: urlController.text.isNotEmpty && !isValidUrl
                ? 'URL must start with https://www.ragalahari.com'
                : null,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 20),
                    onPressed: () {
                      if (urlController.text.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: urlController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied to clipboard')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: onClearUrl,
                  ),
                ],
              ),
            ),
          ),
          autofocus: false,
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }
}