import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/flight_log.dart';
import '../providers/flight_logs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightDataSharingService {
  static const String _fileExtension = '.FLOG';

  /// Export all flight logs to a shareable file
  static Future<void> exportAllFlights({
    required List<FlightLog> flights,
  }) async {
    try {
      // Create export data structure
      final exportData = {
        'appVersion': '1.0.0',
        'appName': 'FalconLog',
        'exportType': 'all',
        'exportDate': DateTime.now().toIso8601String(),
        'flightCount': flights.length,
        'flights': flights.map((flight) => _flightToJson(flight)).toList(),
      };

      // Create and share file with current date
      final now = DateTime.now();
      final dateString =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      await _createAndShareFile(
        data: exportData,
        filename: 'FalconLog_Export_$dateString',
      );
    } catch (e) {
      throw Exception('Failed to export flight data: $e');
    }
  }

  /// Convert FlightLog to JSON
  static Map<String, dynamic> _flightToJson(FlightLog flight) {
    return {
      'id': flight.id,
      'aircraftType': flight.aircraftType,
      'date': flight.date.toIso8601String(),
      'durationHours': flight.durationHours,
      'durationMinutes': flight.durationMinutes,
      'isDayFlight': flight.isDayFlight,
      'pilotRole': flight.pilotRole.name,
      'isSimulated': flight.isSimulated,
      'flightTypes': flight.flightTypes.map((e) => e.name).toList(),
      'createdAt': flight.createdAt.toIso8601String(),
      'updatedAt': flight.updatedAt?.toIso8601String() ??
          flight.createdAt.toIso8601String(),
    };
  }

  /// Convert JSON to FlightLog
  static FlightLog _jsonToFlight(Map<String, dynamic> json) {
    return FlightLog(
      id: json['id'] as String,
      aircraftType: json['aircraftType'] as String,
      date: DateTime.parse(json['date'] as String),
      durationHours: json['durationHours'] as int,
      durationMinutes: json['durationMinutes'] as int,
      isDayFlight: json['isDayFlight'] as bool,
      pilotRole: PilotRole.values.firstWhere(
        (e) => e.name == json['pilotRole'],
        orElse: () => PilotRole.pic,
      ),
      isSimulated: json['isSimulated'] as bool,
      flightTypes: (json['flightTypes'] as List)
          .map((e) => FlightType.values.firstWhere(
                (type) => type.name == e,
                orElse: () => FlightType.local,
              ))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Create and share the export file
  static Future<void> _createAndShareFile({
    required Map<String, dynamic> data,
    required String filename,
  }) async {
    try {
      // Get app directory
      final directory = await getApplicationDocumentsDirectory();

      // Delete all old export files before creating new one
      await _deleteOldExportFiles(directory);

      final filePath = '${directory.path}/$filename$_fileExtension';

      // Create file
      final file = File(filePath);
      final jsonString = json.encode(data);
      await file.writeAsString(jsonString);

      // Try to share file
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'FalconLog Flight Data - $filename',
          subject: 'FalconLog Data Export',
        );
      } catch (shareError) {
        // If sharing fails (e.g., on desktop platforms), inform user about file location
        if (kDebugMode) {
          debugPrint('Share failed, file saved to: $filePath');
        }
        // Rethrow with more helpful message
        throw Exception(
          'File saved successfully to:\n$filePath\n\n'
          'Note: Direct sharing is not available on this platform. '
          'Please locate the file in your documents folder and share it manually.',
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('File saved successfully')) {
        // This is our custom file location message, pass it through
        rethrow;
      } else {
        throw Exception('Failed to create and share file: $e');
      }
    }
  }

  /// Delete all old export files to keep only the latest one
  static Future<void> _deleteOldExportFiles(Directory directory) async {
    try {
      final files = directory.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith(_fileExtension)) {
          // Check if it's a FalconLog export file
          final filename = file.path.split(Platform.pathSeparator).last;
          if (filename.startsWith('FalconLog_Export_')) {
            await file.delete();
            if (kDebugMode) {
              debugPrint('Deleted old export file: $filename');
            }
          }
        }
      }
    } catch (e) {
      // Don't throw error if deletion fails, just log it
      if (kDebugMode) {
        debugPrint('Error deleting old export files: $e');
      }
    }
  }

  /// Import data file and return the parsed data
  static Future<Map<String, dynamic>> importDataFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File does not exist');
      }

      final jsonString = await file.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;

      // Validate file format
      if (!data.containsKey('appName') || data['appName'] != 'FalconLog') {
        throw Exception('Invalid FalconLog data file format');
      }

      if (!data.containsKey('exportType') || !data.containsKey('flights')) {
        throw Exception('Invalid FalconLog data file structure');
      }

      return data;
    } catch (e) {
      throw Exception('Failed to import data file: $e');
    }
  }

  /// Get preview of import file without importing
  static Future<Map<String, dynamic>> getImportPreview(String filePath) async {
    try {
      final data = await importDataFile(filePath);

      final flightCount = data['flightCount'] as int? ?? 0;
      final exportDate = data['exportDate'] as String;
      final appVersion = data['appVersion'] as String? ?? 'Unknown';

      return {
        'flightCount': flightCount,
        'exportDate': exportDate,
        'appVersion': appVersion,
      };
    } catch (e) {
      throw Exception('Failed to get import preview: $e');
    }
  }

  /// Process imported data and save to database
  static Future<void> processImportedData({
    required Map<String, dynamic> data,
    required ImportMode mode,
    required WidgetRef ref,
  }) async {
    try {
      final flightsData = data['flights'] as List;
      final importedFlights =
          flightsData.map((json) => _jsonToFlight(json)).toList();

      final notifier = ref.read(flightLogsProvider.notifier);

      if (mode == ImportMode.replace) {
        // Clear all existing flights first
        await notifier.clearAllFlights();

        // Add all imported flights
        for (final flight in importedFlights) {
          await notifier.addFlightLog(flight);
        }
      } else if (mode == ImportMode.integrate) {
        // Get existing flights
        final existingFlights =
            ref.read(flightLogsProvider).asData?.value ?? [];

        // Merge data (avoid duplicates by ID)
        for (final flight in importedFlights) {
          if (!existingFlights.any((e) => e.id == flight.id)) {
            await notifier.addFlightLog(flight);
          }
        }
      }

      debugPrint('Successfully imported ${importedFlights.length} flights');
    } catch (e) {
      throw Exception('Failed to process imported data: $e');
    }
  }
}

enum ImportMode {
  replace,
  integrate,
}
