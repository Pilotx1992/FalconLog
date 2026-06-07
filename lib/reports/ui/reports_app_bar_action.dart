import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'flight_report_export_screen.dart';

/// AppBar action — opens flight statistics PDF export (trailing, opposite back).
class ReportsAppBarAction extends StatelessWidget {
  const ReportsAppBarAction({super.key});

  static const _iconAsset = 'assets/uil--export.svg';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        icon: SvgPicture.asset(
          _iconAsset,
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        tooltip: 'Flight reports',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const FlightReportExportScreen(),
            ),
          );
        },
      ),
    );
  }
}
