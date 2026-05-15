import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thix_id/l10n/locale_controller.dart';

/// Minimal in-app localization.
///
/// Note: Much of the app still uses hard-coded strings. This layer allows us to
/// progressively migrate screens to translated keys while the global locale
/// (and RTL for Arabic) already applies everywhere.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? const AppLocalizations(Locale('en'));

  static const _strings = <String, Map<String, String>>{
    'fr': {
      'language': 'Langue',
      'choose_language': 'Choisir la langue',
      'system_default': 'Langue du téléphone',

      // Common actions
      'login': 'Se connecter',
      'cancel': 'Annuler',
      'later': 'Plus tard',
      'settings': 'Paramètres',
      'my_account': 'Mon compte',
      'request_account': 'Demander un compte',

      // Settings
      'settings_title': 'Paramètres & Préférences',
      'settings_language_group': 'LANGUE',
      'settings_choose_ui_language': "Choisissez votre langue d'interface",

      'settings_appearance_group': 'APPARENCE',
      'settings_dark_mode': 'Mode sombre',
      'settings_dark_mode_sub': 'Activer le thème haute performance',
      'settings_high_contrast': 'Contraste élevé',
      'settings_high_contrast_sub': 'Optimiser pour la visibilité',

      'settings_security_group': 'SÉCURITÉ INSTITUTIONNELLE',
      'settings_biometrics': 'Biométrie (Empreinte)',
      'settings_biometrics_sub': 'Utiliser pour la connexion',
      'settings_face_id': 'Face ID / Reconnaissance faciale',
      'settings_face_id_sub': 'Niveau de sécurité 2',
      'settings_change_password': 'Changer le mot de passe',
      'settings_2fa': 'Double authentification (2FA)',
      'settings_2fa_sub': 'Recommandé',
      'settings_active': 'ACTIF',

      'settings_account_group': 'GESTION DU COMPTE',
      'settings_data_privacy': 'Confidentialité des données',
      'settings_activity_log': "Journal d'activité",

      'settings_sign_out': 'Se déconnecter de THIX ID',
      'settings_tagline': 'Identité sécurisée. Avenir de confiance.',

      // Dashboard
      'dashboard_security_title': 'Sécurité du compte',
      'dashboard_security_subtitle': 'Paramètres de protection et journalisation',
      'dashboard_biometrics_toggle': 'Biométrie (Face ID / Empreinte)',
      'dashboard_2fa_toggle': 'Double authentification (2FA)',
    },
    'en': {
      'language': 'Language',
      'choose_language': 'Choose language',
      'system_default': 'Device language',

      'login': 'Sign in',
      'cancel': 'Cancel',
      'later': 'Later',
      'settings': 'Settings',
      'my_account': 'My account',
      'request_account': 'Request an account',

      'settings_title': 'Settings & Preferences',
      'settings_language_group': 'LANGUAGE',
      'settings_choose_ui_language': 'Choose your interface language',

      'settings_appearance_group': 'APPEARANCE',
      'settings_dark_mode': 'Dark mode',
      'settings_dark_mode_sub': 'Enable high-performance theme',
      'settings_high_contrast': 'High contrast',
      'settings_high_contrast_sub': 'Optimize for readability',

      'settings_security_group': 'INSTITUTIONAL SECURITY',
      'settings_biometrics': 'Biometrics (Fingerprint)',
      'settings_biometrics_sub': 'Use for sign-in',
      'settings_face_id': 'Face ID / Facial recognition',
      'settings_face_id_sub': 'Security level 2',
      'settings_change_password': 'Change password',
      'settings_2fa': 'Two-factor authentication (2FA)',
      'settings_2fa_sub': 'Recommended',
      'settings_active': 'ACTIVE',

      'settings_account_group': 'ACCOUNT MANAGEMENT',
      'settings_data_privacy': 'Data privacy',
      'settings_activity_log': 'Activity log',

      'settings_sign_out': 'Sign out of THIX ID',
      'settings_tagline': 'Secure identity. Trusted future.',

      'dashboard_security_title': 'Account security',
      'dashboard_security_subtitle': 'Protection settings & audit logs',
      'dashboard_biometrics_toggle': 'Biometrics (Face ID / Fingerprint)',
      'dashboard_2fa_toggle': 'Two-factor authentication (2FA)',
    },
    'sw': {
      'language': 'Lugha',
      'choose_language': 'Chagua lugha',
      'system_default': 'Lugha ya simu',

      'login': 'Ingia',
      'cancel': 'Ghairi',
      'later': 'Baadaye',
      'settings': 'Mipangilio',
      'my_account': 'Akaunti yangu',
      'request_account': 'Omba akaunti',

      'settings_title': 'Mipangilio na Mapendeleo',
      'settings_language_group': 'LUGHA',
      'settings_choose_ui_language': 'Chagua lugha ya matumizi',

      'settings_appearance_group': 'MWONEKANO',
      'settings_dark_mode': 'Hali ya giza',
      'settings_dark_mode_sub': 'Washa mandhari ya utendaji wa juu',
      'settings_high_contrast': 'Tofauti ya juu',
      'settings_high_contrast_sub': 'Boresha usomaji',

      'settings_security_group': 'USALAMA WA TAASISI',
      'settings_biometrics': 'Biometria (Alama ya kidole)',
      'settings_biometrics_sub': 'Tumia kuingia',
      'settings_face_id': 'Face ID / Utambuzi wa uso',
      'settings_face_id_sub': 'Kiwango cha usalama 2',
      'settings_change_password': 'Badilisha nenosiri',
      'settings_2fa': 'Uthibitishaji wa hatua mbili (2FA)',
      'settings_2fa_sub': 'Inapendekezwa',
      'settings_active': 'INAWAKA',

      'settings_account_group': 'USIMAMIZI WA AKAUNTI',
      'settings_data_privacy': 'Faragha ya data',
      'settings_activity_log': 'Rekodi ya shughuli',

      'settings_sign_out': 'Toka THIX ID',
      'settings_tagline': 'Utambulisho salama. Kesho ya uaminifu.',

      'dashboard_security_title': 'Usalama wa akaunti',
      'dashboard_security_subtitle': 'Mipangilio ya ulinzi na kumbukumbu',
      'dashboard_biometrics_toggle': 'Biometria (Face ID / Alama ya kidole)',
      'dashboard_2fa_toggle': 'Uthibitishaji wa hatua mbili (2FA)',
    },
    'ln': {
      'language': 'Lokóta',
      'choose_language': 'Pona lokóta',
      'system_default': 'Lokóta ya telefone',

      'login': 'Kokóta',
      'cancel': 'Tika',
      'later': 'Sima',
      'settings': 'Paramɛtrɛ',
      'my_account': 'Konti na ngai',
      'request_account': 'Senga konti',

      'settings_title': 'Paramɛtrɛ & Preferansi',
      'settings_language_group': 'LOKÓTA',
      'settings_choose_ui_language': "Pona lokóta ya interface",

      'settings_appearance_group': 'BOMÓNI',
      'settings_dark_mode': 'Mode ya molili',
      'settings_dark_mode_sub': 'Pesa tema ya performance',
      'settings_high_contrast': 'Contraste makasi',
      'settings_high_contrast_sub': 'Bongisa ndenge ya komona',

      'settings_security_group': 'SÉCURITÉ YA INSTITUTION',
      'settings_biometrics': 'Biométrie (Empreinte)',
      'settings_biometrics_sub': 'Salela mpo na kokóta',
      'settings_face_id': 'Face ID / Reconnaissance ya elongi',
      'settings_face_id_sub': 'Niveau ya sécurité 2',
      'settings_change_password': 'Bongola mot de passe',
      'settings_2fa': 'Double authentification (2FA)',
      'settings_2fa_sub': 'Esengeli',
      'settings_active': 'AKTIF',

      'settings_account_group': 'GESTION YA KOŃTI',
      'settings_data_privacy': 'Confidentialité ya données',
      'settings_activity_log': 'Journal ya misala',

      'settings_sign_out': 'Bimá na THIX ID',
      'settings_tagline': 'Identité ya libateli. Avenir ya bondimi.',

      'dashboard_security_title': 'SÉCURITÉ ya konti',
      'dashboard_security_subtitle': 'Paramɛtrɛ ya libateli mpe journalisation',
      'dashboard_biometrics_toggle': 'Biométrie (Face ID / Empreinte)',
      'dashboard_2fa_toggle': 'Double authentification (2FA)',
    },
    'ar': {
      'language': 'اللغة',
      'choose_language': 'اختر اللغة',
      'system_default': 'لغة الهاتف',

      'login': 'تسجيل الدخول',
      'cancel': 'إلغاء',
      'later': 'لاحقًا',
      'settings': 'الإعدادات',
      'my_account': 'حسابي',
      'request_account': 'طلب حساب',

      'settings_title': 'الإعدادات والتفضيلات',
      'settings_language_group': 'اللغة',
      'settings_choose_ui_language': 'اختر لغة الواجهة',

      'settings_appearance_group': 'المظهر',
      'settings_dark_mode': 'الوضع الداكن',
      'settings_dark_mode_sub': 'تفعيل السمة عالية الأداء',
      'settings_high_contrast': 'تباين عالٍ',
      'settings_high_contrast_sub': 'تحسين سهولة القراءة',

      'settings_security_group': 'الأمان المؤسسي',
      'settings_biometrics': 'البصمة (Fingerprint)',
      'settings_biometrics_sub': 'استخدمها لتسجيل الدخول',
      'settings_face_id': 'Face ID / التعرف على الوجه',
      'settings_face_id_sub': 'مستوى أمان 2',
      'settings_change_password': 'تغيير كلمة المرور',
      'settings_2fa': 'المصادقة الثنائية (2FA)',
      'settings_2fa_sub': 'موصى بها',
      'settings_active': 'مُفعّل',

      'settings_account_group': 'إدارة الحساب',
      'settings_data_privacy': 'خصوصية البيانات',
      'settings_activity_log': 'سجل النشاط',

      'settings_sign_out': 'تسجيل الخروج من THIX ID',
      'settings_tagline': 'هوية آمنة. مستقبل موثوق.',

      'dashboard_security_title': 'أمان الحساب',
      'dashboard_security_subtitle': 'إعدادات الحماية وسجلات التدقيق',
      'dashboard_biometrics_toggle': 'القياسات الحيوية (Face ID / Fingerprint)',
      'dashboard_2fa_toggle': 'المصادقة الثنائية (2FA)',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ?? _strings['en']?[key] ?? key;
  }

  /// Human-readable label for a locale option.
  static String localeLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'sw':
        return 'Kiswahili';
      case 'ln':
        return 'Lingála';
      case 'ar':
        return 'العربية';
      default:
        return locale.languageCode;
    }
  }
}

class _AppLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocDelegate();

  @override
  bool isSupported(Locale locale) => LocaleController.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension AppLocX on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this);
}
