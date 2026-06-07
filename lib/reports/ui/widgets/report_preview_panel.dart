import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/flight_log_labels.dart';
import '../../domain/flight_log_duration.dart';
import '../../domain/flight_report_summary.dart';
import '../../domain/report_date_range.dart';
import 'report_ui_tokens.dart';

class ReportPreviewPanel extends StatelessWidget {
  const ReportPreviewPanel({
    super.key,
    required this.range,
    required this.preview,
    required this.isLoading,
    this.hasError = false,
    this.onRetry,
  });

  final ReportDateRange range;
  final FlightReportSummary? preview;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ReportUiTokens.previewTint,
        borderRadius: BorderRadius.circular(ReportUiTokens.cardRadius),
        border: Border.all(color: ReportUiTokens.previewBorder, width: 1.5),
        boxShadow: ReportUiTokens.cardShadow,
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                  color: ReportUiTokens.spinnerColor,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : hasError
              ? _buildErrorBanner()
              : _buildContent(),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Could not load flight logs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ReportUiTokens.labelText,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final summary = preview;
    final isEmpty = summary == null || summary.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              flex: 0,
              child: Text(
                reportPeriodKindLabel(range.kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ReportUiTokens.titleText,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  range.formatNumericLabel(),
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ReportUiTokens.labelText,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (isEmpty) _buildEmptyBanner() else _buildStatsRow(summary),
      ],
    );
  }

  Widget _buildEmptyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_busy_rounded, color: ReportUiTokens.labelText, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No flights in this period',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ReportUiTokens.labelText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(FlightReportSummary summary) {
    final stats = [
      _PeriodStat(
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFf59e0b),
        label: 'Day Hours',
        value: formatDurationHhMm(summary.dayHours),
      ),
      _PeriodStat(
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF7c3aed),
        label: 'Night Hours',
        value: formatDurationHhMm(summary.nightHours),
      ),
      _PeriodStat(
        icon: Icons.access_time_rounded,
        color: const Color(0xFF38bdf8),
        label: 'Total Hours',
        value: formatDurationHhMm(summary.totalHours),
      ),
      _PeriodStat(
        icon: Icons.flight_rounded,
        color: const Color(0xFF34d399),
        label: 'Flights',
        value: '${summary.totalFlights}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing * (stats.length - 1)) /
            stats.length;

        return Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: spacing),
              SizedBox(width: itemWidth, child: stats[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PeriodStat extends StatelessWidget {
  const _PeriodStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: ReportUiTokens.labelText,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}

/// Styled dropdown matching report section aesthetics.
class ReportStyledDropdown<T> extends StatelessWidget {
  const ReportStyledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ReportUiTokens.labelText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(ReportUiTokens.chipRadius),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF3949ab)),
              items: items,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ReportUiTokens.titleText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String monthName(int month) => DateFormat.MMMM().format(DateTime(2000, month));
