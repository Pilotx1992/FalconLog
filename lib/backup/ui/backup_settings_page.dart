import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../services/backup_service.dart';
import '../utils/backup_scheduler.dart';
import 'backup_progress_sheet.dart';
import '../../providers/flight_logs_provider.dart';
import '../../services/flight_data_sharing_service.dart';

// Export RestoreMode for use in this file
export '../services/backup_service.dart' show RestoreMode;

class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  final BackupService _backupService = BackupService();
  final BackupScheduler _backupScheduler = BackupScheduler();

  bool _isLoading = true;
  DateTime? _lastBackupTime;
  GoogleSignInAccount? _currentUser;

  String _backupFrequency = 'off';
  bool _wifiOnly = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadSettings();
  }

  Future<void> _initializeAndLoadSettings() async {
    try {
      await _backupService.initialize();
      final backupMetadata = await _backupService.findExistingBackup();
      final frequency = await _backupScheduler.getBackupFrequency();
      final wifiOnly = await _backupScheduler.isWifiOnly();

      if (mounted) {
        setState(() {
          _currentUser = _backupService.currentUser;
          _lastBackupTime = backupMetadata?.createdAt;
          _backupFrequency = frequency;
          _wifiOnly = wifiOnly;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const headerGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0D2A45), Color(0xFF133A5A)],
    );

    final surfaceCard = isDark ? const Color(0xFF1C2B39) : Colors.white;
    final sectionTitleColor =
        isDark ? Colors.white.withValues(alpha: 0.92) : cs.onSurface;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1C28) : cs.surface,
      body: Stack(
        children: [
          // Header gradient background
          Container(
              height: 220,
              decoration: const BoxDecoration(gradient: headerGrad)),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    children: [
                      // Fixed Google Account Section
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new,
                                      size: 20),
                                  color: Colors.white,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Backup & Restore',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildAccountCard(surfaceCard, sectionTitleColor),
                          ],
                        ),
                      ),

                      // Scrollable Content
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          children: [
                            _buildAutoBackupCard(
                                surfaceCard, sectionTitleColor),
                            const SizedBox(height: 16),
                            _buildBackupActions(surfaceCard, sectionTitleColor),
                            const SizedBox(height: 16),
                            _buildDataManagement(
                                surfaceCard, sectionTitleColor),
                            const SizedBox(height: 22),
                            Center(
                              child: Text(
                                'All Backups Are end-to-end Encrypted (AES-256-GCM)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------- Google Account Card ----------------
  Widget _buildAccountCard(Color surfaceCard, Color sectionTitleColor) {
    final cs = Theme.of(context).colorScheme;
    final user = _currentUser;
    final isConnected = user != null;
    final hasBackup = _lastBackupTime != null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // الصورة في المنتصف
              Center(
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: user?.photoUrl == null
                      ? Icon(isConnected ? Icons.person : Icons.cloud_off,
                          color: cs.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // النصوص تلف حول الصورة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isConnected
                              ? (user.displayName?.isNotEmpty == true
                                  ? user.displayName!
                                  : 'Google User')
                              : 'Not connected',
                          style: TextStyle(
                              color: sectionTitleColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700),
                        ),
                        if (hasBackup) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: (isConnected && hasBackup)
                                  ? const Color(0xFF10B981)
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? user.email : 'Sign in to enable backup',
                      style: TextStyle(
                          color: sectionTitleColor.withValues(alpha: 0.65),
                          fontSize: 13),
                    ),
                    if (hasBackup) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last backup: ${_formatBackupTime(_lastBackupTime!)}',
                        style: TextStyle(
                            color: sectionTitleColor.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              // زر Choose account في المنتصف العمودي
              Align(
                alignment: Alignment.center,
                child: IconButton(
                  tooltip: 'Choose account',
                  icon: Icon(Icons.settings, color: cs.primary),
                  onPressed: _chooseAccount,
                ),
              ),
            ],
          ),
          if (!isConnected) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _signInToGoogle,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Auto Backup Card ----------------
  Widget _buildAutoBackupCard(Color surfaceCard, Color sectionTitleColor) {
    final cs = Theme.of(context).colorScheme;

    Widget row({
      required IconData icon,
      required String title,
      required Widget trailing,
      bool topDivider = false,
    }) {
      return Column(
        children: [
          if (topDivider)
            Divider(
                height: 1, color: sectionTitleColor.withValues(alpha: 0.12)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: sectionTitleColor.withValues(alpha: 0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        color: sectionTitleColor, fontWeight: FontWeight.w600),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Auto Backup',
              style: TextStyle(
                  color: sectionTitleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          row(
            icon: Icons.autorenew_rounded,
            title: 'Auto Backup',
            trailing: Switch.adaptive(
              value: _backupFrequency != 'off',
              onChanged: (v) => _onBackupFrequencyChanged(v ? 'daily' : 'off'),
              activeTrackColor: cs.primary,
            ),
          ),
          row(
            icon: Icons.calendar_today_outlined,
            title: 'Backup Frequency',
            topDivider: true,
            trailing: GestureDetector(
              onTap: _showFrequencySheet,
              child: Row(
                children: [
                  Text(
                    _backupFrequency == 'off'
                        ? 'Off'
                        : toBeginningOfSentenceCase(_backupFrequency)!,
                    style: TextStyle(
                        color: sectionTitleColor.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: sectionTitleColor),
                ],
              ),
            ),
          ),
          row(
            icon: Icons.wifi,
            title: 'Network',
            topDivider: true,
            trailing: GestureDetector(
              onTap: () => _onNetworkPreferenceChanged(!_wifiOnly),
              child: Row(
                children: [
                  Text(_wifiOnly ? 'Wi-Fi only' : 'Any network',
                      style: TextStyle(
                          color: sectionTitleColor.withValues(alpha: 0.75))),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: sectionTitleColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Cloud Backup Actions ----------------
  Widget _buildBackupActions(Color surfaceCard, Color sectionTitleColor) {
    final cs = Theme.of(context).colorScheme;
    final enabled = _currentUser != null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cloud Backup Actions',
              style: TextStyle(
                  color: sectionTitleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Opacity(
            opacity: enabled ? 1 : .55,
            child: GestureDetector(
              onTap: enabled ? _startBackupNow : null,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF40BEFF), Color(0xFF12C9B6)]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF12C9B6).withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Backup Now',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: enabled ? 1 : .55,
            child: OutlinedButton.icon(
              onPressed: enabled ? _startRestore : null,
              icon: Icon(Icons.restore, color: cs.primary),
              label: Text('Restore',
                  style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                side: BorderSide(color: cs.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Data Management ----------------
  Widget _buildDataManagement(Color surfaceCard, Color sectionTitleColor) {
    const orange = Color(0xFFFFA000);
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, color: orange),
              const SizedBox(width: 8),
              Text('Data Management',
                  style: TextStyle(
                      color: sectionTitleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _exportFlightData,
            icon: const Icon(Icons.upload, color: orange),
            label: const Text('Export Data',
                style: TextStyle(
                    color: orange, fontWeight: FontWeight.w700, fontSize: 15)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(
                  color: Color.fromARGB(255, 0, 166, 255), width: 1.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(45)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _importFlightData,
            icon: const Icon(Icons.file_download, color: Color(0xFF10B981)),
            label: const Text('Import Data',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(
                  color: Color.fromARGB(255, 0, 166, 255), width: 1.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(45)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Helpers & actions ----------------
  String _formatBackupTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, HH:mm').format(time);
  }

  Future<void> _showFrequencySheet() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final options = {
          'off': Icons.block_outlined,
          'daily': Icons.calendar_today_outlined,
          'weekly': Icons.view_week_outlined,
          'monthly': Icons.calendar_month_outlined,
        };
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: options.entries.map((e) {
              return ListTile(
                leading: Icon(e.value),
                title: Text(toBeginningOfSentenceCase(e.key)!),
                trailing: _backupFrequency == e.key
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(ctx).pop(e.key),
              );
            }).toList(),
          ),
        );
      },
    );

    if (value != null) _onBackupFrequencyChanged(value);
  }

  Future<void> _onBackupFrequencyChanged(String frequency) async {
    setState(() => _backupFrequency = frequency);
    await _backupScheduler.scheduleBackup(
        frequency: frequency, wifiOnly: _wifiOnly);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          frequency == 'off'
              ? 'Auto backup disabled'
              : 'Auto backup set to $frequency',
        ),
        backgroundColor: const Color(0xFF1A1F36),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onNetworkPreferenceChanged(bool wifiOnly) async {
    setState(() => _wifiOnly = wifiOnly);

    // Save the preference even if backup is off
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifi_only_backup', wifiOnly);

    // If backup is enabled, reschedule with new network preference
    if (_backupFrequency != 'off') {
      await _backupScheduler.scheduleBackup(
        frequency: _backupFrequency,
        wifiOnly: wifiOnly,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wifiOnly ? 'Wi-Fi only enabled' : 'All networks enabled'),
        backgroundColor: const Color(0xFF1A1F36),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startBackupNow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BackupProgressSheet(isRestore: false),
    );
  }

  void _startRestore() {
    // Always use merge mode to preserve existing data
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackupProgressSheet(
        isRestore: true,
        restoreMode: RestoreMode.merge,
        onRestoreComplete: _refreshAfterRestore,
      ),
    );
  }

  void _refreshAfterRestore() {
    ref.read(flightLogsProvider.notifier).refresh();
    _initializeAndLoadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Data restored successfully'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _signInToGoogle() async {
    try {
      await _backupService.initialize();
      if (!mounted) return;
      setState(() => _currentUser = _backupService.currentUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Open Google account chooser (without leaving the user signed out).
  Future<void> _chooseAccount() async {
    try {
      // أبسط طريقة مضمونة: signOut ثم signIn لعرض شاشة اختيار الحساب
      await _backupService.signOut();
      await _backupService.initialize();
      if (!mounted) return;
      setState(() => _currentUser = _backupService.currentUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not switch account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Export flight data to a shareable file
  Future<void> _exportFlightData() async {
    try {
      final flights = ref.read(flightLogsProvider).asData?.value ?? [];

      if (flights.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No flights to export'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await FlightDataSharingService.exportAllFlights(flights: flights);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${flights.length} flights exported successfully'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Import flight data directly with file picker
  Future<void> _importFlightData() async {
    try {
      // Step 1: Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select FalconLog Data File',
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        _showErrorSnackBar('Failed to read file path');
        return;
      }

      // Step 2: Get preview
      if (!mounted) return;
      _showLoadingDialog('Reading file...');

      final preview = await FlightDataSharingService.getImportPreview(filePath);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Step 3: Show preview and import mode dialog
      final shouldImport = await _showImportPreviewDialog(preview);
      if (shouldImport != true) return;

      // Step 4: Import data
      if (!mounted) return;
      _showLoadingDialog('Importing flights...');

      final data = await FlightDataSharingService.importDataFile(filePath);
      await FlightDataSharingService.processImportedData(
        data: data,
        mode: ImportMode.integrate, // Always integrate to avoid data loss
        ref: ref,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Step 5: Refresh and show success
      ref.read(flightLogsProvider.notifier).refresh();

      final flightCount = preview['flightCount'] as int;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$flightCount flights imported successfully'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Close any open dialogs
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Import failed: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showImportPreviewDialog(Map<String, dynamic> preview) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Color(0xFF10B981)),
            SizedBox(width: 12),
            Text('Import Flight Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File Preview:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildPreviewRow('Flight Count', '${preview['flightCount']} flights'),
            _buildPreviewRow('App Version', preview['appVersion'] ?? 'Unknown'),
            _buildPreviewRow(
              'Export Date',
              DateTime.parse(preview['exportDate'])
                  .toLocal()
                  .toString()
                  .split('.')[0],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Flights will be merged with existing data (no duplicates)',
                      style: TextStyle(fontSize: 13, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.download),
            label: const Text('Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
