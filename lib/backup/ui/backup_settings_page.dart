import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_provider_enum.dart';
import '../services/backup_service.dart';
import '../utils/backup_constants.dart';
import '../utils/backup_filename.dart';
import '../utils/backup_scheduler.dart';
import '../utils/backup_safety_export_helper.dart';
import '../utils/backup_safety_import_helper.dart';
import 'backup_progress_sheet.dart';
import '../../providers/backup_service_provider.dart';
import '../../providers/aircraft_types_provider.dart';
import '../../providers/flight_logs_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/app_snack_bar.dart';

export '../services/backup_service.dart' show RestoreMode;

/// Colors specific to the Backup UI to maintain the requested visual identity.
class _BackupColors {
  static const Color headerGradientStart = Color(0xFF0D2A45);
  static const Color headerGradientEnd = Color(0xFF133A5A);
  static const Color darkSurface = Color(0xFF0E1C28);
  static const Color cardSurfaceDark = Color(0xFF1C2B39);
  static const Color cloudGradientStart = Color(0xFF40BEFF);
  static const Color cloudGradientEnd = Color(0xFF12C9B6);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFA000);
}

class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  final BackupService _backupService = BackupService();
  final BackupScheduler _backupScheduler = BackupScheduler();

  bool _isLoading = true;
  DateTime? _lastGoogleDriveBackupTime;
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
      final backupMetadata = await _backupService.findExistingBackup(
        provider: BackupProvider.googleDrive,
      );
      final frequency = await _backupScheduler.getBackupFrequency();
      final wifiOnly = await _backupScheduler.isWifiOnly();
      await ref.read(backupHistoryProvider.notifier).refresh();

      if (mounted) {
        setState(() {
          _currentUser = _backupService.currentUser;
          _lastGoogleDriveBackupTime = backupMetadata?.createdAt;
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

    final operationRunning = ref.watch(isBackupInProgressProvider) ||
        ref.watch(isRestoreInProgressProvider);

    final surfaceCard = isDark ? _BackupColors.cardSurfaceDark : cs.surface;
    final sectionTitleColor =
        isDark ? Colors.white.withValues(alpha: 0.92) : cs.onSurface;

    return Scaffold(
      backgroundColor: isDark ? _BackupColors.darkSurface : cs.surface,
      body: Stack(
        children: [
          // Header Background Gradient
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _BackupColors.headerGradientStart,
                  _BackupColors.headerGradientEnd
                ],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    children: [
                      // Header Section
                      Padding(
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
                                const SizedBox(width: 48), // Balance alignment
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildAccountCard(surfaceCard, sectionTitleColor,
                                operationRunning),
                          ],
                        ),
                      ),
                      // Scrollable Content
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildAutoBackupCard(surfaceCard, sectionTitleColor,
                                operationRunning),
                            const SizedBox(height: 20),
                            _buildCloudBackupActions(surfaceCard,
                                sectionTitleColor, operationRunning),
                            const SizedBox(height: 20),
                            _buildLocalBackupActions(surfaceCard,
                                sectionTitleColor, operationRunning),
                            const SizedBox(height: 20),
                            _buildSafetyCopySection(surfaceCard,
                                sectionTitleColor, operationRunning),
                            const SizedBox(height: 32),
                            Center(
                              child: Text(
                                'Encrypted backups (AES-256-GCM)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
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

  Widget _buildAccountCard(
      Color surfaceCard, Color sectionTitleColor, bool operationRunning) {
    final cs = Theme.of(context).colorScheme;
    final user = _currentUser;
    final isConnected = user != null;
    final hasBackup = _lastGoogleDriveBackupTime != null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isConnected
                                ? (user.displayName?.isNotEmpty == true
                                    ? user.displayName!
                                    : 'Google User')
                                : 'Not connected',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sectionTitleColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (hasBackup) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _BackupColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? user.email : 'Sign in to enable backup',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sectionTitleColor.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                    if (hasBackup) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last backup: ${_formatBackupTime(_lastGoogleDriveBackupTime!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: sectionTitleColor.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Choose account',
                icon: Icon(Icons.settings, color: cs.primary),
                onPressed: operationRunning ? null : _chooseAccount,
              ),
            ],
          ),
          if (!isConnected) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: operationRunning ? null : _signInToGoogle,
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

  Widget _buildAutoBackupCard(
      Color surfaceCard, Color sectionTitleColor, bool operationRunning) {
    final cs = Theme.of(context).colorScheme;
    final autoBackupEnabled = _backupFrequency != 'off';

    Widget row({
      required IconData icon,
      required String title,
      required Widget trailing,
      bool topDivider = false,
      bool enabled = true,
      VoidCallback? onTap,
    }) {
      final titleStyle = TextStyle(
        color: enabled
            ? sectionTitleColor
            : sectionTitleColor.withValues(alpha: 0.38),
        fontWeight: FontWeight.w700,
      );
      final iconColor = enabled
          ? sectionTitleColor.withValues(alpha: 0.8)
          : sectionTitleColor.withValues(alpha: 0.32);

      return Column(
        children: [
          if (topDivider)
            Divider(
                height: 1, color: sectionTitleColor.withValues(alpha: 0.12)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, color: iconColor),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: titleStyle)),
                    trailing,
                  ],
                ),
              ),
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
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto Backup',
            style: TextStyle(
              color: sectionTitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          row(
            icon: Icons.autorenew_rounded,
            title: 'Enable',
            trailing: Switch.adaptive(
              value: autoBackupEnabled,
              onChanged: operationRunning
                  ? null
                  : (v) => _onBackupFrequencyChanged(v ? 'daily' : 'off'),
              activeTrackColor: cs.primary,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: autoBackupEnabled
                ? Column(
                    key: const ValueKey('auto_on'),
                    children: [
                      row(
                        icon: Icons.calendar_today_outlined,
                        title: 'Backup Frequency',
                        topDivider: true,
                        enabled: !operationRunning,
                        onTap: operationRunning ? null : _showFrequencySheet,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              toBeginningOfSentenceCase(_backupFrequency) ??
                                  _backupFrequency,
                              style: TextStyle(
                                color:
                                    sectionTitleColor.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right,
                              color: sectionTitleColor.withValues(alpha: 0.72),
                            ),
                          ],
                        ),
                      ),
                      row(
                        icon: Icons.wifi_rounded,
                        title: 'Network',
                        topDivider: true,
                        enabled: !operationRunning,
                        trailing: Switch.adaptive(
                          value: _wifiOnly,
                          onChanged: operationRunning
                              ? null
                              : _onNetworkPreferenceChanged,
                          activeTrackColor: cs.primary,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('auto_off')),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBackupActions(
      Color surfaceCard, Color sectionTitleColor, bool operationRunning) {
    final cs = Theme.of(context).colorScheme;
    final enabled = !operationRunning && _currentUser != null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_rounded,
                  color: _BackupColors.cloudGradientEnd),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Google Drive',
                  style: TextStyle(
                    color: sectionTitleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: enabled ? 1 : 0.55,
            child: GestureDetector(
              onTap: enabled ? _startGoogleDriveBackupNow : null,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      _BackupColors.cloudGradientStart,
                      _BackupColors.cloudGradientEnd
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _BackupColors.cloudGradientEnd
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
            opacity: enabled ? 1 : 0.55,
            child: OutlinedButton.icon(
              onPressed: enabled ? _confirmAndRestoreLatestGoogleDrive : null,
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

  Widget _buildLocalBackupActions(
      Color surfaceCard, Color sectionTitleColor, bool operationRunning) {
    final canOperate = !operationRunning;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder, color: _BackupColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Local Device',
                  style: TextStyle(
                    color: sectionTitleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: canOperate ? 1 : 0.55,
            child: OutlinedButton.icon(
              onPressed: canOperate ? _startLocalBackupNow : null,
              icon: const Icon(Icons.file_upload, color: _BackupColors.warning),
              label: const Text('Local Backup',
                  style: TextStyle(
                      color: _BackupColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side:
                    const BorderSide(color: _BackupColors.warning, width: 1.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: canOperate ? 1 : 0.55,
            child: OutlinedButton.icon(
              onPressed: canOperate ? _pickLocalBackupAndRestore : null,
              icon:
                  const Icon(Icons.file_download, color: _BackupColors.success),
              label: const Text('Local Restore',
                  style: TextStyle(
                      color: _BackupColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side:
                    const BorderSide(color: _BackupColors.success, width: 1.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCopySection(
      Color surfaceCard, Color sectionTitleColor, bool operationRunning) {
    final cs = Theme.of(context).colorScheme;
    final canOperate = !operationRunning;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: cs.primary.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Safety Copy (Testing)',
                  style: TextStyle(
                    color: sectionTitleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: canOperate ? 1 : 0.55,
            child: OutlinedButton.icon(
              onPressed: canOperate ? _exportSafetyCopy : null,
              icon: Icon(Icons.drive_folder_upload_outlined, color: cs.primary),
              label: Text('Export backup to folder',
                  style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(color: cs.primary, width: 1.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: canOperate ? 1 : 0.55,
            child: OutlinedButton.icon(
              onPressed: canOperate ? _importSafetyCopy : null,
              icon: const Icon(Icons.file_download_outlined,
                  color: _BackupColors.success),
              label: Text('Import backup from folder',
                  style: TextStyle(
                      color: _BackupColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: _BackupColors.success, width: 1.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark
          ? _BackupColors.cardSurfaceDark
          : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = {
          'off': Icons.block_outlined,
          'daily': Icons.calendar_today_outlined,
          'weekly': Icons.view_week_outlined,
          'monthly': Icons.calendar_month_outlined,
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Backup Frequency',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ...options.entries.map((e) {
                return ListTile(
                  leading: Icon(e.value),
                  title: Text(toBeginningOfSentenceCase(e.key)!),
                  trailing: _backupFrequency == e.key
                      ? const Icon(Icons.check_rounded,
                          color: _BackupColors.success)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(e.key),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (value != null) _onBackupFrequencyChanged(value);
  }

  Future<void> _onBackupFrequencyChanged(String frequency) async {
    final previousFrequency = _backupFrequency;
    setState(() => _backupFrequency = frequency);

    final scheduled = await _backupScheduler.scheduleBackup(
      frequency: frequency,
      wifiOnly: _wifiOnly,
    );

    if (!scheduled) {
      if (!mounted) return;
      setState(() => _backupFrequency = previousFrequency);
      _showErrorSnackBar('Could not update auto backup schedule');
      return;
    }

    if (!mounted) return;
    _showSuccessSnackBar(
      frequency == 'off'
          ? 'Auto backup disabled'
          : 'Auto backup set to $frequency',
    );
  }

  Future<void> _onNetworkPreferenceChanged(bool wifiOnly) async {
    final previousWifiOnly = _wifiOnly;

    setState(() => _wifiOnly = wifiOnly);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      BackupConstants.settingsKeys['wifi_only']!,
      wifiOnly,
    );

    if (_backupFrequency != 'off') {
      final scheduled = await _backupScheduler.scheduleBackup(
        frequency: _backupFrequency,
        wifiOnly: wifiOnly,
      );

      if (!scheduled) {
        // Revert both prefs and UI state so they stay in sync.
        await prefs.setBool(
          BackupConstants.settingsKeys['wifi_only']!,
          previousWifiOnly,
        );

        if (!mounted) return;
        setState(() => _wifiOnly = previousWifiOnly);
        _showErrorSnackBar('Could not update auto backup network setting');
        return;
      }
    }

    if (!mounted) return;
    _showSuccessSnackBar(
      wifiOnly ? 'Wi-Fi only enabled' : 'All networks enabled',
    );
  }

  void _startGoogleDriveBackupNow() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) => BackupProgressSheet(
        backupService: _backupService,
        backupProvider: BackupProvider.googleDrive,
        isRestore: false,
        onBackupComplete: () {
          ref.read(backupHistoryProvider.notifier).refresh();
          _initializeAndLoadSettings();
        },
      ),
    );
  }

  void _startLocalBackupNow() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) => BackupProgressSheet(
        backupService: _backupService,
        backupProvider: BackupProvider.local,
        isRestore: false,
        onBackupComplete: () {
          ref.read(backupHistoryProvider.notifier).refresh();
          _initializeAndLoadSettings();
        },
      ),
    );
  }

  Future<void> _importSafetyCopy() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose safety backup copy',
        type: FileType.custom,
        allowedExtensions: const ['crypt14'],
        withData: true,
      );

      if (!mounted) return;

      final loadOutcome =
          await BackupSafetyImportHelper.loadFromPickerResult(result);
      if (!loadOutcome.isSuccess || loadOutcome.candidate == null) {
        if (loadOutcome.isFailure) {
          _showErrorSnackBar(
            loadOutcome.errorMessage ?? 'Import failed. Please try again.',
          );
        }
        return;
      }

      final candidate = loadOutcome.candidate!;
      final mode = await _confirmAndRestoreSafetyCopy(candidate);
      if (mode != null && mounted) {
        _startSafetyCopyRestore(candidate: candidate, mode: mode);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Import failed: $e');
      }
    }
  }

  Future<RestoreMode?> _confirmAndRestoreSafetyCopy(
    BackupSafetyImportCandidate candidate,
  ) async {
    RestoreMode selectedMode = RestoreMode.replace;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    final dialogBg =
        isDark ? _BackupColors.cardSurfaceDark : theme.colorScheme.surface;
    final backupDate =
        DateFormat('dd MMM yyyy, HH:mm').format(
      BackupFilename.parseTimestampFromFileName(candidate.fileName) ??
          DateTime.now(),
    );

    return showDialog<RestoreMode>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = theme.colorScheme.primary;

          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Import safety copy',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open_rounded,
                          size: 22, color: _BackupColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'External file · $backupDate',
                              style: TextStyle(fontSize: 12.5, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _restoreModeOption(
                  mode: RestoreMode.replace,
                  selected: selectedMode,
                  title: 'Replace',
                  description: 'Make this device match the backup.',
                  accent: accent,
                  muted: muted,
                  onTap: () =>
                      setDialogState(() => selectedMode = RestoreMode.replace),
                ),
                const SizedBox(height: 10),
                _restoreModeOption(
                  mode: RestoreMode.merge,
                  selected: selectedMode,
                  title: 'Merge',
                  description: 'Add and update records; keep other local data.',
                  accent: accent,
                  muted: muted,
                  onTap: () =>
                      setDialogState(() => selectedMode = RestoreMode.merge),
                ),
                if (selectedMode == RestoreMode.replace) ...[
                  const SizedBox(height: 14),
                  Text(
                    'A safety copy is saved first. You cannot undo from the app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _BackupColors.warning.withValues(alpha: 0.95),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selectedMode),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportSafetyCopy() async {
    try {
      final candidate =
          await _backupService.resolveLatestExportableBackupForSafetyCopy(
        interactive: true,
      );
      if (!mounted) return;

      if (candidate == null) {
        _showErrorSnackBar(
          'Create a backup first, then export a safety copy.',
        );
        return;
      }

      final outcome = await BackupSafetyExportHelper.export(
        candidate: candidate,
        saveFile: ({required fileName, required bytes}) {
          return FilePicker.platform.saveFile(
            dialogTitle: 'Save safety backup copy',
            fileName: fileName,
            bytes: bytes,
            type: FileType.custom,
            allowedExtensions: const ['crypt14'],
          );
        },
      );

      if (!mounted) return;

      if (outcome.isSuccess) {
        _showSuccessSnackBar('Backup copy saved successfully.');
      } else if (outcome.isFailure) {
        _showErrorSnackBar(
          outcome.errorMessage ?? 'Export failed. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Export failed: $e');
      }
    }
  }

  Future<void> _confirmAndRestoreLatestGoogleDrive() async {
    final latest = await _backupService.resolveDefaultRestoreTarget(
      provider: BackupProvider.googleDrive,
    );
    if (!mounted) return;

    if (latest == null) {
      _showErrorSnackBar('No Google Drive backup found to restore.');
      return;
    }

    if (latest.provider != BackupProvider.googleDrive) {
      _showErrorSnackBar('Selected backup is not a Google Drive backup.');
      return;
    }

    await _confirmAndRestore(latest);
  }

  Future<void> _pickLocalBackupAndRestore() async {
    final localBackups = ref
        .read(backupHistoryProvider)
        .where((entry) => entry.provider == BackupProvider.local)
        .toList();

    if (localBackups.isEmpty) {
      final latest = await _backupService.resolveDefaultRestoreTarget(
        provider: BackupProvider.local,
      );
      if (!mounted) return;
      if (latest == null) {
        _showErrorSnackBar('No local backup found on this device.');
        return;
      }
      await _confirmAndRestore(latest);
      return;
    }

    if (localBackups.length == 1) {
      await _confirmAndRestore(localBackups.first);
      return;
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<BackupInfo>(
      context: context,
      backgroundColor: isDark
          ? _BackupColors.cardSurfaceDark
          : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Text(
                'Choose a local backup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: localBackups.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                itemBuilder: (context, index) {
                  final entry = localBackups[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading:
                        const Icon(Icons.folder, color: _BackupColors.warning),
                    title: Text(entry.fileName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${entry.formattedDate} · ${entry.logsCount} flights'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(ctx, entry),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      await _confirmAndRestore(selected);
    }
  }

  Future<void> _confirmAndRestore(BackupInfo target) async {
    RestoreMode selectedMode = RestoreMode.replace;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    final dialogBg =
        isDark ? _BackupColors.cardSurfaceDark : theme.colorScheme.surface;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = theme.colorScheme.primary;

          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Restore backup',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _restoreDialogBackupSummary(
                  target: target,
                  muted: muted,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                _restoreModeOption(
                  mode: RestoreMode.replace,
                  selected: selectedMode,
                  title: 'Replace',
                  description: 'Make this device match the backup.',
                  accent: accent,
                  muted: muted,
                  onTap: () =>
                      setDialogState(() => selectedMode = RestoreMode.replace),
                ),
                const SizedBox(height: 10),
                _restoreModeOption(
                  mode: RestoreMode.merge,
                  selected: selectedMode,
                  title: 'Merge',
                  description: 'Add and update records; keep other local data.',
                  accent: accent,
                  muted: muted,
                  onTap: () =>
                      setDialogState(() => selectedMode = RestoreMode.merge),
                ),
                if (selectedMode == RestoreMode.replace) ...[
                  const SizedBox(height: 14),
                  Text(
                    'A safety copy is saved first. You cannot undo from the app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _BackupColors.warning.withValues(alpha: 0.95),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;
    _startRestore(target: target, mode: selectedMode);
  }

  Widget _restoreDialogBackupSummary({
    required BackupInfo target,
    required Color muted,
    required bool isDark,
  }) {
    final providerIcon = target.provider == BackupProvider.googleDrive
        ? Icons.cloud_done_rounded
        : Icons.sd_storage_rounded;
    final providerColor = target.provider == BackupProvider.googleDrive
        ? _BackupColors.cloudGradientEnd
        : _BackupColors.warning;
    final panelFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: panelFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(providerIcon, size: 22, color: providerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${target.provider.displayName} · ${target.formattedDate}',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _restoreModeOption({
    required RestoreMode mode,
    required RestoreMode selected,
    required String title,
    required String description,
    required Color accent,
    required Color muted,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.55)
                  : muted.withValues(alpha: 0.22),
              width: isSelected ? 1.5 : 1,
            ),
            color: isSelected ? accent.withValues(alpha: 0.08) : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 22,
                color: isSelected ? accent : muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? accent : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSafetyCopyRestore({
    required BackupSafetyImportCandidate candidate,
    RestoreMode mode = RestoreMode.replace,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) => BackupProgressSheet(
        backupService: _backupService,
        isRestore: true,
        restoreMode: mode,
        safetyImportCandidate: candidate,
        onRestoreComplete: _refreshAfterRestore,
      ),
    );
  }

  void _startRestore({
    required BackupInfo target,
    RestoreMode mode = RestoreMode.replace,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) => BackupProgressSheet(
        backupService: _backupService,
        isRestore: true,
        restoreMode: mode,
        restoreTarget: target,
        onRestoreComplete: _refreshAfterRestore,
      ),
    );
  }

  void _refreshAfterRestore() {
    ref.read(flightLogsProvider.notifier).refresh();
    ref.read(aircraftTypesProvider.notifier).reload();
    ref.read(languageProvider.notifier).reloadFromPrefs();
    ref.read(backupHistoryProvider.notifier).refresh();
    _initializeAndLoadSettings();
    if (!mounted) return;
    _showSuccessSnackBar('Data restored successfully');
  }

  Future<void> _signInToGoogle() async {
    try {
      await _backupService.initialize();
      if (!mounted) return;
      setState(() => _currentUser = _backupService.currentUser);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Sign in failed: $e');
    }
  }

  Future<void> _chooseAccount() async {
    try {
      await _backupService.signOut();
      await _backupService.initialize();
      if (!mounted) return;
      setState(() => _currentUser = _backupService.currentUser);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not switch account: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _BackupColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: AppSnackBar.success,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: AppSnackBar.error,
      ),
    );
  }
}
