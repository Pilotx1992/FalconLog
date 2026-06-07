import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/currency_card_level.dart';
import '../../providers/currency_status_provider.dart';

void showCurrencyStatusSheet(BuildContext context, CurrencyStatus status) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF8FAFC),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => CurrencyStatusSheet(status: status),
  );
}

class CurrencyStatusSheet extends StatelessWidget {
  const CurrencyStatusSheet({super.key, required this.status});

  final CurrencyStatus status;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Currency status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1a202c),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 20),
            if (status.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Loading…')),
              )
            else if (status.hasError)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Could not load status')),
              )
            else ...[
              _CurrencyKindCard(
                title: 'Day currency',
                icon: Icons.wb_sunny_rounded,
                row: status.day,
                hasFlights: status.hasFlights,
              ),
              const SizedBox(height: 12),
              _CurrencyKindCard(
                title: 'Night currency',
                icon: Icons.nights_stay_rounded,
                row: status.night,
                hasFlights: status.hasFlights,
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/settings');
              },
              child: const Text('Currency alert settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyKindCard extends StatelessWidget {
  const _CurrencyKindCard({
    required this.title,
    required this.icon,
    required this.row,
    required this.hasFlights,
  });

  final String title;
  final IconData icon;
  final CurrencyKindRow row;
  final bool hasFlights;

  @override
  Widget build(BuildContext context) {
    final level = resolveCurrencyCardLevel(row, hasFlights: hasFlights);
    final style = CurrencyCardVisualStyle.forLevel(level);
    final statusLine = currencyCardStatusLine(row, level);

    final lastFlightLabel = row.lastFlightDate == null
        ? 'Last flight: none'
        : 'Last flight: ${DateFormat('MMM dd, yyyy').format(row.lastFlightDate!)}';

    String? agoLine;
    if (level == CurrencyCardLevel.outOfCurrency &&
        row.lastFlightDate != null) {
      agoLine = formatLastFlightDaysAgo(
        DateTime.now().difference(row.lastFlightDate!).inDays,
      );
    }

    final statusLineColor = currencyCardLevelIsUrgent(level)
        ? style.accent
        : const Color(0xFF334155);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: style.accent.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: style.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: style.iconTintBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: style.accent, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a202c),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: style.chipLabel,
                            accent: style.accent,
                          ),
                        ],
                      ),
                      if (level != CurrencyCardLevel.noData) ...[
                        const SizedBox(height: 12),
                        Text(
                          lastFlightLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        statusLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: currencyCardLevelIsUrgent(level)
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: statusLineColor,
                          height: 1.3,
                        ),
                      ),
                      if (agoLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          agoLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}
