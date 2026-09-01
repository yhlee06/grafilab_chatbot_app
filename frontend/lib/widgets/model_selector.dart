import 'package:flutter/material.dart';

class ModelSelector extends StatelessWidget {
  final String selectedModel;
  final VoidCallback onTap;

  const ModelSelector({
    super.key,
    required this.selectedModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              selectedModel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}
