import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/currency_status_provider.dart';
import 'currency_status_sheet.dart';

/// Notification-style AppBar action showing currency summary sheet.
class CurrencyAppBarAction extends ConsumerWidget {
  const CurrencyAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(currencyStatusProvider);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(
                Icons.notifications_rounded,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'Currency status',
              onPressed: () => showCurrencyStatusSheet(context, status),
            ),
            if (status.hasAlert && !status.isLoading && !status.hasError)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
