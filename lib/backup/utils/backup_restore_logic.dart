/// Pure restore planning helpers (unit-testable).
class BackupRestoreLogic {
  BackupRestoreLogic._();

  /// Extract stable flight UUID from a backup entry value.
  static String? flightIdFromEntryValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      final id = value['id'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  /// Hive storage key must be the flight UUID (not an auto-increment index).
  static String storageKeyForFlight(String flightId) => flightId;

  /// Counts flights that would be written for this restore pass.
  static int countFlightsToApply({
    required Map<String, dynamic> backupFlightLogs,
    required Set<String> existingFlightIds,
    required bool merge,
  }) {
    final appliedIds = <String>{};
    var count = 0;

    for (final entry in backupFlightLogs.entries) {
      final flightId = flightIdFromEntryValue(entry.value);
      if (flightId == null || flightId.isEmpty) {
        continue;
      }

      if (merge) {
        if (existingFlightIds.contains(flightId) ||
            appliedIds.contains(flightId)) {
          continue;
        }
      }

      appliedIds.add(flightId);
      count++;
    }

    return count;
  }

  /// True when restoring the same backup twice in merge mode produces no new rows.
  static bool isDuplicateSafeMerge({
    required Map<String, dynamic> backupFlightLogs,
    required Set<String> existingFlightIds,
  }) {
    return countFlightsToApply(
          backupFlightLogs: backupFlightLogs,
          existingFlightIds: existingFlightIds,
          merge: true,
        ) ==
        0;
  }
}
