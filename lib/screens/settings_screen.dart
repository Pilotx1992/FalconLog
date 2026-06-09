import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import '../services/navigation_service.dart';
import '../helpers/auth_state_helper.dart';
import '../providers/biometric_provider.dart';
import '../security/ui/settings_security_section.dart';
import '../notifications/ui/notification_settings_section.dart';
import '../settings/ui/settings_currency_alerts_section.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import 'change_password_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backup/ui/backup_settings_page.dart';
import '../providers/app_info_provider.dart';
import 'package:flutter/foundation.dart';

enum _SettingsSection {
  account,
  appPreferences,
  notifications,
  currencyAlerts,
  appLock,
  dataStorage,
  about,
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static final _logger = Logger('SettingsScreen');

  // Design tokens
  static const _tileGradient = LinearGradient(
    colors: [Color(0xFF3949ab), Color(0xFF5e35b1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _panelBackground = Color(0x66FFFFFF); // translucent
  static const _panelStroke = Color(0x33FFFFFF);
  static const _highlightColor = Color(0xFF6366F1);
  // Support contact details (international format number without + or leading zeros for WhatsApp API)
  static const String _supportWhatsAppNumber =
      '201117006878'; // User provided: 00201117006878
  static const String _supportEmail = 'pilotn44@gmail.com';

  _SettingsSection? _expandedSection;

  void _toggleSection(_SettingsSection section) {
    setState(() {
      _expandedSection = _expandedSection == section ? null : section;
    });
  }

  void _collapseAllSections() {
    if (_expandedSection != null) {
      setState(() => _expandedSection = null);
    }
  }

  // (Removed unused _dividerColor & _buildGradientBorder to satisfy analyzer)

  @override
  Widget build(BuildContext context) {
    final user = AuthStateHelper.currentUser;
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          localizations.settings,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
      body: Stack(
        children: [
          // decorative background gradients
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x336366F1), Color(0x006366F1)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x338B5CF6), Color(0x008B5CF6)],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _collapseAllSections,
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    GestureDetector(
                      onTap: _collapseAllSections,
                      child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF667eea),
                          Color(0xFF764ba2),
                          Color(0xFF8B5CF6)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withValues(alpha: 0.4),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: user?.photoURL != null
                                        ? Image.network(
                                            user!.photoURL!,
                                            fit: BoxFit.cover,
                                            width: 80,
                                            height: 80,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person_rounded,
                                                size: 40,
                                                color: Colors.white,
                                              );
                                            },
                                          )
                                        : const Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -6,
                                  right: -6,
                                  child: InkWell(
                                    onTap: () {},
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFF667eea)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.12),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          AuthStateHelper.displayName,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                            height: 1.15,
                                          ),
                                        ),
                                      ),
                                      if (AuthStateHelper.isEmailVerified)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.green
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.green
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.verified_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AuthStateHelper.email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (AuthStateHelper.isGoogleUser) ...[
                                      Image.asset(
                                        'assets/google.png',
                                        width: 20,
                                        height: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.googleAccount,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        localizations.premiumMember,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (!AuthStateHelper.isEmailVerified) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_rounded,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      localizations.unverified,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Sign out?'),
                                    content: const Text(
                                        'You will need to sign in again to access your data.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: Text(
                                          'Sign out',
                                          style: TextStyle(
                                              color: Colors.red.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                if (!context.mounted) return;
                                await NavigationService.logout();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    _buildCollapsibleSection(
                    icon: Icons.manage_accounts_rounded,
                    title: localizations.accountSettings,
                    isExpanded: _expandedSection == _SettingsSection.account,
                    onToggle: () => _toggleSection(_SettingsSection.account),
                    children: [
                      _buildSettingsTile(
                        icon: Icons.key_rounded,
                        title: localizations.changePassword,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),
                      if (!AuthStateHelper.isEmailVerified) ...[
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: Icons.mark_email_read_rounded,
                          title: localizations.verifyEmail,
                          subtitle: localizations.verifyEmailSubtitle,
                          onTap: () => _sendEmailVerification(),
                          trailing: const Icon(
                            Icons.warning_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildCollapsibleSection(
                    icon: Icons.tune_rounded,
                    title: localizations.appPreferences,
                    isExpanded:
                        _expandedSection == _SettingsSection.appPreferences,
                    onToggle: () =>
                        _toggleSection(_SettingsSection.appPreferences),
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final currentLanguage = ref.watch(languageProvider);
                          final isRTL = ref.watch(isRTLProvider);

                          return _buildLanguageTile(
                            currentLanguage: currentLanguage,
                            isRTL: isRTL,
                            onLanguageChanged: (language) {
                              ref
                                  .read(languageProvider.notifier)
                                  .setLanguage(language);
                              _showLanguageChangedSnackBar(
                                  language.nativeName);
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildCollapsibleSection(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    isExpanded:
                        _expandedSection == _SettingsSection.notifications,
                    onToggle: () =>
                        _toggleSection(_SettingsSection.notifications),
                    children: [
                      NotificationSettingsSection(
                        buildTile: ({
                          required icon,
                          required title,
                          String? subtitle,
                          onTap,
                          trailing,
                          bareTrailing = false,
                        }) =>
                            _buildSettingsTile(
                          icon: icon,
                          title: title,
                          subtitle: subtitle,
                          onTap: onTap ?? () {},
                          trailing: trailing,
                          bareTrailing: bareTrailing,
                        ),
                        buildDivider: _buildDivider,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildCollapsibleSection(
                    icon: Icons.schedule_rounded,
                    title: 'Currency Alerts',
                    isExpanded:
                        _expandedSection == _SettingsSection.currencyAlerts,
                    onToggle: () =>
                        _toggleSection(_SettingsSection.currencyAlerts),
                    children: [
                      SettingsCurrencyAlertsSection(
                        buildTile: ({
                          required icon,
                          required title,
                          String? subtitle,
                          onTap,
                          trailing,
                          bareTrailing = false,
                        }) =>
                            _buildSettingsTile(
                          icon: icon,
                          title: title,
                          subtitle: subtitle,
                          onTap: onTap ?? () {},
                          trailing: trailing,
                          bareTrailing: bareTrailing,
                        ),
                        buildDivider: _buildDivider,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildCollapsibleSection(
                    icon: Icons.lock_rounded,
                    title: 'App Lock',
                    isExpanded: _expandedSection == _SettingsSection.appLock,
                    onToggle: () => _toggleSection(_SettingsSection.appLock),
                    children: [
                      SettingsSecuritySection(
                        buildTile: ({
                          required icon,
                          required title,
                          String? subtitle,
                          onTap,
                          trailing,
                          bareTrailing = false,
                        }) =>
                            _buildSettingsTile(
                          icon: icon,
                          title: title,
                          subtitle: subtitle,
                          onTap: onTap ?? () {},
                          trailing: trailing,
                          bareTrailing: bareTrailing,
                        ),
                        buildDivider: _buildDivider,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildCollapsibleSection(
                    icon: Icons.storage_rounded,
                    title: localizations.dataStorage,
                    isExpanded: _expandedSection == _SettingsSection.dataStorage,
                    onToggle: () => _toggleSection(_SettingsSection.dataStorage),
                    children: [
                      _buildSettingsTile(
                        icon: Icons.backup_rounded,
                        title: 'Backup Settings',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BackupSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildCollapsibleSection(
                    icon: Icons.info_outline_rounded,
                    title: localizations.about,
                    isExpanded: _expandedSection == _SettingsSection.about,
                    onToggle: () => _toggleSection(_SettingsSection.about),
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final versionAsync = ref.watch(appVersionProvider);
                          final versionLabel = versionAsync.maybeWhen(
                            data: (v) => 'v$v',
                            orElse: () => '...',
                          );
                          return _buildSettingsTile(
                            icon: Icons.code_rounded,
                            title: localizations.version,
                            subtitle: versionLabel,
                            onTap: () {},
                            trailing: const SizedBox(),
                          );
                        },
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.person_pin_rounded,
                        title: localizations.developer,
                        subtitle: 'Pilot X',
                        onTap: () {},
                        trailing: const SizedBox(),
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Contact Us',
                        subtitle: 'Give Feedback',
                        onTap: _showContactSheet,
                      ),
                    ],
                  ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return _buildSettingsCard([
      _buildSectionHeaderRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        isExpanded: isExpanded,
        onToggle: onToggle,
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: isExpanded
            ? GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildSectionHeaderRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: isExpanded,
          header: true,
          label: title,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              splashColor: _highlightColor.withValues(alpha: 0.15),
              highlightColor: _highlightColor.withValues(alpha: 0.07),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.12),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _tileGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3949ab)
                                .withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 24, color: Colors.white),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: Colors.grey[850],
                            ),
                          ),
                          if (hasSubtitle) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded) _buildSectionSeparator(),
      ],
    );
  }

  Widget _buildSectionSeparator() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x1464748B), Color(0x4D64748B), Color(0x1464748B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: _panelBackground,
            border: Border.all(color: _panelStroke, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool bareTrailing = false,
  }) {
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.985, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: _highlightColor.withValues(alpha: 0.15),
          highlightColor: _highlightColor.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _tileGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3949ab).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18), width: 1),
                  ),
                  child: Icon(icon, size: 22, color: Colors.white),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: Colors.grey[850],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (bareTrailing)
                  trailing ?? const SizedBox()
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: trailing ??
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x1464748B), Color(0x3364748B), Color(0x1464748B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  Future<void> _sendEmailVerification() async {
    final localizations = AppLocalizations.of(context)!;

    try {
      await AuthStateHelper.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.verificationEmailSent),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send verification email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Language selection methods
  Widget _buildLanguageTile({
    required AppLanguage currentLanguage,
    required bool isRTL,
    required ValueChanged<AppLanguage> onLanguageChanged,
  }) {
    final localizations = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _showLanguageSelectionDialog(currentLanguage, onLanguageChanged),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3949ab), Color(0xFF5e35b1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRTL ? Icons.translate_rounded : Icons.language_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.language,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          currentLanguage.nativeName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (currentLanguage.code != 'en') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3949ab)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF3949ab)
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              currentLanguage.name,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF3949ab),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectionDialog(AppLanguage currentLanguage,
      ValueChanged<AppLanguage> onLanguageChanged) {
    final localizations = AppLocalizations.of(context)!;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.language_rounded,
                color: Color(0xFF3949ab), size: 24),
            const SizedBox(width: 12),
            Text(
              localizations.selectLanguage,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableLanguages.map((language) {
            final isSelected = language.code == currentLanguage.code;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (!mounted) return;
                  Navigator.pop(context);
                  onLanguageChanged(language);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3949ab).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3949ab).withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language.nativeName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF3949ab)
                                    : Colors.grey[800],
                              ),
                            ),
                            if (language.name != language.nativeName) ...[
                              const SizedBox(height: 2),
                              Text(
                                language.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF3949ab),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
  }

  void _showLanguageChangedSnackBar(String languageName) {
    final localizations = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.language_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              '${localizations.languageChanged} $languageName',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3949ab),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Legacy login-biometric Settings UI (hidden in PR3.1; LoginScreen unchanged).
  // ignore: unused_element
  Future<void> _handleBiometricToggle(
      WidgetRef ref, bool value, BiometricAvailability availability) async {
    final localizations = AppLocalizations.of(context)!;

    if (!availability.isFullyAvailable) {
      _showBiometricNotAvailableDialog(availability);
      return;
    }

    if (value) {
      // Enable biometric
      final setupNotifier = ref.read(biometricSetupProvider.notifier);
      await setupNotifier.setupBiometric();

      final setupState = ref.read(biometricSetupProvider);
      if (setupState.runtimeType.toString() == '_Success') {
        ref.read(biometricEnabledProvider.notifier).setBiometricEnabled(true);
        _showSuccessSnackBar(localizations.biometricEnabledMessage);
      } else if (setupState.runtimeType.toString() == '_Error') {
        final errorState = setupState as dynamic;
        _showErrorSnackBar(errorState.message ?? 'Unknown error occurred');
      }
    } else {
      // Disable biometric
      ref.read(biometricEnabledProvider.notifier).setBiometricEnabled(false);
      _showSuccessSnackBar(localizations.biometricDisabledMessage);
    }
  }

  // ignore: unused_element
  Widget _buildBiometricTile({
    required BiometricAvailability availability,
    required bool isEnabled,
    required BiometricSetupState setupState,
    required ValueChanged<bool> onChanged,
  }) {
    final localizations = AppLocalizations.of(context)!;
    final isLoading = setupState.runtimeType.toString() == '_Loading';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: availability.isFullyAvailable
                    ? [const Color(0xFF3949ab), const Color(0xFF5e35b1)]
                    : [Colors.grey[400]!, Colors.grey[500]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getBiometricIcon(availability.availableBiometrics),
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.biometricAuthentication,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  availability.isFullyAvailable
                      ? 'Active Biometric'
                      : availability.statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: availability.isFullyAvailable
                        ? Colors.grey[600]
                        : Colors.orange[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3949ab)),
              ),
            )
          else
            Switch.adaptive(
              value: isEnabled && availability.isFullyAvailable,
              onChanged: availability.isFullyAvailable ? onChanged : null,
              activeThumbColor: const Color(0xFF3949ab),
              activeTrackColor: const Color(0xFF3949ab).withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildBiometricLoadingTile() {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[400]!, Colors.grey[500]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.biometricAuthentication,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  localizations.checkingAvailability,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3949ab)),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildBiometricErrorTile(String error) {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[400]!, Colors.red[500]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.biometricAuthentication,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Error: $error',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.warning_rounded,
            color: Colors.red[400],
            size: 24,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  IconData _getBiometricIcon(List<dynamic> availableBiometrics) {
    // Convert to proper type and check for face ID
    final types = availableBiometrics.cast<dynamic>();

    if (types.any((type) => type.toString().contains('face'))) {
      return Icons.face_rounded;
    } else if (types.any((type) => type.toString().contains('fingerprint'))) {
      return Icons.fingerprint_rounded;
    } else {
      return Icons.security_rounded;
    }
  }

  // ignore: unused_element
  void _showBiometricNotAvailableDialog(BiometricAvailability availability) {
    final localizations = AppLocalizations.of(context)!;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Text(
              localizations.biometricNotAvailableTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              availability.statusMessage,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (!availability.hasEnrolledBiometrics &&
                availability.canCheckBiometrics)
              Text(
                localizations.biometricSetupInstructions,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Contact Us
  Future<void> _showContactSheet() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          // فتح شبه ممتد مع السماح بالتمرير الإضافي إذا احتاج (أزرار لن تُقص)
          initialChildSize: 0.60,
          maxChildSize: 0.85,
          minChildSize: 0.35,
          snap: true,
          snapSizes: const [0.60, 0.85],
          builder: (ctx, scrollController) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how you want to reach us',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _contactAction(
                          icon: Icons.email_rounded,
                          title: 'Email Support',
                          subtitle: _supportEmail,
                          color: const Color(0xFF6366F1),
                          onTap: _composeSupportEmail,
                        ),
                        _contactAction(
                          icon: Icons.chat_rounded,
                          title: 'WhatsApp Chat',
                          subtitle: 'Quick response (preferred)',
                          color: const Color(0xFF25D366),
                          onTap: () {
                            final userEmail = AuthStateHelper.email;
                            final display = AuthStateHelper.displayName;
                            final msg =
                                'Hi FalconLog Support, I need help with ...\nUser: ${display.isNotEmpty ? '$display ' : ''}<$userEmail>';
                            _launchWhatsApp(_supportWhatsAppNumber, msg);
                          },
                        ),
                        const SizedBox(height: 20),
                        // Removed Copy Contact Info button per request
                      ],
                    ),
                  ),
                  // Removed Close / Send Email buttons per request
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _contactAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_outward_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color.darken(),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color.darken(), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _composeSupportEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query:
          'subject=${Uri.encodeComponent('FalconLog Support Inquiry')}&body=${Uri.encodeComponent('Hello FalconLog Support,\n\nI need help with...\n\n\nUser: ${AuthStateHelper.displayName} <${AuthStateHelper.email}>')}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback if no email client is found
        _showEmailCopyDialog();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Could not launch email client: $e');
      _showEmailCopyDialog();
    }
  }

  void _showEmailCopyDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.email_rounded, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 8),
            Text('Contact Support',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
        content: const Text(
            'No email client found. Please install an email app to send support emails.',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(String number, String message) async {
    // Clean number
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    _logger.fine('WhatsApp number cleaned: $cleaned (original: $number)');

    try {
      // Method 1: WhatsApp URL scheme
      final whatsappScheme =
          'whatsapp://send?phone=$cleaned&text=${Uri.encodeComponent(message)}';
      final whatsappUri = Uri.parse(whatsappScheme);
      _logger.fine('WhatsApp scheme: $whatsappScheme');

      final canLaunchScheme = await canLaunchUrl(whatsappUri);
      _logger.fine('Can launch WhatsApp scheme: $canLaunchScheme');

      if (canLaunchScheme) {
        final launched =
            await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        _logger.fine('WhatsApp scheme launch result: $launched');
        if (launched) {
          _showSuccessSnackBar('تم فتح واتساب / WhatsApp opened');
          return;
        }
      }

      // Method 2: Web WhatsApp
      final webUrl =
          'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}';
      final webUri = Uri.parse(webUrl);
      _logger.fine('WhatsApp web: $webUrl');

      final canLaunchWeb = await canLaunchUrl(webUri);
      _logger.fine('Can launch WhatsApp web: $canLaunchWeb');

      if (canLaunchWeb) {
        final launched =
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
        _logger.fine('WhatsApp web launch result: $launched');
        if (launched) {
          _showSuccessSnackBar('تم فتح واتساب / WhatsApp opened');
          return;
        }
      }

      // Method 3: Try different modes
      final launched3 =
          await launchUrl(webUri, mode: LaunchMode.platformDefault);
      _logger.fine('WhatsApp platform default result: $launched3');
      if (launched3) {
        _showSuccessSnackBar('تم فتح واتساب / WhatsApp opened');
        return;
      }

      _showErrorSnackBar(
          'واتساب غير متاح - تأكد من تثبيت التطبيق / WhatsApp not available - check if app installed');
    } catch (e) {
      _logger.warning('WhatsApp error: $e');
      _showErrorSnackBar('خطأ في واتساب: $e');
    }
  }
}

// Simple color darken extension
extension _ColorShade on Color {
  Color darken([double amount = .18]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
