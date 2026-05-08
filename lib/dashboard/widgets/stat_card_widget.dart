import 'package:flutter/material.dart';

class StatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final String? changeText;
  final bool isUp;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const StatCardWidget({
    Key? key,
    required this.title,
    required this.value,
    this.changeText,
    this.isUp = true,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark slate matching the Figma design
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (changeText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isUp ? Icons.arrow_outward : Icons.south_east,
                  color: isUp ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  changeText!,
                  style: TextStyle(
                    color: isUp ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
