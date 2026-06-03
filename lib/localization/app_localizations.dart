import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App Bar Titles
      'settings': 'Settings',
      'dashboard': 'Dashboard',
      'log_flight': 'Log Flight',
      'summary': 'Summary',
      'advanced_stats': 'Advanced Statistics',
      'all_flights': 'All Flights',

      // Settings Screen
      'account_settings': 'Account Settings',
      'app_preferences': 'App Preferences',
      'data_storage': 'Data & Storage',
      'about': 'About',

      // Account Settings
      'change_password': 'Change Password',
      'update_password': 'Update your password',
      'biometric_auth': 'Biometric Authentication',
      'biometric_subtitle': 'Use fingerprint to secure app',
      'verify_email': 'Verify Email',
      'verify_email_subtitle': 'Verify your email address',

      // App Preferences
      'language': 'Language',
      'select_language': 'Select Language',
      'language_changed': 'Language changed to',

      // Data & Storage
      'auto_backup': 'Auto Backup',
      'auto_backup_subtitle': 'Automatically backup your data',
      'export_data': 'Export Data',
      'export_data_subtitle': 'Download your flight logs',

      // About
      'version': 'Version',
      'developer': 'Developer',

      // Profile
      'google_account': 'Google Account',
      'premium_member': 'Premium Member',
      'unverified': 'Unverified',

      // Common
      'cancel': 'Cancel',
      'ok': 'OK',
      'sign_out': 'Sign Out',
      'sign_out_confirmation': 'Are you sure you want to sign out?',
      'sign_out_success': 'Signed out successfully',
      'verification_email_sent': 'Verification email sent!',
      'biometric_enabled': 'Enabled Successfully!',
      'biometric_disabled': 'Biometric authentication disabled',
      'biometric_enabled_message': 'Enabled Successfully!',
      'biometric_disabled_message': 'Biometric authentication disabled',
      'biometric_not_available_title': 'Biometric Not Available',
      'biometric_setup_instructions':
          'To enable biometric authentication:\n1. Go to device Settings\n2. Set up fingerprint or face unlock\n3. Return to FalconLog to enable',
      'biometric_authentication': 'Biometric Authentication',
      'use_biometric': 'Use',
      'to_secure_app': 'to secure app',
      'checking_availability': 'Checking availability...',

      // Dashboard
      'total_flights': 'Total Flights',
      'total_hours': 'Total Hours',
      'last_flight': 'Last Flight',
      'currency_status': 'Currency Status',
      'recent_flights': 'Recent Flights',
      'quick_actions': 'Quick Actions',
      'view_all': 'View All',

      // Flight Log
      'aircraft_type': 'Aircraft Type',
      'flight_date': 'Flight Date',
      'departure': 'Departure',
      'arrival': 'Arrival',
      'flight_time': 'Flight Time',
      'pilot_role': 'Pilot Role',
      'remarks': 'Remarks',
      'save_flight': 'Save Flight',

      // Summary
      'flight_summary': 'Flight Summary',
      'this_month': 'This Month',
      'this_year': 'This Year',
      'lifetime': 'Lifetime',

      // Advanced Stats
      'flight_distribution': 'Flight Distribution',
      'monthly_trends': 'Monthly Trends',
      'aircraft_usage': 'Aircraft Usage',
      'pilot_experience': 'Pilot Experience',
    },
    'ar': {
      // App Bar Titles
      'settings': 'الإعدادات',
      'dashboard': 'لوحة التحكم',
      'log_flight': 'تسجيل طيران',
      'summary': 'الملخص',
      'advanced_stats': 'إحصائيات متقدمة',
      'all_flights': 'جميع الطيرات',

      // Settings Screen
      'account_settings': 'إعدادات الحساب',
      'app_preferences': 'تفضيلات التطبيق',
      'data_storage': 'البيانات والتخزين',
      'about': 'حول',

      // Account Settings
      'change_password': 'تغيير كلمة المرور',
      'update_password': 'تحديث كلمة مرور حسابك',
      'biometric_auth': 'المصادقة البيومترية',
      'biometric_subtitle': 'استخدم بصمة الإصبع لتأمين التطبيق',
      'verify_email': 'تأكيد البريد الإلكتروني',
      'verify_email_subtitle': 'تأكيد عنوان بريدك الإلكتروني',

      // App Preferences
      'language': 'اللغة',
      'select_language': 'اختيار اللغة',
      'language_changed': 'تم تغيير اللغة إلى',

      // Data & Storage
      'auto_backup': 'النسخ الاحتياطي التلقائي',
      'auto_backup_subtitle': 'نسخ احتياطي تلقائي لبياناتك',
      'export_data': 'تصدير البيانات',
      'export_data_subtitle': 'تحميل سجلات طياراتك',

      // About
      'version': 'الإصدار',
      'developer': 'المطور',

      // Profile
      'google_account': 'حساب جوجل',
      'premium_member': 'عضو مميز',
      'unverified': 'غير مؤكد',

      // Common
      'cancel': 'إلغاء',
      'ok': 'موافق',
      'sign_out': 'تسجيل الخروج',
      'sign_out_confirmation': 'هل أنت متأكد من تسجيل الخروج؟',
      'sign_out_success': 'تم تسجيل الخروج بنجاح',
      'verification_email_sent': 'تم إرسال بريد التأكيد!',
      'biometric_enabled': 'تم تفعيل المصادقة البيومترية بنجاح!',
      'biometric_disabled': 'تم إلغاء تفعيل المصادقة البيومترية',
      'biometric_enabled_message': 'تم تفعيل المصادقة البيومترية بنجاح!',
      'biometric_disabled_message': 'تم إلغاء تفعيل المصادقة البيومترية',
      'biometric_not_available_title': 'المصادقة البيومترية غير متاحة',
      'biometric_setup_instructions':
          'لتفعيل المصادقة البيومترية:\n1. اذهب إلى إعدادات الجهاز\n2. قم بإعداد بصمة الإصبع أو إلغاء القفل بالوجه\n3. عد إلى FalconLog للتفعيل',
      'biometric_authentication': 'المصادقة البيومترية',
      'use_biometric': 'استخدم',
      'to_secure_app': 'لتأمين التطبيق',
      'checking_availability': 'جاري التحقق من التوفر...',

      // Dashboard
      'total_flights': 'إجمالي الطيرات',
      'total_hours': 'إجمالي الساعات',
      'last_flight': 'آخر طيران',
      'currency_status': 'حالة الصلاحية',
      'recent_flights': 'طيرات حديثة',
      'quick_actions': 'إجراءات سريعة',
      'view_all': 'عرض الكل',

      // Flight Log
      'aircraft_type': 'نوع الطائرة',
      'flight_date': 'تاريخ الطيران',
      'departure': 'المغادرة',
      'arrival': 'الوصول',
      'flight_time': 'وقت الطيران',
      'pilot_role': 'دور الطيار',
      'remarks': 'ملاحظات',
      'save_flight': 'حفظ الطيران',

      // Summary
      'flight_summary': 'ملخص الطيرات',
      'this_month': 'هذا الشهر',
      'this_year': 'هذا العام',
      'lifetime': 'مدى الحياة',

      // Advanced Stats
      'flight_distribution': 'توزيع الطيرات',
      'monthly_trends': 'الاتجاهات الشهرية',
      'aircraft_usage': 'استخدام الطائرات',
      'pilot_experience': 'خبرة الطيار',
    },
    'fr': {
      // App Bar Titles
      'settings': 'Paramètres',
      'dashboard': 'Tableau de bord',
      'log_flight': 'Enregistrer le vol',
      'summary': 'Résumé',
      'advanced_stats': 'Statistiques avancées',
      'all_flights': 'Tous les vols',

      // Settings Screen
      'account_settings': 'Paramètres du compte',
      'app_preferences': 'Préférences de l\'application',
      'data_storage': 'Données et stockage',
      'about': 'À propos',

      // Account Settings
      'change_password': 'Changer le mot de passe',
      'update_password': 'Mettre à jour votre mot de passe',
      'biometric_auth': 'Authentification biométrique',
      'biometric_subtitle': 'Utiliser l\'empreinte pour sécuriser l\'app',
      'verify_email': 'Vérifier l\'email',
      'verify_email_subtitle': 'Vérifiez votre adresse email',

      // App Preferences
      'language': 'Langue',
      'select_language': 'Sélectionner la langue',
      'language_changed': 'Langue changée en',

      // Data & Storage
      'auto_backup': 'Sauvegarde automatique',
      'auto_backup_subtitle': 'Sauvegarder automatiquement vos données',
      'export_data': 'Exporter les données',
      'export_data_subtitle': 'Télécharger vos journaux de vol',

      // About
      'version': 'Version',
      'developer': 'Développeur',

      // Profile
      'google_account': 'Compte Google',
      'premium_member': 'Membre Premium',
      'unverified': 'Non vérifié',

      // Common
      'cancel': 'Annuler',
      'ok': 'OK',
      'sign_out': 'Se déconnecter',
      'sign_out_confirmation': 'Êtes-vous sûr de vouloir vous déconnecter?',
      'sign_out_success': 'Déconnecté avec succès',
      'verification_email_sent': 'Email de vérification envoyé!',
      'biometric_enabled': 'Authentification biométrique activée!',
      'biometric_disabled': 'Authentification biométrique désactivée',
      'biometric_enabled_message':
          'Authentification biométrique activée avec succès!',
      'biometric_disabled_message': 'Authentification biométrique désactivée',
      'biometric_not_available_title': 'Biométrie non disponible',
      'biometric_setup_instructions':
          'Pour activer l\'authentification biométrique:\n1. Accédez aux paramètres de l\'appareil\n2. Configurez l\'empreinte digitale ou le déverrouillage facial\n3. Revenez à FalconLog pour l\'activer',
      'biometric_authentication': 'Authentification biométrique',
      'use_biometric': 'Utiliser',
      'to_secure_app': 'pour sécuriser l\'app',
      'checking_availability': 'Vérification de la disponibilité...',
    },
    'es': {
      // App Bar Titles
      'settings': 'Configuración',
      'dashboard': 'Panel de control',
      'log_flight': 'Registrar vuelo',
      'summary': 'Resumen',
      'advanced_stats': 'Estadísticas avanzadas',
      'all_flights': 'Todos los vuelos',

      // Settings Screen
      'account_settings': 'Configuración de cuenta',
      'app_preferences': 'Preferencias de la aplicación',
      'data_storage': 'Datos y almacenamiento',
      'about': 'Acerca de',

      // Account Settings
      'change_password': 'Cambiar contraseña',
      'update_password': 'Actualizar tu contraseña',
      'biometric_auth': 'Autenticación biométrica',
      'biometric_subtitle': 'Usar huella para asegurar la app',
      'verify_email': 'Verificar email',
      'verify_email_subtitle': 'Verifica tu dirección de email',

      // App Preferences
      'language': 'Idioma',
      'select_language': 'Seleccionar idioma',
      'language_changed': 'Idioma cambiado a',

      // Data & Storage
      'auto_backup': 'Respaldo automático',
      'auto_backup_subtitle': 'Respaldar automáticamente tus datos',
      'export_data': 'Exportar datos',
      'export_data_subtitle': 'Descargar tus registros de vuelo',

      // About
      'version': 'Versión',
      'developer': 'Desarrollador',

      // Profile
      'google_account': 'Cuenta de Google',
      'premium_member': 'Miembro Premium',
      'unverified': 'No verificado',

      // Common
      'cancel': 'Cancelar',
      'ok': 'OK',
      'sign_out': 'Cerrar sesión',
      'sign_out_confirmation': '¿Estás seguro de cerrar sesión?',
      'sign_out_success': 'Sesión cerrada exitosamente',
      'verification_email_sent': '¡Email de verificación enviado!',
      'biometric_enabled': '¡Autenticación biométrica habilitada!',
      'biometric_disabled': 'Autenticación biométrica deshabilitada',
      'biometric_enabled_message':
          '¡Autenticación biométrica habilitada con éxito!',
      'biometric_disabled_message': 'Autenticación biométrica deshabilitada',
      'biometric_not_available_title': 'Biometría no disponible',
      'biometric_setup_instructions':
          'Para habilitar la autenticación biométrica:\n1. Ve a la configuración del dispositivo\n2. Configura la huella dactilar o desbloqueo facial\n3. Regresa a FalconLog para habilitar',
      'biometric_authentication': 'Autenticación biométrica',
      'use_biometric': 'Usar',
      'to_secure_app': 'para asegurar la app',
      'checking_availability': 'Verificando disponibilidad...',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Convenience getters for common translations
  String get settings => translate('settings');
  String get dashboard => translate('dashboard');
  String get logFlight => translate('log_flight');
  String get summary => translate('summary');
  String get advancedStats => translate('advanced_stats');
  String get allFlights => translate('all_flights');

  String get accountSettings => translate('account_settings');
  String get appPreferences => translate('app_preferences');
  String get dataStorage => translate('data_storage');
  String get about => translate('about');

  String get changePassword => translate('change_password');
  String get updatePassword => translate('update_password');
  String get biometricAuth => translate('biometric_auth');
  String get biometricSubtitle => translate('biometric_subtitle');
  String get verifyEmail => translate('verify_email');
  String get verifyEmailSubtitle => translate('verify_email_subtitle');

  String get language => translate('language');
  String get selectLanguage => translate('select_language');
  String get languageChanged => translate('language_changed');

  String get autoBackup => translate('auto_backup');
  String get autoBackupSubtitle => translate('auto_backup_subtitle');
  String get exportData => translate('export_data');
  String get exportDataSubtitle => translate('export_data_subtitle');

  String get version => translate('version');
  String get developer => translate('developer');

  String get googleAccount => translate('google_account');
  String get premiumMember => translate('premium_member');
  String get unverified => translate('unverified');

  String get cancel => translate('cancel');
  String get ok => translate('ok');
  String get signOut => translate('sign_out');
  String get signOutConfirmation => translate('sign_out_confirmation');
  String get signOutSuccess => translate('sign_out_success');
  String get verificationEmailSent => translate('verification_email_sent');
  String get biometricEnabled => translate('biometric_enabled');
  String get biometricDisabled => translate('biometric_disabled');
  String get biometricEnabledMessage => translate('biometric_enabled_message');
  String get biometricDisabledMessage =>
      translate('biometric_disabled_message');
  String get biometricNotAvailableTitle =>
      translate('biometric_not_available_title');
  String get biometricSetupInstructions =>
      translate('biometric_setup_instructions');
  String get biometricAuthentication => translate('biometric_authentication');
  String get useBiometric => translate('use_biometric');
  String get toSecureApp => translate('to_secure_app');
  String get checkingAvailability => translate('checking_availability');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar', 'fr', 'es'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
