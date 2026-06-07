import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/flight_log_labels.dart';
import '../../domain/report_date_range.dart';
import 'report_date_field.dart';
import 'report_ui_tokens.dart';

class ReportPeriodSelector extends StatelessWidget {
  const ReportPeriodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.displayStart,
    required this.displayEnd,
    required this.customStart,
    required this.customEnd,
    this.customError,
    required this.onPickStart,
    required this.onPickEnd,
    required this.dateFormat,
  });

  final ReportPeriodKind selected;
  final ValueChanged<ReportPeriodKind> onSelected;
  final DateTime displayStart;
  final DateTime displayEnd;
  final DateTime customStart;
  final DateTime customEnd;
  final String? customError;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final DateFormat dateFormat;

  bool get _datesEditable => selected == ReportPeriodKind.custom;

  static const _optionHeight = 52.0;
  static const _gridSpacing = 10.0;
  static const _customBreakpoint = 360.0;

  static const _kinds = ReportPeriodKind.values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPresetGrid(),
        const SizedBox(height: 14),
        _buildDateFields(context),
        if (_datesEditable && customError != null) ...[
          const SizedBox(height: 10),
          _buildErrorBanner(customError!),
        ],
      ],
    );
  }

  Widget _buildPresetGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - _gridSpacing) / 2;
        return Wrap(
          spacing: _gridSpacing,
          runSpacing: _gridSpacing,
          children: _kinds.map((kind) {
            return SizedBox(
              width: itemWidth,
              height: _optionHeight,
              child: _ReportPeriodOption(
                label: _optionLabel(kind),
                icon: _iconFor(kind),
                isSelected: kind == selected,
                onTap: () => onSelected(kind),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDateFields(BuildContext context) {
    final start = _datesEditable ? customStart : displayStart;
    final end = _datesEditable ? customEnd : displayEnd;
    final startField = ReportDateField(
      compact: true,
      label: 'Start date',
      value: dateFormat.format(start),
      readOnly: !_datesEditable,
      onTap: onPickStart,
    );
    final endField = ReportDateField(
      compact: true,
      label: 'End date',
      value: dateFormat.format(end),
      readOnly: !_datesEditable,
      onTap: onPickEnd,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _customBreakpoint;
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: startField),
              const SizedBox(width: _gridSpacing),
              Expanded(child: endField),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            startField,
            const SizedBox(height: _gridSpacing),
            endField,
          ],
        );
      },
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _optionLabel(ReportPeriodKind kind) {
    if (kind == ReportPeriodKind.custom) return 'Custom';
    return reportPeriodKindLabel(kind);
  }

  IconData _iconFor(ReportPeriodKind kind) {
    switch (kind) {
      case ReportPeriodKind.allTime:
        return Icons.all_inclusive_rounded;
      case ReportPeriodKind.thisMonth:
        return Icons.calendar_month_rounded;
      case ReportPeriodKind.thisYear:
        return Icons.calendar_today_rounded;
      case ReportPeriodKind.custom:
        return Icons.tune_rounded;
    }
  }
}

class _ReportPeriodOption extends StatelessWidget {
  const _ReportPeriodOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isSelected ? ReportUiTokens.tileGradient : null,
            color: isSelected ? null : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3949ab).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : ReportUiTokens.labelText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : ReportUiTokens.titleText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
