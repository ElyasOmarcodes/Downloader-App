import 'package:flutter/material.dart';

/// Lightweight hand-rolled localization. Pashto (`ps`) is the default and
/// English (`en`) is provided as a fallback. Pashto renders right-to-left.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const supportedLocales = [Locale('ps'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, Map<String, String>> _values = {
    'ps': {
      'appName': 'میډیا ګرب',
      'home': 'کور',
      'downloads': 'ډانلوډونه',
      'settings': 'تنظیمات',
      'pasteLink': 'لینک دلته ولګوئ',
      'paste': 'لګول',
      'fetch': 'میډیا راوړل',
      'resolving': 'د پروسس په حال کې…',
      'platforms': 'پلیټفارمونه',
      'video': 'ویډیو',
      'audio': 'آډیو',
      'download': 'ډانلوډ',
      'downloadSubtitles': 'سب‌ټایټل هم ډانلوډ کړه',
      'noVideoFormats': 'د ویډیو کوم کیفیت نشته.',
      'noAudioFormats': 'د آډیو کوم کیفیت نشته.',
      'addedToDownloads': 'ډانلوډونو ته اضافه شو',
      'inProgress': 'روان',
      'completed': 'بشپړ شوي',
      'noDownloads': 'تر اوسه ډانلوډ نشته',
      'noDownloadsHint': 'د لینک لګولو لپاره کور ټب ته لاړ شئ.',
      'clearCompleted': 'بشپړ شوي پاک کړه',
      'done': 'شوی',
      'pause': 'ودروه',
      'resume': 'بیا پیل',
      'retry': 'بیا هڅه',
      'open': 'خلاص کړه',
      'remove': 'لرې کړه',
      'size': 'اندازه',
      'quality': 'کیفیت',
      'unrecognizedLink': 'لینک ونه پیژندل شو. بشپړ لینک ولګوئ.',
      'storageLocation': 'د خوندي کولو ځای',
      'videoQuality': 'د ویډیو کیفیت',
      'audioExtraction': 'د آډیو ایستل',
      'language': 'ژبه',
      'concurrentWifi': 'د وای‌فای پر مهال هممهاله ډانلوډونه',
      'concurrentMobile': 'د موبایل ډېټا پر مهال هممهاله ډانلوډونه',
      'legalNote':
          'یوازې هغه محتوا ډانلوډ کړئ چې د خوندي کولو حق یې لرئ. د هرې پلیټفارم د ToS او د کاپي‌رایټ قوانین درناوی وکړئ.',
      'clipboardDetected': 'یو نوی لینک وموندل شو',
    },
    'en': {
      'appName': 'MediaGrab',
      'home': 'Home',
      'downloads': 'Downloads',
      'settings': 'Settings',
      'pasteLink': 'Paste a video link',
      'paste': 'Paste',
      'fetch': 'Fetch media',
      'resolving': 'Resolving…',
      'platforms': 'Platforms',
      'video': 'Video',
      'audio': 'Audio',
      'download': 'Download',
      'downloadSubtitles': 'Also download subtitles',
      'noVideoFormats': 'No video formats available.',
      'noAudioFormats': 'No audio formats available.',
      'addedToDownloads': 'Added to downloads',
      'inProgress': 'In progress',
      'completed': 'Completed',
      'noDownloads': 'No downloads yet',
      'noDownloadsHint': 'Paste a link on the Home tab to get started.',
      'clearCompleted': 'Clear completed',
      'done': 'Done',
      'pause': 'Pause',
      'resume': 'Resume',
      'retry': 'Retry',
      'open': 'Open',
      'remove': 'Remove',
      'size': 'Size',
      'quality': 'Quality',
      'unrecognizedLink': 'Unrecognized link. Paste a full video URL.',
      'storageLocation': 'Storage location',
      'videoQuality': 'Video quality',
      'audioExtraction': 'Audio extraction',
      'language': 'Language',
      'concurrentWifi': 'Concurrent downloads on WiFi',
      'concurrentMobile': 'Concurrent downloads on mobile data',
      'legalNote':
          'Only download content you have the right to save. Respect each platform\'s Terms of Service and copyright law.',
      'clipboardDetected': 'A new link was detected',
    },
  };

  String t(String key) {
    final lang = _values.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'ps';
    return _values[lang]![key] ?? _values['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ps', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
