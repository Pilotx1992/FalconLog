import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/currency/domain/currency_card_level.dart';
import 'package:falconlog/providers/currency_status_provider.dart';

void main() {
  group('resolveCurrencyCardLevel', () {
    test('no flights in logbook', () {
      expect(
        resolveCurrencyCardLevel(CurrencyKindRow.empty, hasFlights: false),
        CurrencyCardLevel.noData,
      );
    });

    test('no day flights', () {
      const row = CurrencyKindRow(
        daysRemaining: null,
        outOfCurrency: true,
      );
      expect(
        resolveCurrencyCardLevel(row, hasFlights: true),
        CurrencyCardLevel.outOfCurrency,
      );
    });

    test('in currency when more than one day remains', () {
      const row = CurrencyKindRow(
        daysRemaining: 5,
        outOfCurrency: false,
      );
      expect(
        resolveCurrencyCardLevel(row, hasFlights: true),
        CurrencyCardLevel.inCurrency,
      );
    });

    test('one day left', () {
      const row = CurrencyKindRow(
        daysRemaining: 1,
        outOfCurrency: false,
      );
      expect(
        resolveCurrencyCardLevel(row, hasFlights: true),
        CurrencyCardLevel.oneDayLeft,
      );
    });

    test('expires today', () {
      const row = CurrencyKindRow(
        daysRemaining: 0,
        outOfCurrency: false,
      );
      expect(
        resolveCurrencyCardLevel(row, hasFlights: true),
        CurrencyCardLevel.expiresToday,
      );
    });

    test('out of currency', () {
      const row = CurrencyKindRow(
        daysRemaining: -2,
        outOfCurrency: true,
      );
      expect(
        resolveCurrencyCardLevel(row, hasFlights: true),
        CurrencyCardLevel.outOfCurrency,
      );
    });
  });

  group('CurrencyCardVisualStyle', () {
    test('accent colors match level', () {
      expect(
        CurrencyCardVisualStyle.forLevel(CurrencyCardLevel.inCurrency).accent,
        const Color(0xFF22C55E),
      );
      expect(
        CurrencyCardVisualStyle.forLevel(CurrencyCardLevel.oneDayLeft).accent,
        const Color(0xFF3B82F6),
      );
      expect(
        CurrencyCardVisualStyle.forLevel(CurrencyCardLevel.expiresToday).accent,
        const Color(0xFFEAB308),
      );
      expect(
        CurrencyCardVisualStyle.forLevel(CurrencyCardLevel.outOfCurrency).accent,
        const Color(0xFFEF4444),
      );
    });
  });

  group('currencyCardStatusLine', () {
    test('no data message', () {
      expect(
        currencyCardStatusLine(
          CurrencyKindRow.empty,
          CurrencyCardLevel.noData,
        ),
        'Log a flight to track currency',
      );
    });

    test('expires today line', () {
      const row = CurrencyKindRow(
        lastFlightDate: null,
        daysRemaining: 0,
        outOfCurrency: false,
      );
      expect(
        currencyCardStatusLine(row, CurrencyCardLevel.expiresToday),
        'Last flight: none',
      );
    });

    test('remaining days line', () {
      final row = CurrencyKindRow(
        lastFlightDate: DateTime(2026, 5, 1),
        daysRemaining: 3,
        outOfCurrency: false,
      );
      expect(
        currencyCardStatusLine(row, CurrencyCardLevel.inCurrency),
        '3 days remaining',
      );
    });

    test('expired line', () {
      final row = CurrencyKindRow(
        lastFlightDate: DateTime(2026, 5, 1),
        daysRemaining: -2,
        outOfCurrency: true,
      );
      expect(
        currencyCardStatusLine(row, CurrencyCardLevel.outOfCurrency),
        'expired 2 days ago',
      );
    });
  });
}
