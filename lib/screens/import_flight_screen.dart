import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/flight_data_sharing_service.dart';

class ImportFlightScreen extends ConsumerStatefulWidget {
  const ImportFlightScreen({super.key});

  @override
  ConsumerState<ImportFlightScreen> createState() =>
      _ImportFlightScreenState();
}

class _ImportFlightScreenState extends ConsumerState<ImportFlightScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _previewData;
  String? _selectedFilePath;

  Future<void> _pickFile() async {
    try {
      setState(() {
        _isLoading = true;
        _previewData = null;
        _selectedFilePath = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _selectedFilePath = file.path;

        if (_selectedFilePath != null) {
          // Get preview of the data
          final preview =
              await FlightDataSharingService.getImportPreview(_selectedFilePath!);
          setState(() {
            _previewData = preview;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importData(ImportMode mode) async {
    if (_selectedFilePath == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Import the data file
      final data =
          await FlightDataSharingService.importDataFile(_selectedFilePath!);

      // Process the imported data
      await FlightDataSharingService.processImportedData(
        data: data,
        mode: mode,
        ref: ref,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flight data imported successfully!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );

        // Close the import screen and return to previous screen
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showImportDialog() async {
    final result = await showDialog<ImportMode>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Flight Data'),
          content: const Text(
            'How would you like to import this data?\n\n'
            '• Replace: Remove all existing flights and replace with imported data\n'
            '• Integrate: Merge imported flights with existing flights (no duplicates)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.integrate),
              child: const Text('Integrate'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.replace),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _importData(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Flight Data',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a237e), Color(0xFF3949ab), Color(0xFF5e35b1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import FalconLog Data File',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select a FalconLog data file (.FLOG) to import flight logs into your app.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pick File Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_present, size: 24),
                      label: const Text(
                        'Select Data File',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3949ab),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // File Preview
                  if (_previewData != null) ...[
                    const Text(
                      'File Preview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewInfo(
                            'Flight Count',
                            '${_previewData!['flightCount']} flights',
                          ),
                          _buildPreviewInfo(
                            'App Version',
                            _previewData!['appVersion'],
                          ),
                          _buildPreviewInfo(
                            'Export Date',
                            DateTime.parse(_previewData!['exportDate'])
                                .toLocal()
                                .toString()
                                .split('.')[0],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Import Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _showImportDialog,
                        icon: const Icon(Icons.download, size: 24),
                        label: const Text(
                          'Import Data',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
