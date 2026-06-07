import 'package:flutter/material.dart';

import '../../notifications/domain/currency_daily_notification.dart';
import '../../providers/currency_status_provider.dart';

enum CurrencyCardLevel {
  inCurrency,
  oneDayLeft,
  expiresToday,
  outOfCurrency,
  noData,
}

CurrencyCardLevel resolveCurrencyCardLevel(
  CurrencyKindRow row, {
  required bool hasFlights,
}) {
  if (!hasFlights) return CurrencyCardLevel.noData;
  if (row.lastFlightDate == null && row.outOfCurrency) {
    return CurrencyCardLevel.outOfCurrency;
  }
  if (row.outOfCurrency) return CurrencyCardLevel.outOfCurrency;
  final remaining = row.daysRemaining;
  if (remaining == null) return CurrencyCardLevel.outOfCurrency;
  if (remaining > 1) return CurrencyCardLevel.inCurrency;
  if (remaining == 1) return CurrencyCardLevel.oneDayLeft;
  if (remaining == 0) return CurrencyCardLevel.expiresToday;
  return CurrencyCardLevel.outOfCurrency;
}

class CurrencyCardVisualStyle {
  const CurrencyCardVisualStyle({
    required this.accent,
    required this.chipLabel,
    required this.iconTintBackground,
  });

  final Color accent;
  final String chipLabel;
  final Color iconTintBackground;

  static CurrencyCardVisualStyle forLevel(CurrencyCardLevel level) {
    switch (level) {
      case CurrencyCardLevel.inCurrency:
        return CurrencyCardVisualStyle(
          accent: const Color(0xFF22C55E),
          chipLabel: 'In currency',
          iconTintBackground: const Color(0xFF22C55E).withValues(alpha: 0.12),
        );
      case CurrencyCardLevel.oneDayLeft:
        return CurrencyCardVisualStyle(
          accent: const Color(0xFF3B82F6),
          chipLabel: '1 day left',
          iconTintBackground: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        );
      case CurrencyCardLevel.expiresToday:
        return CurrencyCardVisualStyle(
          accent: const Color(0xFFEAB308),
          chipLabel: 'Expires today',
          iconTintBackground: const Color(0xFFEAB308).withValues(alpha: 0.12),
        );
      case CurrencyCardLevel.outOfCurrency:
        return CurrencyCardVisualStyle(
          accent: const Color(0xFFEF4444),
          chipLabel: 'Out of currency',
          iconTintBackground: const Color(0xFFEF4444).withValues(alpha: 0.12),
        );
      case CurrencyCardLevel.noData:
        return CurrencyCardVisualStyle(
          accent: const Color(0xFF94A3B8),
          chipLabel: 'No flights yet',
          iconTintBackground: const Color(0xFF94A3B8).withValues(alpha: 0.12),
        );
    }
  }
}

bool currencyCardLevelIsUrgent(CurrencyCardLevel level) =>
    level == CurrencyCardLevel.oneDayLeft ||
    level == CurrencyCardLevel.expiresToday ||
    level == CurrencyCardLevel.outOfCurrency;

String currencyCardStatusLine(CurrencyKindRow row, CurrencyCardLevel level) {
  if (level == CurrencyCardLevel.noData) {
    return 'Log a flight to track currency';
  }
  if (row.lastFlightDate == null) return 'Last flight: none';
  final remaining = row.daysRemaining ?? (row.outOfCurrency ? -1 : 0);
  return formatCurrencyKindStatusLine(remaining);
}
