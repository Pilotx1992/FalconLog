import 'package:flutter_test/flutter_test.dart';

import 'package:falconlog/backup/models/backup_payload_manifest.dart';
import 'package:falconlog/backup/utils/backup_payload_codec.dart';

void main() {
  group('backup compatibility', () {
    test('legacy flight-only payload validates without format version', () {
      final legacy = {
        BackupPayloadCodec.flightLogsKey: {
          'f-1': {
            'id': 'f-1',
            'date': '2025-01-01T00:00:00.000',
            'flightTypes': ['local'],
            'durationHours': 1,
            'durationMinutes': 0,
            'aircraftType': 'UH-60',
            'pilotRole': 'pic',
            'isDayFlight': true,
            'isSimulated': false,
            'createdAt': '2025-01-01T00:00:00.000',
          },
        },
      };

      expect(BackupPayloadCodec.validatePayload(legacy), isNull);
    });

    test('current format version is accepted', () {
      expect(
        BackupPayloadManifest.validateBackupFormatVersion({
          'backup_format_version':
              BackupPayloadManifest.currentBackupFormatVersion,
        }),
        isNull,
      );
    });

    test('newer unsupported format is rejected before restore', () {
      final payload = {
        'manifest': {
          'backup_format_version': '99.0',
          'schema_version': '4.0',
        },
        'flight_logs': {},
      };
      expect(
        BackupPayloadCodec.validatePayload(payload),
        BackupPayloadManifest.newerVersionErrorMessage,
      );
    });
  });
}
