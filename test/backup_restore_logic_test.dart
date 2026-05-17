import 'package:flutter_test/flutter_test.dart';
import 'package:falconlog/backup/utils/backup_restore_logic.dart';

void main() {
  final sampleLogs = {
    'flight-a': {
      'id': 'flight-a',
      'date': '2025-01-10T00:00:00.000',
      'flightTypes': ['local'],
      'durationHours': 1,
      'durationMinutes': 0,
      'aircraftType': 'UH-60',
      'pilotRole': 'pic',
      'isDayFlight': true,
      'isSimulated': false,
      'createdAt': '2025-01-10T00:00:00.000',
    },
    'flight-b': {
      'id': 'flight-b',
      'date': '2025-02-10T00:00:00.000',
      'flightTypes': ['local'],
      'durationHours': 2,
      'durationMinutes': 0,
      'aircraftType': 'UH-60',
      'pilotRole': 'pic',
      'isDayFlight': true,
      'isSimulated': false,
      'createdAt': '2025-02-10T00:00:00.000',
    },
  };

  test('storage key uses flight UUID', () {
    expect(
      BackupRestoreLogic.storageKeyForFlight('uuid-123'),
      'uuid-123',
    );
  });

  test('merge skips existing UUIDs', () {
    final count = BackupRestoreLogic.countFlightsToApply(
      backupFlightLogs: sampleLogs,
      existingFlightIds: {'flight-a'},
      merge: true,
    );
    expect(count, 1);
  });

  test('restoring same backup twice in merge is duplicate-safe', () {
    expect(
      BackupRestoreLogic.isDuplicateSafeMerge(
        backupFlightLogs: sampleLogs,
        existingFlightIds: {'flight-a', 'flight-b'},
      ),
      isTrue,
    );
  });

  test('replace mode applies all flights', () {
    final count = BackupRestoreLogic.countFlightsToApply(
      backupFlightLogs: sampleLogs,
      existingFlightIds: {'flight-a', 'flight-b'},
      merge: false,
    );
    expect(count, 2);
  });
}
