import 'package:flutter/material.dart';

import 'report_ui_tokens.dart';

class ReportDateField extends StatelessWidget {
  const ReportDateField({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.onTap,
    this.icon = Icons.calendar_today_rounded,
    this.readOnly = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;
  final IconData icon;
  final bool readOnly;
  final bool compact;

  static const double _compactHeight = 52;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactField();
    }
    return _buildStandardField();
  }

  Widget _buildCompactField() {
    final content = SizedBox(
      height: _compactHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3949ab).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF3949ab), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: ReportUiTokens.labelText,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ReportUiTokens.titleText,
                    ),
                  ),
                ],
              ),
            ),
            if (!readOnly)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF3949ab),
                size: 20,
              ),
          ],
        ),
      ),
    );

    if (readOnly) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
        child: content,
      ),
    );
  }

  Widget _buildStandardField() {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: ReportUiTokens.tileGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3949ab).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ReportUiTokens.labelText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ReportUiTokens.titleText,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ReportUiTokens.faintText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!readOnly)
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF3949ab),
            ),
        ],
      ),
    );

    if (readOnly) {
      return Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
        child: content,
      );
    }

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
        child: content,
      ),
    );
  }
}
