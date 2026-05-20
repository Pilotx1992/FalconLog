import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_provider_enum.dart';
import '../services/backup_service.dart';
import '../utils/backup_constants.dart';
import '../utils/backup_scheduler.dart';
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
              const Icon(Icons.sd_storage_rounded,
                  color: _BackupColors.warning),
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
                    leading: const Icon(Icons.sd_storage_rounded,
                        color: _BackupColors.warning),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark
              ? _BackupColors.cardSurfaceDark
              : Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.restore_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text('Restore backup'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restore "${target.fileName}" from ${target.provider.displayName}. Choose how backup data is applied to this device.',
                  style: const TextStyle(height: 1.4),
                ),
                if (target.provider == BackupProvider.local) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _BackupColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _BackupColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: _BackupColors.warning, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a device-bound local backup. It will not restore on another phone.',
                            style: TextStyle(
                                color: _BackupColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (target.provider == BackupProvider.googleDrive) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cloud_done, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'After reinstall, sign in with the same Google account, then restore from Google Drive here.',
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Restore mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<RestoreMode>(
                  segments: const [
                    ButtonSegment(
                      value: RestoreMode.replace,
                      label: Text('Replace'),
                      icon: Icon(Icons.swap_horiz_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: RestoreMode.merge,
                      label: Text('Merge'),
                      icon: Icon(Icons.merge_rounded, size: 18),
                    ),
                  ],
                  selected: {selectedMode},
                  onSelectionChanged: (selection) {
                    setDialogState(() => selectedMode = selection.first);
                  },
                ),
                const SizedBox(height: 14),
                if (selectedMode == RestoreMode.replace) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Replace overwrites backed-up app data on this device after a safety snapshot is saved. This cannot be undone from the app.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  selectedMode == RestoreMode.replace
                      ? 'Use when this device should match the backup. FalconLog validates the file, saves a local safety snapshot, then applies the backup.'
                      : 'Use to add missing records from the backup. Matching IDs are updated; other existing records stay on this device.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('Restore'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    _startRestore(target: target, mode: selectedMode);
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
