import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MinimalSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  
  const MinimalSearchBar({super.key, required this.onChanged});

  @override
  State<MinimalSearchBar> createState() => _MinimalSearchBarState();
}

class _MinimalSearchBarState extends State<MinimalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: color.surface,
        boxShadow: [
          BoxShadow(
            color: color.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.surfaceContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.outline.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search celebrities...',
            hintStyle: TextStyle(color: color.onSurfaceVariant),
            prefixIcon: Icon(Icons.search_rounded, color: color.onSurfaceVariant),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.clear_rounded, color: color.onSurfaceVariant),
                    onPressed: () {
                      _controller.clear();
                      _focusNode.unfocus();
                      widget.onChanged('');
                      setState(() {});
                      HapticFeedback.lightImpact();
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (val) {
             widget.onChanged(val);
             setState(() {});
          },
        ),
      ),
    );
  }
}
