import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/navigation_service.dart';
import '../helpers/auth_state_helper.dart';
import '../providers/biometric_provider.dart';
import '../providers/language_provider.dart';
import '../providers/backup_provider.dart';
import '../services/backup_service.dart';
import '../widgets/backup_widgets_new.dart';
import '../localization/app_localizations.dart';
import 'change_password_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Design tokens
  static const _primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _tileGradient = LinearGradient(
    colors: [Color(0xFF3949ab), Color(0xFF5e35b1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _panelBackground = Color(0x66FFFFFF); // translucent
  static const _panelStroke = Color(0x33FFFFFF);
  static const _highlightColor = Color(0xFF6366F1);
  // Support contact details (international format number without + or leading zeros for WhatsApp API)
  static const String _supportWhatsAppNumber = '201117006878'; // User provided: 00201117006878
  static const String _supportEmail = 'pilotn44@gmail.com';

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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
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
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
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
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
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
                                        errorBuilder: (context, error, stackTrace) {
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
                                      colors: [Color(0xFF8B5CF6), Color(0xFF667eea)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
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
                                        color: Colors.green.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.3),
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
                                  color: Colors.white.withOpacity(0.85),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  AuthStateHelper.isGoogleUser ? Icons.g_mobiledata_rounded : Icons.star_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AuthStateHelper.isGoogleUser ? localizations.googleAccount : localizations.premiumMember,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!AuthStateHelper.isEmailVerified) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
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
                            await NavigationService.logout();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
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

              const SizedBox(height: 32),

              // Account Settings
              _buildSectionTitle(localizations.accountSettings),
              const SizedBox(height: 16),
              _buildSettingsCard([
                _buildSettingsTile(
                  icon: Icons.key_rounded,
                  title: localizations.changePassword,
                  subtitle: localizations.updatePassword,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                Consumer(
                  builder: (context, ref, child) {
                    final biometricEnabled = ref.watch(biometricEnabledProvider);
                    final biometricAvailability = ref.watch(biometricAvailabilityProvider);
                    final setupState = ref.watch(biometricSetupProvider);
                    
                    return biometricAvailability.when(
                      data: (availability) => _buildBiometricTile(
                        availability: availability,
                        isEnabled: biometricEnabled,
                        setupState: setupState,
                        onChanged: (value) => _handleBiometricToggle(ref, value, availability),
                      ),
                      loading: () => _buildBiometricLoadingTile(),
                      error: (error, stack) => _buildBiometricErrorTile(error.toString()),
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
              ]),

              const SizedBox(height: 24),

              // App Preferences
              _buildSectionTitle(localizations.appPreferences),
              const SizedBox(height: 16),
              _buildSettingsCard([
                Consumer(
                  builder: (context, ref, child) {
                    final currentLanguage = ref.watch(languageProvider);
                    final isRTL = ref.watch(isRTLProvider);
                    
                    return _buildLanguageTile(
                      currentLanguage: currentLanguage,
                      isRTL: isRTL,
                      onLanguageChanged: (language) {
                        ref.read(languageProvider.notifier).setLanguage(language);
                        _showLanguageChangedSnackBar(language.nativeName);
                      },
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // Data & Storage
              _buildSectionTitle(localizations.dataStorage),
              const SizedBox(height: 16),
              _buildSettingsCard([
                Consumer(
                  builder: (context, ref, child) {
                    final autoBackupEnabled = ref.watch(autoBackupEnabledProvider);
                    final backupProvider = ref.watch(backupProviderProvider);
                    final lastBackupAsync = ref.watch(lastBackupTimeProvider);
                    final backupStatus = ref.watch(backupStatusProvider);
                    final backupRecommendation = ref.watch(backupRecommendationProvider);
                    final isOnline = ref.watch(isOnlineProvider);
                    
                    return _buildAdvancedBackupTile(
                      isEnabled: autoBackupEnabled,
                      provider: backupProvider,
                      lastBackup: lastBackupAsync.valueOrNull,
                      status: backupStatus,
                      recommendation: backupRecommendation,
                      isOnline: isOnline,
                      onTap: () => _showBackupOptions(ref),
                    );
                  },
                ),
                _buildDivider(),
                Consumer(
                  builder: (context, ref, child) {
                    final backupHistoryAsync = ref.watch(backupHistoryProvider);
                    
                    return _buildSettingsTile(
                      icon: Icons.history_rounded,
                      title: 'Backup History',
                      subtitle: backupHistoryAsync.when(
                        data: (history) => '${history.length} backups available',
                        loading: () => 'Loading...',
                        error: (_, __) => 'Error loading history',
                      ),
                      onTap: () => _showBackupHistory(ref),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // About
              _buildSectionTitle(localizations.about),
              const SizedBox(height: 16),
              _buildSettingsCard([
                _buildSettingsTile(
                  icon: Icons.code_rounded,
                  title: localizations.version,
                  subtitle: 'v2.0.0',
                  onTap: () {},
                  trailing: const SizedBox(),
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
              ]),

              const SizedBox(height: 32),
            ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: _primaryGradient,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.grey[850],
            letterSpacing: 0.5,
          ),
        ),
      ],
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
                  color: Colors.black.withOpacity(0.05),
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
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
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
          splashColor: _highlightColor.withOpacity(0.15),
          highlightColor: _highlightColor.withOpacity(0.07),
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
                        color: const Color(0xFF3949ab).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
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
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: trailing ?? Icon(
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
        onTap: () => _showLanguageSelectionDialog(currentLanguage, onLanguageChanged),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3949ab).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF3949ab).withOpacity(0.3),
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

  void _showLanguageSelectionDialog(AppLanguage currentLanguage, ValueChanged<AppLanguage> onLanguageChanged) {
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
            const Icon(Icons.language_rounded, color: Color(0xFF3949ab), size: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? const Color(0xFF3949ab).withOpacity(0.1)
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                        ? const Color(0xFF3949ab).withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
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
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF3949ab) : Colors.grey[800],
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

  // Biometric authentication methods
  Future<void> _handleBiometricToggle(WidgetRef ref, bool value, BiometricAvailability availability) async {
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

  Widget _buildBiometricTile({
    required BiometricAvailability availability,
    required bool isEnabled,
    required BiometricSetupState setupState,
    required ValueChanged<bool> onChanged,
  }) {
    final localizations = AppLocalizations.of(context)!;
    final isLoading = setupState.runtimeType.toString() == '_Loading';
    final biometricName = availability.biometricTypeName;
    
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
                    ? '${localizations.useBiometric} $biometricName ${localizations.toSecureApp}'
                    : availability.statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: availability.isFullyAvailable ? Colors.grey[600] : Colors.orange[600],
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
              activeColor: const Color(0xFF3949ab),
            ),
        ],
      ),
    );
  }

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
            if (!availability.hasEnrolledBiometrics && availability.canCheckBiometrics)
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

  // Advanced Backup UI Methods
  Widget _buildAdvancedBackupTile({
    required bool isEnabled,
    required BackupProvider provider,
    required DateTime? lastBackup,
    required BackupStatus status,
    required BackupRecommendation recommendation,
    required bool isOnline,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                  _getBackupStatusIcon(status, provider),
                  size: 20,
                  color: Colors.white,
                ),
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
                            'Smart Backup',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSimpleProviderBadge(provider),
                        if (!isOnline) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'OFFLINE',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getBackupSubtitle(status, recommendation, lastBackup),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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
  
  // Simple Provider Badge that matches the settings UI
  Widget _buildSimpleProviderBadge(BackupProvider provider) {
    Color color;
    String name;
    
    switch (provider) {
      case BackupProvider.firebase:
        color = Colors.orange;
        name = 'CLOUD';
        break;
      case BackupProvider.local:
        color = Colors.blue;
        name = 'LOCAL';
        break;
      case BackupProvider.googleDrive:
        color = Colors.green;
        name = 'DRIVE';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  
  void _showBackupOptions(WidgetRef ref) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BackupOptionsBottomSheet(),
    );
  }
  
  void _showBackupHistory(WidgetRef ref) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BackupHistoryBottomSheet(),
    );
  }
  
  IconData _getBackupStatusIcon(BackupStatus status, BackupProvider provider) {
    if (status.toString().contains('BackingUp')) return Icons.backup_rounded;
    if (status.toString().contains('Restoring')) return Icons.restore_rounded;
    if (status.toString().contains('Deleting')) return Icons.delete_rounded;
    if (status.toString().contains('Success')) return Icons.check_circle_rounded;
    if (status.toString().contains('Error')) return Icons.error_rounded;
    
    // Default based on provider
    switch (provider) {
      case BackupProvider.firebase:
        return Icons.cloud_sync_rounded;
      case BackupProvider.local:
        return Icons.storage_rounded;
      case BackupProvider.googleDrive:
        return Icons.cloud_queue_rounded;
    }
  }
  
  String _getBackupSubtitle(BackupStatus status, BackupRecommendation recommendation, DateTime? lastBackup) {
    if (status.toString().contains('BackingUp')) return 'Creating backup...';
    if (status.toString().contains('Restoring')) return 'Restoring data...';
    if (status.toString().contains('Deleting')) return 'Deleting backup...';
    if (status.toString().contains('Success')) return 'Backup completed successfully';
    if (status.toString().contains('Error')) return 'Backup operation failed';
    
    // Base on recommendation when idle
    if (recommendation.toString().contains('Disabled')) return 'Auto backup is disabled';
    if (recommendation.toString().contains('FirstBackup')) return 'Create your first backup to secure your data';
    if (recommendation.toString().contains('Overdue')) return 'Backup overdue - action needed';
    if (recommendation.toString().contains('Recommended')) return 'Backup recommended';
    if (recommendation.toString().contains('Offline')) return 'Offline - Local backup only';
    if (recommendation.toString().contains('UpToDate')) {
      return lastBackup != null 
        ? 'Last backup: ${_formatTimeAgo(lastBackup)}'
        : 'Backup up to date';
    }
    if (recommendation.toString().contains('Loading')) return 'Checking backup status...';
    if (recommendation.toString().contains('Error')) return 'Error checking backup status';
    
    return 'Ready to backup';
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
                          final msg = 'Hi FalconLog Support, I need help with ...\nUser: '+
                            (display.isNotEmpty ? '$display ' : '') + '<$userEmail>';
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
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
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_outward_rounded, color: Colors.white),
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
      query: 'subject=${Uri.encodeComponent('FalconLog Support Inquiry')}&body=${Uri.encodeComponent('Hello FalconLog Support,\n\nI need help with...\n\n\nUser: ${AuthStateHelper.displayName} <${AuthStateHelper.email}>')}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback if no email client is found
        _showEmailCopyDialog();
      }
    } catch (e) {
      debugPrint('Could not launch email client: $e');
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
            Text('Contact Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy the email address and contact us:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _supportEmail,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _supportEmail));
                      if (!mounted) return;
                      Navigator.pop(context);
                      _showSuccessSnackBar('📋 تم نسخ الإيميل');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(String number, String message) async {
    // Clean number
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    print('DEBUG: WhatsApp number cleaned: $cleaned (original: $number)');
    
    try {
      // Method 1: WhatsApp URL scheme
      final whatsappScheme = 'whatsapp://send?phone=$cleaned&text=${Uri.encodeComponent(message)}';
      final whatsappUri = Uri.parse(whatsappScheme);
      print('DEBUG: WhatsApp scheme: $whatsappScheme');
      
      final canLaunchScheme = await canLaunchUrl(whatsappUri);
      print('DEBUG: Can launch WhatsApp scheme: $canLaunchScheme');
      
      if (canLaunchScheme) {
        final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        print('DEBUG: WhatsApp scheme launch result: $launched');
        if (launched) {
          _showSuccessSnackBar('تم فتح واتساب / WhatsApp opened');
          return;
        }
      }
      
      // Method 2: Web WhatsApp
      final webUrl = 'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}';
      final webUri = Uri.parse(webUrl);
      print('DEBUG: WhatsApp web: $webUrl');
      
      final canLaunchWeb = await canLaunchUrl(webUri);
      print('DEBUG: Can launch WhatsApp web: $canLaunchWeb');
      
      if (canLaunchWeb) {
        final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        print('DEBUG: WhatsApp web launch result: $launched');
        if (launched) {
          _showSuccessSnackBar('تم فتح واتساب / WhatsApp opened');
          return;
        }
      }
      
      // Method 3: Try different modes
      final launched3 = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      print('DEBUG: WhatsApp platform default result: $launched3');
      if (launched3) {
        _showSuccessSnackBar('تم فتح واتساب / WhatsApp opened');
        return;
      }
      
      _showErrorSnackBar('واتساب غير متاح - تأكد من تثبيت التطبيق / WhatsApp not available - check if app installed');
    } catch (e) {
      print('DEBUG: WhatsApp error: $e');
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
