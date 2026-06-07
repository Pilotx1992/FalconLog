import '../../models/flight_log.dart';
import 'report_date_range.dart';

String flightTypeLabel(FlightType type) {
  switch (type) {
    case FlightType.local:
      return 'Local';
    case FlightType.mission:
      return 'Mission';
    case FlightType.xc:
      return 'Cross Country';
    case FlightType.zone:
      return 'Zone';
    case FlightType.range:
      return 'Range';
    case FlightType.formation:
      return 'Formation';
    case FlightType.currencyFlight:
      return 'Currency';
    case FlightType.landingGround:
      return 'Landing Ground';
    case FlightType.navalOps:
      return 'Naval OPS';
    case FlightType.lowLevel:
      return 'Low Level';
  }
}

String flightTypesLabel(List<FlightType> types) =>
    types.map(flightTypeLabel).join(', ');

String pilotRoleLabel(PilotRole role) {
  switch (role) {
    case PilotRole.ip:
      return 'IP';
    case PilotRole.mtp:
      return 'MTP';
    case PilotRole.pic:
      return 'PIC';
    case PilotRole.cpgGunner:
      return 'CPG';
    case PilotRole.wzo:
      return 'WZO';
  }
}

String flightConditionLabel(bool isDayFlight) => isDayFlight ? 'Day' : 'Night';

String flightModeLabel(bool isSimulated) =>
    isSimulated ? 'Simulator' : 'Actual';

String reportPeriodKindLabel(ReportPeriodKind kind) {
  switch (kind) {
    case ReportPeriodKind.allTime:
      return 'All time';
    case ReportPeriodKind.thisMonth:
      return 'This month';
    case ReportPeriodKind.thisYear:
      return 'This year';
    case ReportPeriodKind.custom:
      return 'Custom range';
  }
}
