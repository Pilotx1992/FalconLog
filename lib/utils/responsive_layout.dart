/// Shared breakpoints and spacing helpers for orientation-safe layouts.
const double kCompactHeightBreakpoint = 700;

/// True when vertical space is tight (landscape phones, short windows).
bool isCompactHeight(double height) => height < kCompactHeightBreakpoint;

/// Picks [compact] or [normal] vertical gap from available height.
double responsiveVerticalGap({
  required double maxHeight,
  required double normal,
  required double compact,
}) => isCompactHeight(maxHeight) ? compact : normal;

/// Picks [compact] or [normal] padding from available height.
double responsivePadding({
  required double maxHeight,
  required double normal,
  required double compact,
}) => isCompactHeight(maxHeight) ? compact : normal;
