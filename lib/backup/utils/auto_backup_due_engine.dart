/// Pure due-day logic for daily auto backup (23:59 local anchor).
class AutoBackupDueEngine {
  AutoBackupDueEngine._();

  /// Minutes from midnight; default 23:59 = 1439.
  static const int defaultDueMinuteOfDay = 23 * 60 + 59;

  /// Local calendar day id `yyyy-MM-dd`.
  static String dueDayId(DateTime local) {
    final d = DateTime(local.year, local.month, local.day);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  /// Local due instant for a calendar day.
  static DateTime dueInstantForDay(String dayId, int dueMinuteOfDay) {
    final parts = dayId.split('-');
    if (parts.length != 3) {
      throw ArgumentError.value(dayId, 'dayId', 'expected yyyy-MM-dd');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final hour = dueMinuteOfDay ~/ 60;
    final minute = dueMinuteOfDay % 60;
    return DateTime(year, month, day, hour, minute);
  }

  static int compareDueDays(String a, String b) => a.compareTo(b);

  /// Latest missed due day (collapsed): one backup for current state, not per missed day.
  static String? latestMissedDueDay({
    required DateTime nowLocal,
    required int dueMinuteOfDay,
    required String? lastSuccessDueDay,
  }) {
    var candidate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayId = dueDayId(candidate);
    if (nowLocal.isBefore(dueInstantForDay(todayId, dueMinuteOfDay))) {
      candidate = candidate.subtract(const Duration(days: 1));
    }

    final id = dueDayId(candidate);
    final due = dueInstantForDay(id, dueMinuteOfDay);
    if (nowLocal.isBefore(due)) {
      return null;
    }
    if (lastSuccessDueDay != null &&
        compareDueDays(id, lastSuccessDueDay) <= 0) {
      return null;
    }
    return id;
  }

  /// Next due boundary for UX (not exact execution time).
  static DateTime nextDueDateTime({
    required DateTime nowLocal,
    required int dueMinuteOfDay,
  }) {
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayId = dueDayId(today);
    final todayDue = dueInstantForDay(todayId, dueMinuteOfDay);
    if (nowLocal.isBefore(todayDue)) {
      return todayDue;
    }
    final tomorrow = today.add(const Duration(days: 1));
    return dueInstantForDay(dueDayId(tomorrow), dueMinuteOfDay);
  }

  static bool isDueDaySatisfied({
    required String? lastSuccessDueDay,
    required String pendingOrRunDueDay,
  }) {
    if (lastSuccessDueDay == null) return false;
    return compareDueDays(lastSuccessDueDay, pendingOrRunDueDay) >= 0;
  }
}
