import 'package:flutter/material.dart';
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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final user = AuthStateHelper.currentUser;
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
      body: SingleChildScrollView(
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
                        Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: user?.photoURL != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(21),
                                  child: Image.network(
                                    user!.photoURL!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person_rounded,
                                        size: 45,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 45,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 24),
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
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                        height: 1.2,
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
                              const SizedBox(height: 6),
                              Text(
                                AuthStateHelper.email,
                                style: TextStyle(
                                  fontSize: 15,
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
                                    fontSize: 14,
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
                _buildSettingsTile(
                  icon: Icons.download_rounded,
                  title: localizations.exportData,
                  subtitle: localizations.exportDataSubtitle,
                  onTap: () => _exportData(),
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
                  subtitle: 'v2.0.0 (Build 1)',
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
              ]),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.grey[800],
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: children,
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
                  icon,
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
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(
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

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.grey[200],
    );
  }

  Future<void> _sendEmailVerification() async {
    final localizations = AppLocalizations.of(context)!;
    
    try {
      await AuthStateHelper.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.verificationEmailSent),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BackupOptionsBottomSheet(),
    );
  }
  
  void _showBackupHistory(WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BackupHistoryBottomSheet(),
    );
  }
  
  Future<void> _exportData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon'),
        backgroundColor: Colors.blue,
      ),
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
}