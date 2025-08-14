import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
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
  // Design tokens and constants
  static const _primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const _supportEmail = 'pilotn44@gmail.com';
  static const _supportWhatsAppNumber = '201117006878';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(localizations),
      body: Stack(
        children: [
          // Background decorative elements
          _buildBackgroundDecorations(),
          
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  _buildProfileSection(localizations),
                  
                  const SizedBox(height: 32),
                  
                  // Account Settings
                  _buildSectionTitle(localizations.accountSettings),
                  const SizedBox(height: 16),
                  _buildAccountSettingsCard(localizations),
                  
                  const SizedBox(height: 24),
                  
                  // App Preferences
                  _buildSectionTitle(localizations.appPreferences),
                  const SizedBox(height: 16),
                  _buildAppPreferencesCard(localizations),
                  
                  const SizedBox(height: 24),
                  
                  // Data & Storage
                  _buildSectionTitle(localizations.dataStorage),
                  const SizedBox(height: 16),
                  _buildDataStorageCard(localizations),
                  
                  const SizedBox(height: 24),
                  
                  // About Section
                  _buildSectionTitle(localizations.about),
                  const SizedBox(height: 16),
                  _buildAboutCard(localizations),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ App Bar ============
  AppBar _buildAppBar(AppLocalizations localizations) {
    return AppBar(
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
    );
  }

  // ============ Profile Section ============
  Widget _buildProfileSection(AppLocalizations localizations) {
    return Container(
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
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile Avatar
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
                ),
                child: AuthStateHelper.currentUser?.photoURL != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Image.network(
                          AuthStateHelper.currentUser!.photoURL!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.person_rounded, size: 45, color: Colors.white),
              ),
              
              const SizedBox(width: 24),
              
              // Profile Info
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
                            ),
                          ),
                        ),
                        if (AuthStateHelper.isEmailVerified)
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AuthStateHelper.email,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Profile Actions
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AuthStateHelper.isGoogleUser 
                          ? Icons.g_mobiledata_rounded 
                          : Icons.star_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AuthStateHelper.isGoogleUser 
                          ? localizations.googleAccount 
                          : localizations.premiumMember,
                        style: const TextStyle(color: Colors.white),
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
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Text(localizations.unverified, style: const TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(width: 12),
              GestureDetector(
                onTap: NavigationService.logout,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ Account Settings ============
  Widget _buildAccountSettingsCard(AppLocalizations localizations) {
    return _buildSettingsCard([
      _buildSettingsTile(
        icon: Icons.key_rounded,
        title: localizations.changePassword,
        subtitle: localizations.updatePassword,
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        ),
      ),
      
      _buildDivider(),
      
      // Placeholder for other account settings
      _buildSettingsTile(
        icon: Icons.security_rounded,
        title: "Security",
        subtitle: "Manage security settings",
        onTap: () {},
      ),
      
      if (!AuthStateHelper.isEmailVerified) ...[
        _buildDivider(),
        _buildSettingsTile(
          icon: Icons.mark_email_read_rounded,
          title: localizations.verifyEmail,
          subtitle: localizations.verifyEmailSubtitle,
          onTap: _sendEmailVerification,
          trailing: const Icon(Icons.warning_rounded, color: Colors.orange),
        ),
      ],
    ]);
  }

  // ============ App Preferences ============
  Widget _buildAppPreferencesCard(AppLocalizations localizations) {
    return _buildSettingsCard([
      _buildSettingsTile(
        icon: Icons.language_rounded,
        title: "Language",
        subtitle: "Choose your preferred language",
        onTap: () {},
      ),
    ]);
  }

  // ============ Data & Storage ============
  Widget _buildDataStorageCard(AppLocalizations localizations) {
    return _buildSettingsCard([
      _buildSettingsTile(
        icon: Icons.backup_rounded,
        title: "Backup",
        subtitle: "Manage your data backup",
        onTap: () {},
      ),
      
      _buildDivider(),
      
      _buildSettingsTile(
        icon: Icons.download_rounded,
        title: localizations.exportData,
        subtitle: localizations.exportDataSubtitle,
        onTap: _exportData,
      ),
    ]);
  }

  // ============ About Section ============
  Widget _buildAboutCard(AppLocalizations localizations) {
    return _buildSettingsCard([
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
      
      _buildDivider(),
      
      _buildSettingsTile(
        icon: Icons.support_agent_rounded,
        title: 'Contact Us',
        subtitle: 'Support • Feedback • Suggestions',
        onTap: _showContactSheet,
      ),
    ]);
  }

  // ============ Helper Widgets ============
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withOpacity(0.66),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3949ab), Color(0xFF5e35b1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              
              const SizedBox(width: 18),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[850],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(6),
                child: trailing ?? const Icon(Icons.chevron_right_rounded),
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
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x1464748B), Color(0x3364748B), Color(0x1464748B)],
        ),
      ),
    );
  }

  // ============ Contact Methods ============
  Future<void> _composeSupportEmail() async {
    final localizations = AppLocalizations.of(context)!;
    final userEmail = AuthStateHelper.email;
    final displayName = AuthStateHelper.displayName;
    
    final subject = 'FalconLog Support Request';
    final body = '''
Hello FalconLog Support Team,

I need assistance with:

[Please describe your issue here]

---
User Details:
Name: ${displayName.isNotEmpty ? displayName : 'Not provided'}
Email: $userEmail
App Version: v2.0.0 (Build 1)
Device: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
---
''';

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: Uri.encodeQueryComponent('subject=$subject&body=$body'),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: Platform.isAndroid 
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      } else {
        _showEmailCopyDialog(subject, body);
      }
    } catch (e) {
      _showEmailCopyDialog(subject, body);
    }
  }

  void _showEmailCopyDialog(String subject, String body) {
    final fullContent = '''
To: $_supportEmail
Subject: $subject

$body
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not open email app. Please copy this information:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(fullContent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullContent));
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy All'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final userEmail = AuthStateHelper.email;
    final displayName = AuthStateHelper.displayName;
    final message = '''
Hi FalconLog Support, 

I need help with...

User Details:
Name: ${displayName.isNotEmpty ? displayName : 'Not provided'}
Email: $userEmail
''';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = 'https://wa.me/$_supportWhatsAppNumber?text=$encodedMessage';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showContactSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contact Support',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Email Option
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email Support'),
              subtitle: const Text('Get detailed assistance'),
              onTap: () {
                Navigator.pop(context);
                _composeSupportEmail();
              },
            ),
            
            // WhatsApp Option
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp Chat'),
              subtitle: const Text('Quick response (recommended)'),
              onTap: () {
                Navigator.pop(context);
                _launchWhatsApp();
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============ Other Methods ============
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
          content: Text('Failed to send verification: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportData() async {
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export data feature coming soon')),
    );
  }

  // ============ Background Decorations ============
  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
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
      ],
    );
  }
}
