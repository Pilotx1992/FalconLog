import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF styling aligned with FalconLog indigo brand — printable A4 landscape.
abstract final class FlightPdfTheme {
  static const double pageMargin = 40;
  static const double bodyFontSize = 9;
  static const double detailFontSize = 9;
  static const double headerFontSize = 9;
  static const double sectionTitleSize = 11;
  static const double titleFontSize = 14;
  static const double brandLabelSize = 10;
  static const double bannerTitleSize = 15;
  static const double bannerSubtitleSize = 8.5;
  static const double kpiCardValueSize = 14;
  static const double kpiCardLabelSize = 8;
  static const double tableRowHeight = 20;
  static const double tableHeaderHeight = 22;
  static const double subtotalRowHeight = 18;
  static const double compactBannerHeight = 30;
  static const double analyticsLabelHeight = 12;
  static const double footerFontSize = 7;

  static final PdfColor accent = PdfColor.fromInt(0xFF3949AB);
  static final PdfColor bodyText = PdfColor.fromInt(0xFF1E293B);
  static final PdfColor mutedText = PdfColor.fromInt(0xFF64748B);
  static final PdfColor headerBg = PdfColor.fromInt(0xFFF1F5F9);
  static final PdfColor headerText = PdfColor.fromInt(0xFF3949AB);
  static final PdfColor rowAlt = PdfColor.fromInt(0xFFF8FAFC);
  static final PdfColor border = PdfColor.fromInt(0xFFCBD5E1);
  static final PdfColor totalsBg = PdfColor.fromInt(0xFFE2E8F0);
  static final PdfColor footerGray = PdfColor.fromInt(0xFF64748B);
  static final PdfColor kpiLabel = PdfColor.fromInt(0xFF3949AB);

  static final PdfColor bannerBg = PdfColor.fromInt(0xFF3949AB);
  static final PdfColor bannerText = PdfColor.fromInt(0xFFFFFFFF);
  static final PdfColor bannerSubtitleText = PdfColor.fromInt(0xFFE8EAF6);

  static final PdfColor kpiCardTotalBg = PdfColor.fromInt(0xFFE8EAF6);
  static final PdfColor kpiCardTotalBorder = PdfColor.fromInt(0xFF3949AB);
  static final PdfColor kpiCardDayBg = PdfColor.fromInt(0xFFFFF8E1);
  static final PdfColor kpiCardDayBorder = PdfColor.fromInt(0xFFFFB300);
  static final PdfColor kpiCardNightBg = PdfColor.fromInt(0xFFE3F2FD);
  static final PdfColor kpiCardNightBorder = PdfColor.fromInt(0xFF42A5F5);

  static final PdfColor dateGroupBase = PdfColor.fromInt(0xFFFFFFFF);
  static final PdfColor dateGroupAlt = PdfColor.fromInt(0xFFF8FAFC);
  static final PdfColor subtotalText = PdfColor.fromInt(0xFF64748B);

  static pw.EdgeInsets get cellPadding =>
      const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2);

  static pw.TextStyle sectionTitle() => pw.TextStyle(
        fontSize: sectionTitleSize,
        fontWeight: pw.FontWeight.bold,
        color: bodyText,
      );

  static pw.TextStyle body({pw.FontWeight? weight, double? fontSize, PdfColor? color}) =>
      pw.TextStyle(
        fontSize: fontSize ?? bodyFontSize,
        fontWeight: weight,
        color: color ?? bodyText,
      );

  static pw.TextStyle headerCell() => pw.TextStyle(
        fontSize: headerFontSize,
        fontWeight: pw.FontWeight.bold,
        color: headerText,
      );

  static pw.TextStyle durationCell() => pw.TextStyle(
        fontSize: detailFontSize,
        fontWeight: pw.FontWeight.bold,
        color: bodyText,
      );

  static pw.TextStyle kpiLabelStyle() => pw.TextStyle(
        fontSize: kpiCardLabelSize,
        fontWeight: pw.FontWeight.normal,
        color: kpiLabel,
      );

  static pw.TextStyle kpiValueStyle() => pw.TextStyle(
        fontSize: kpiCardValueSize,
        fontWeight: pw.FontWeight.bold,
        color: bodyText,
      );

  static pw.TextStyle subtotalStyle() => pw.TextStyle(
        fontSize: bodyFontSize - 0.5,
        fontWeight: pw.FontWeight.normal,
        color: subtotalText,
      );

  static pw.TextStyle bannerTitleStyle() => pw.TextStyle(
        fontSize: bannerTitleSize,
        fontWeight: pw.FontWeight.bold,
        color: bannerText,
      );

  static pw.TextStyle bannerSubtitleStyle() => pw.TextStyle(
        fontSize: bannerSubtitleSize,
        fontWeight: pw.FontWeight.normal,
        color: bannerSubtitleText,
      );

  static pw.TextStyle analyticsLabelStyle() => pw.TextStyle(
        fontSize: bodyFontSize - 0.5,
        fontWeight: pw.FontWeight.bold,
        color: mutedText,
      );
}
