import 'package:pdf/widgets.dart' as pw;

import 'flight_pdf_table_builder.dart';
import 'flight_pdf_theme.dart';

/// Deterministic packing of analytics appendix sections onto pages.
class AnalyticsBlock {
  const AnalyticsBlock({
    required this.title,
    required this.content,
    required this.estimatedHeight,
  });

  final String title;
  final pw.Widget content;
  final double estimatedHeight;

  bool get isTrendSection =>
      title == 'Weekly Totals' ||
      title == 'Daily Totals' ||
      title == 'Monthly Totals';
}

class AnalyticsPagePlan {
  const AnalyticsPagePlan({required this.blocks});

  final List<AnalyticsBlock> blocks;
}

class FlightPdfAnalyticsLayout {
  FlightPdfAnalyticsLayout._();

  static const double blockSpacing = 14;

  /// Usable vertical space below compact header and above footer on A4 landscape.
  static const double pageUsableHeight = 420;

  static double estimateTableBlockHeight(
    int rowCount, {
    bool hasTotals = false,
    bool hasNote = false,
  }) {
    return FlightPdfTheme.analyticsLabelHeight +
        3 +
        FlightPdfTheme.tableHeaderHeight +
        rowCount * FlightPdfTheme.tableRowHeight +
        (hasTotals ? FlightPdfTheme.subtotalRowHeight : 0) +
        (hasNote ? 16 : 0);
  }

  static pw.Widget wrapBlock(AnalyticsBlock block) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        FlightPdfTableBuilder.analyticsBlockLabel(block.title),
        block.content,
      ],
    );
  }

  static List<AnalyticsPagePlan> planPages(List<AnalyticsBlock> blocks) {
    if (blocks.isEmpty) return [];

    final pages = <List<AnalyticsBlock>>[];
    var current = <AnalyticsBlock>[];
    var used = 0.0;

    void flush() {
      if (current.isNotEmpty) {
        pages.add(List.from(current));
        current = [];
        used = 0;
      }
    }

    for (final block in blocks) {
      final blockHeight = block.estimatedHeight + blockSpacing;
      if (current.isNotEmpty && used + blockHeight > pageUsableHeight) {
        flush();
      }
      current.add(block);
      used += blockHeight;
    }
    flush();

    _mergeOrphanTrendPage(pages);

    return [for (final page in pages) AnalyticsPagePlan(blocks: page)];
  }

  static double _pageHeight(List<AnalyticsBlock> pageBlocks) {
    var h = 0.0;
    for (final b in pageBlocks) {
      h += b.estimatedHeight + blockSpacing;
    }
    return h;
  }

  static void _mergeOrphanTrendPage(List<List<AnalyticsBlock>> pages) {
    if (pages.length < 2) return;

    final lastPage = pages.last;
    if (lastPage.length != 1 || !lastPage.first.isTrendSection) return;

    final prevPage = pages[pages.length - 2];
    final combined = _pageHeight(prevPage) + _pageHeight(lastPage);
    if (combined > pageUsableHeight * 1.05) return;

    pages[pages.length - 2] = [...prevPage, ...lastPage];
    pages.removeLast();
  }

  static List<pw.Widget> renderPage(AnalyticsPagePlan plan) {
    final widgets = <pw.Widget>[];
    for (var i = 0; i < plan.blocks.length; i++) {
      if (i > 0) widgets.add(pw.SizedBox(height: blockSpacing));
      widgets.add(wrapBlock(plan.blocks[i]));
    }
    return widgets;
  }
}
