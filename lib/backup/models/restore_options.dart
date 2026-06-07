/// Options for restore operations
class RestoreOptions {
  final bool useDateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool replaceAll; // vs merge (for future)

  const RestoreOptions({
    this.useDateFilter = false,
    this.startDate,
    this.endDate,
    this.replaceAll = true,
  });

  /// Create options for restoring all data
  const RestoreOptions.all() : this(useDateFilter: false, replaceAll: true);

  /// Create options for restoring data within a date range
  RestoreOptions.dateRange({
    required DateTime start,
    required DateTime end,
  }) : this(
          useDateFilter: true,
          startDate: start,
          endDate: end,
          replaceAll: true,
        );

  /// Validate the restore options
  bool get isValid {
    if (useDateFilter) {
      if (startDate == null || endDate == null) {
        return false;
      }
      return startDate!.isBefore(endDate!) ||
          startDate!.isAtSameMomentAs(endDate!);
    }
    return true;
  }

  /// Get description of the filter
  String get filterDescription {
    if (!useDateFilter) {
      return 'All flight logs';
    }

    if (startDate != null && endDate != null) {
      return 'From ${_formatDate(startDate!)} to ${_formatDate(endDate!)}';
    }

    if (startDate != null) {
      return 'From ${_formatDate(startDate!)} onwards';
    }

    if (endDate != null) {
      return 'Up to ${_formatDate(endDate!)}';
    }

    return 'All flight logs';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Create a copy with updated fields
  RestoreOptions copyWith({
    bool? useDateFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool? replaceAll,
  }) {
    return RestoreOptions(
      useDateFilter: useDateFilter ?? this.useDateFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      replaceAll: replaceAll ?? this.replaceAll,
    );
  }

  @override
  String toString() {
    return 'RestoreOptions(useDateFilter: $useDateFilter, startDate: $startDate, endDate: $endDate, replaceAll: $replaceAll)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RestoreOptions &&
        other.useDateFilter == useDateFilter &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.replaceAll == replaceAll;
  }

  @override
  int get hashCode {
    return useDateFilter.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        replaceAll.hashCode;
  }
}
