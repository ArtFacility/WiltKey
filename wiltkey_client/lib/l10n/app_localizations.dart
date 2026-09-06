import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('hu'),
    Locale('pl'),
    Locale('sv'),
    Locale('zh'),
  ];

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navPair.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get navPair;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @nukedTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Reset'**
  String get nukedTitle;

  /// No description provided for @nukedExplanation.
  ///
  /// In en, this message translates to:
  /// **'All messages and keys have been deleted from this device. The secure database has been cleared.'**
  String get nukedExplanation;

  /// No description provided for @nukedResetButton.
  ///
  /// In en, this message translates to:
  /// **'Create New Identity'**
  String get nukedResetButton;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Wiltkey'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Wiltkey is a private messenger that doesn\'t save metadata, logs, or server history. Messages are encrypted locally and self-destruct if a screenshot is taken.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingWelcomeNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No server history. No recovery keys.'**
  String get onboardingWelcomeNoHistory;

  /// No description provided for @onboardingIntelTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Info'**
  String get onboardingIntelTitle;

  /// No description provided for @onboardingLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language to continue. You can change this at any time in Settings.'**
  String get onboardingLanguageDescription;

  /// No description provided for @onboardingFactLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language setup'**
  String get onboardingFactLanguageTitle;

  /// No description provided for @onboardingFactLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language to continue. You can change this at any time in Settings. Your preference is saved locally.'**
  String get onboardingFactLanguageBody;

  /// No description provided for @onboardingThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your theme'**
  String get onboardingThemeTitle;

  /// No description provided for @onboardingThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a theme below. You can change this later in Settings.'**
  String get onboardingThemeDescription;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Identity'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get onboardingProfileUsernameLabel;

  /// No description provided for @onboardingProfileUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get onboardingProfileUsernameHint;

  /// No description provided for @onboardingProfileCodenameLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection code (5 letters/numbers)'**
  String get onboardingProfileCodenameLabel;

  /// No description provided for @onboardingProfileCodenameExplanation.
  ///
  /// In en, this message translates to:
  /// **'This code is shared during pairing to connect with nearby friends.'**
  String get onboardingProfileCodenameExplanation;

  /// No description provided for @onboardingProfileUsernameError.
  ///
  /// In en, this message translates to:
  /// **'Please set a username.'**
  String get onboardingProfileUsernameError;

  /// No description provided for @onboardingProfileCodenameError.
  ///
  /// In en, this message translates to:
  /// **'Connection code must be exactly 5 characters.'**
  String get onboardingProfileCodenameError;

  /// No description provided for @onboardingAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Pixel Avatar'**
  String get onboardingAvatarTitle;

  /// No description provided for @onboardingAvatarBrushColor.
  ///
  /// In en, this message translates to:
  /// **'Brush color'**
  String get onboardingAvatarBrushColor;

  /// No description provided for @onboardingAvatarRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get onboardingAvatarRandom;

  /// No description provided for @onboardingAvatarClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get onboardingAvatarClear;

  /// No description provided for @onboardingPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Passcode PIN'**
  String get onboardingPinTitle;

  /// No description provided for @onboardingPinExplanation.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN (4–6 digits) to protect your chats. You will need to enter this PIN every time you open the app. If you forget this PIN, your messages cannot be recovered.'**
  String get onboardingPinExplanation;

  /// No description provided for @onboardingPinEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get onboardingPinEnter;

  /// No description provided for @onboardingPinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get onboardingPinConfirm;

  /// No description provided for @onboardingPinLengthError.
  ///
  /// In en, this message translates to:
  /// **'PIN must be between 4 and 6 digits.'**
  String get onboardingPinLengthError;

  /// No description provided for @onboardingPinMatchError.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get onboardingPinMatchError;

  /// No description provided for @onboardingSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Setup failed: {error}'**
  String onboardingSetupFailed(String error);

  /// No description provided for @onboardingFactMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'THE METADATA PROBLEM'**
  String get onboardingFactMetadataTitle;

  /// No description provided for @onboardingFactMetadataBody.
  ///
  /// In en, this message translates to:
  /// **'Most chat apps encrypt message content but still track who you talk to, when, and how often. Wiltkey does not log any metadata, server-side data, or connections.'**
  String get onboardingFactMetadataBody;

  /// No description provided for @onboardingFactThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR THEME'**
  String get onboardingFactThemeTitle;

  /// No description provided for @onboardingFactThemeBody.
  ///
  /// In en, this message translates to:
  /// **'Themes are cosmetic. The same security standards apply to every theme. You can switch themes at any time in Settings.'**
  String get onboardingFactThemeBody;

  /// No description provided for @onboardingFactOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'PERFECT SECRECY'**
  String get onboardingFactOtpTitle;

  /// No description provided for @onboardingFactOtpBody.
  ///
  /// In en, this message translates to:
  /// **'Wiltkey uses One-Time Pads (OTP) where keys match the message size, are completely random, and are never reused. This provides mathematical perfect secrecy, making messages impossible to decrypt without the keys.'**
  String get onboardingFactOtpBody;

  /// No description provided for @onboardingFactLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'CONNECTION LIMITS'**
  String get onboardingFactLimitsTitle;

  /// No description provided for @onboardingFactLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'Chat capacity limits are designed to encourage meaningful, deliberate relationships. Restricting capacity ensures conversations are purposeful and grounded in real-world connections.'**
  String get onboardingFactLimitsBody;

  /// No description provided for @onboardingFactKdfTitle.
  ///
  /// In en, this message translates to:
  /// **'SECURITY HASHING'**
  String get onboardingFactKdfTitle;

  /// No description provided for @onboardingFactKdfBody.
  ///
  /// In en, this message translates to:
  /// **'A standard PIN can be brute-forced in milliseconds. Wiltkey processes your PIN through a hardening function, making brute-force attacks on the local database impossible.'**
  String get onboardingFactKdfBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsTabProfile;

  /// No description provided for @settingsTabSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsTabSecurity;

  /// No description provided for @settingsSecuritySectionAccess.
  ///
  /// In en, this message translates to:
  /// **'Access & unlock'**
  String get settingsSecuritySectionAccess;

  /// No description provided for @settingsSecuritySectionDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsSecuritySectionDanger;

  /// No description provided for @settingsTabNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsTabNetwork;

  /// No description provided for @settingsTabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsTabAlerts;

  /// No description provided for @settingsSavedIndicator.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settingsSavedIndicator;

  /// No description provided for @settingsProfileSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsProfileSectionAppearance;

  /// No description provided for @settingsProfileSectionAvatar.
  ///
  /// In en, this message translates to:
  /// **'Pixel Art Avatar'**
  String get settingsProfileSectionAvatar;

  /// No description provided for @settingsProfileSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get settingsProfileSectionProfile;

  /// No description provided for @settingsProfileSectionOtherVisuals.
  ///
  /// In en, this message translates to:
  /// **'Other Visuals'**
  String get settingsProfileSectionOtherVisuals;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsPixelArtEditor.
  ///
  /// In en, this message translates to:
  /// **'Pixel Art Editor'**
  String get settingsPixelArtEditor;

  /// No description provided for @settingsProfileBrushColor.
  ///
  /// In en, this message translates to:
  /// **'Brush color'**
  String get settingsProfileBrushColor;

  /// No description provided for @settingsProfileChipIdenticon.
  ///
  /// In en, this message translates to:
  /// **'Identicon'**
  String get settingsProfileChipIdenticon;

  /// No description provided for @settingsProfileChipClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsProfileChipClear;

  /// No description provided for @settingsProfileChipRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get settingsProfileChipRandom;

  /// No description provided for @settingsProfileChipTemplateSave.
  ///
  /// In en, this message translates to:
  /// **'Add to templates'**
  String get settingsProfileChipTemplateSave;

  /// No description provided for @settingsProfileTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to templates'**
  String get settingsProfileTemplateSaved;

  /// No description provided for @settingsProfileTemplatesButton.
  ///
  /// In en, this message translates to:
  /// **'Select from template'**
  String get settingsProfileTemplatesButton;

  /// No description provided for @settingsProfileTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Templates'**
  String get settingsProfileTemplatesTitle;

  /// No description provided for @settingsProfileNoTemplates.
  ///
  /// In en, this message translates to:
  /// **'No saved templates yet'**
  String get settingsProfileNoTemplates;

  /// No description provided for @settingsProfileTemplateEquipped.
  ///
  /// In en, this message translates to:
  /// **'Avatar template equipped'**
  String get settingsProfileTemplateEquipped;

  /// No description provided for @avatarEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit avatar'**
  String get avatarEditButton;

  /// No description provided for @groupCreateEditIcon.
  ///
  /// In en, this message translates to:
  /// **'Edit icon'**
  String get groupCreateEditIcon;

  /// No description provided for @settingsProfileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsProfileUsername;

  /// No description provided for @settingsProfileBleNick.
  ///
  /// In en, this message translates to:
  /// **'Short Nickname (5 chars)'**
  String get settingsProfileBleNick;

  /// No description provided for @settingsProfileKeyhash.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get settingsProfileKeyhash;

  /// No description provided for @settingsProfileKeyhashCopied.
  ///
  /// In en, this message translates to:
  /// **'Account ID copied to clipboard'**
  String get settingsProfileKeyhashCopied;

  /// No description provided for @settingsProfileChangePinButton.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsProfileChangePinButton;

  /// No description provided for @settingsProfileResetIdentityButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Account'**
  String get settingsProfileResetIdentityButton;

  /// No description provided for @settingsResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset identity?'**
  String get settingsResetConfirmTitle;

  /// No description provided for @settingsResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all messages, contacts, and generate a new identity. This action cannot be undone.'**
  String get settingsResetConfirmBody;

  /// No description provided for @settingsResetConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsResetConfirmCancel;

  /// No description provided for @settingsResetConfirmReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetConfirmReset;

  /// No description provided for @settingsChangePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsChangePinTitle;

  /// No description provided for @changePinVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify current PIN'**
  String get changePinVerifyTitle;

  /// No description provided for @changePinVerifyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN to continue.'**
  String get changePinVerifyPrompt;

  /// No description provided for @changePinSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set new PIN'**
  String get changePinSetTitle;

  /// No description provided for @settingsChangePinOldPin.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN'**
  String get settingsChangePinOldPin;

  /// No description provided for @settingsChangePinNewPin.
  ///
  /// In en, this message translates to:
  /// **'Enter new PIN (4–6 digits)'**
  String get settingsChangePinNewPin;

  /// No description provided for @settingsChangePinConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN'**
  String get settingsChangePinConfirmPin;

  /// No description provided for @settingsChangePinEmptyFieldsError.
  ///
  /// In en, this message translates to:
  /// **'Please fill out all fields.'**
  String get settingsChangePinEmptyFieldsError;

  /// No description provided for @settingsChangePinLengthError.
  ///
  /// In en, this message translates to:
  /// **'New PIN must be 4 to 6 digits.'**
  String get settingsChangePinLengthError;

  /// No description provided for @settingsChangePinMatchError.
  ///
  /// In en, this message translates to:
  /// **'New PINs do not match.'**
  String get settingsChangePinMatchError;

  /// No description provided for @settingsChangePinUpdatedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'PIN updated.'**
  String get settingsChangePinUpdatedSnackBar;

  /// No description provided for @settingsChangePinIncorrectError.
  ///
  /// In en, this message translates to:
  /// **'Current PIN is incorrect.'**
  String get settingsChangePinIncorrectError;

  /// No description provided for @settingsNetworkRoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Settings'**
  String get settingsNetworkRoutingTitle;

  /// No description provided for @settingsNetworkDevRelayToggle.
  ///
  /// In en, this message translates to:
  /// **'Use local developer server'**
  String get settingsNetworkDevRelayToggle;

  /// No description provided for @settingsNetworkDevRelayUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Developer Server URL'**
  String get settingsNetworkDevRelayUrlLabel;

  /// No description provided for @settingsNetworkDevRelayDescription.
  ///
  /// In en, this message translates to:
  /// **'Enabling this overrides the production server and routes messages through a local server.'**
  String get settingsNetworkDevRelayDescription;

  /// No description provided for @settingsNetworkActiveGateway.
  ///
  /// In en, this message translates to:
  /// **'Current Server URL'**
  String get settingsNetworkActiveGateway;

  /// No description provided for @settingsNetworkDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsNetworkDiagnostics;

  /// No description provided for @settingsNetworkDebugButton.
  ///
  /// In en, this message translates to:
  /// **'Open debug console'**
  String get settingsNetworkDebugButton;

  /// No description provided for @settingsDebugButtonsToggle.
  ///
  /// In en, this message translates to:
  /// **'Debugger buttons'**
  String get settingsDebugButtonsToggle;

  /// No description provided for @settingsDebugButtonsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the terminal console button on the chats list and inside chats.'**
  String get settingsDebugButtonsDescription;

  /// No description provided for @settingsDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug console'**
  String get settingsDebugTitle;

  /// No description provided for @settingsAlertsBackgroundNotifications.
  ///
  /// In en, this message translates to:
  /// **'Background Notifications'**
  String get settingsAlertsBackgroundNotifications;

  /// No description provided for @settingsAlertsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Notifications will only show \'You have a message\'. Your messages remain encrypted until you unlock the app.'**
  String get settingsAlertsExplanation;

  /// No description provided for @settingsTextSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat text size'**
  String get settingsTextSizeLabel;

  /// No description provided for @settingsTextSizePreview.
  ///
  /// In en, this message translates to:
  /// **'This is how your messages will look.'**
  String get settingsTextSizePreview;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Language'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageHungarian.
  ///
  /// In en, this message translates to:
  /// **'Magyar (Hungarian)'**
  String get settingsLanguageHungarian;

  /// No description provided for @settingsLanguagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polski (Polish)'**
  String get settingsLanguagePolish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch (German)'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français (French)'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsLanguageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Svenska (Swedish)'**
  String get settingsLanguageSwedish;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文 (Chinese)'**
  String get settingsLanguageChinese;

  /// No description provided for @notificationModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get notificationModeOff;

  /// No description provided for @notificationModeOffDesc.
  ///
  /// In en, this message translates to:
  /// **'No background checks. You only see messages when you open the app.'**
  String get notificationModeOffDesc;

  /// No description provided for @notificationModeLowPower.
  ///
  /// In en, this message translates to:
  /// **'Low Power'**
  String get notificationModeLowPower;

  /// No description provided for @notificationModeLowPowerDesc.
  ///
  /// In en, this message translates to:
  /// **'Periodically checks for new messages in the background — quickly right after you close the app, then less often to save battery. No constant connection, so alerts can be delayed.'**
  String get notificationModeLowPowerDesc;

  /// No description provided for @notificationModeInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get notificationModeInstant;

  /// No description provided for @notificationModeInstantDesc.
  ///
  /// In en, this message translates to:
  /// **'Optional. Keeps an end-to-end-encrypted connection open in the background to sync your incoming messages in real time, shown by an ongoing notification. Wiltkey uses this instead of Google or Apple push services for privacy, so it works even without Google Play Services — at the cost of more battery.'**
  String get notificationModeInstantDesc;

  /// No description provided for @notificationNewMessageBody.
  ///
  /// In en, this message translates to:
  /// **'You got a message'**
  String get notificationNewMessageBody;

  /// No description provided for @notificationEmergencyChatBody.
  ///
  /// In en, this message translates to:
  /// **'Emergency chat request'**
  String get notificationEmergencyChatBody;

  /// No description provided for @notificationSecureLinkActive.
  ///
  /// In en, this message translates to:
  /// **'Syncing secure messages'**
  String get notificationSecureLinkActive;

  /// No description provided for @onboardingNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get onboardingNotificationsTitle;

  /// No description provided for @onboardingNotificationsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Wiltkey doesn\'t use Google or Apple push notifications — nothing about your messages ever touches their servers. Choose how you\'d like to be alerted. You can change this any time in Settings.'**
  String get onboardingNotificationsExplanation;

  /// No description provided for @onboardingFactPushTitle.
  ///
  /// In en, this message translates to:
  /// **'NO PUSH SERVERS'**
  String get onboardingFactPushTitle;

  /// No description provided for @onboardingFactPushBody.
  ///
  /// In en, this message translates to:
  /// **'Normal apps route your notifications through Google or Apple, revealing who messages you and when. Wiltkey never does — the default is no background checks at all, and any alerting runs entirely on your device.'**
  String get onboardingFactPushBody;

  /// No description provided for @notificationModeInstantDescFcm.
  ///
  /// In en, this message translates to:
  /// **'Optional. Uses Google\'s push service as a lightweight wake-up so new messages arrive in real time. Only a content-free ping goes through Google — never your messages, which stay end-to-end encrypted on the relay until your device fetches them. Lighter on battery than a constant connection.'**
  String get notificationModeInstantDescFcm;

  /// No description provided for @onboardingNotificationsExplanationFcm.
  ///
  /// In en, this message translates to:
  /// **'For real-time alerts, this build uses Google\'s push service purely as a wake-up signal — a content-free ping, never your messages, which never touch Google\'s servers. Choose how you\'d like to be alerted; you can change this any time in Settings.'**
  String get onboardingNotificationsExplanationFcm;

  /// No description provided for @onboardingFactPushTitleFcm.
  ///
  /// In en, this message translates to:
  /// **'CONTENT-FREE PUSH'**
  String get onboardingFactPushTitleFcm;

  /// No description provided for @onboardingFactPushBodyFcm.
  ///
  /// In en, this message translates to:
  /// **'Normal apps route your notification content through Google, revealing what\'s sent and when. This build uses Google only as a content-free wake-up ping — no message data, no readable metadata — and everything stays encrypted end to end.'**
  String get onboardingFactPushBodyFcm;

  /// No description provided for @chatsLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Locked · pair in person to unlock'**
  String get chatsLockedSubtitle;

  /// No description provided for @chatsMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String chatsMemberCount(int count);

  /// No description provided for @chatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{totalCount} {totalCount, plural, =1{contact} other{contacts}} · {lockedCount} locked'**
  String chatsSubtitle(int totalCount, int lockedCount);

  /// No description provided for @chatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// No description provided for @chatsPopupPair.
  ///
  /// In en, this message translates to:
  /// **'Pair a device'**
  String get chatsPopupPair;

  /// No description provided for @chatsPopupCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get chatsPopupCreateGroup;

  /// No description provided for @chatsPopupJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get chatsPopupJoinGroup;

  /// No description provided for @chatsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get chatsSearchHint;

  /// No description provided for @chatsEmptyNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get chatsEmptyNoMatches;

  /// No description provided for @chatsEmptyNoChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get chatsEmptyNoChats;

  /// No description provided for @chatsEmptyPairInstruction.
  ///
  /// In en, this message translates to:
  /// **'Pair a device in person to start chatting.'**
  String get chatsEmptyPairInstruction;

  /// No description provided for @chatsEmptyPairButton.
  ///
  /// In en, this message translates to:
  /// **'Pair a device'**
  String get chatsEmptyPairButton;

  /// No description provided for @chatsRowMeRemaining.
  ///
  /// In en, this message translates to:
  /// **'ME {remaining} · PEER {theirRemaining}'**
  String chatsRowMeRemaining(String remaining, String theirRemaining);

  /// No description provided for @chatsRowGroupRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} / {max}'**
  String chatsRowGroupRemaining(String remaining, String max);

  /// No description provided for @pinMaxAttemptsExceeded.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts. Device wiped.'**
  String get pinMaxAttemptsExceeded;

  /// No description provided for @pinAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. {attempts} attempts remaining.'**
  String pinAccessDenied(int attempts);

  /// No description provided for @pinMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits.'**
  String get pinMinLengthError;

  /// No description provided for @pinPurgeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset device?'**
  String get pinPurgeConfirmTitle;

  /// No description provided for @pinPurgeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Forget your PIN? This will permanently delete all messages and reset your account. This action cannot be undone.'**
  String get pinPurgeConfirmBody;

  /// No description provided for @pinPurgeConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Device'**
  String get pinPurgeConfirmButton;

  /// No description provided for @pinLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get pinLockedTitle;

  /// No description provided for @pinLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to unlock'**
  String get pinLockedSubtitle;

  /// No description provided for @pinUnlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlockButton;

  /// No description provided for @pinUseFingerprintButton.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get pinUseFingerprintButton;

  /// No description provided for @settingsBiometricToggle.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint unlock'**
  String get settingsBiometricToggle;

  /// No description provided for @settingsBiometricDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint to unlock instead of the PIN. Your PIN is still required after the fallback period below.'**
  String get settingsBiometricDescription;

  /// No description provided for @settingsBiometricIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN fallback'**
  String get settingsBiometricIdleTitle;

  /// No description provided for @settingsBiometricIdleDescription.
  ///
  /// In en, this message translates to:
  /// **'Require your PIN again after this long without unlocking.'**
  String get settingsBiometricIdleDescription;

  /// Fingerprint idle window in hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String settingsBiometricIdleValue(int hours);

  /// PIN-fallback slider value meaning fingerprint never expires.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsBiometricIdleNever;

  /// No description provided for @settingsBiometricFailedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t enable fingerprint unlock.'**
  String get settingsBiometricFailedSnackBar;

  /// No description provided for @pinForgotButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN? Reset Device'**
  String get pinForgotButton;

  /// No description provided for @pairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair Devices'**
  String get pairTitle;

  /// No description provided for @pairRescanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh scan'**
  String get pairRescanTooltip;

  /// No description provided for @pairBluetoothOffWarning.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off. Pairing needs Bluetooth to find nearby devices — turn it on to continue.'**
  String get pairBluetoothOffWarning;

  /// No description provided for @pairBluetoothTurnOnButton.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth'**
  String get pairBluetoothTurnOnButton;

  /// No description provided for @pairDoNotExitWarning.
  ///
  /// In en, this message translates to:
  /// **'Keep WiltKey open — don\'t switch apps or exit until pairing has finished on BOTH devices.'**
  String get pairDoNotExitWarning;

  /// No description provided for @pairRequestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing Request'**
  String get pairRequestDialogTitle;

  /// No description provided for @pairRequestDialogBody.
  ///
  /// In en, this message translates to:
  /// **'{peerName} wants to pair.\n\nChat size: {size}.\n\nAccept secure pairing?'**
  String pairRequestDialogBody(String peerName, String size);

  /// No description provided for @pairRequestReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get pairRequestReject;

  /// No description provided for @pairRequestAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get pairRequestAccept;

  /// No description provided for @pairPingStatusPinging.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get pairPingStatusPinging;

  /// No description provided for @pairPingStatusLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency: {latency}ms'**
  String pairPingStatusLatency(String latency);

  /// No description provided for @pairPingStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get pairPingStatusFailed;

  /// No description provided for @pairPingStatusTest.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get pairPingStatusTest;

  /// No description provided for @pairDeviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Device Name'**
  String get pairDeviceNameLabel;

  /// No description provided for @pairDeviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get pairDeviceNameHint;

  /// No description provided for @pairDiscoverableTitle.
  ///
  /// In en, this message translates to:
  /// **'Make device discoverable'**
  String get pairDiscoverableTitle;

  /// No description provided for @pairDiscoverableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow nearby friends to find you'**
  String get pairDiscoverableSubtitle;

  /// No description provided for @pairNearbyDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby Devices'**
  String get pairNearbyDevicesTitle;

  /// No description provided for @pairNearbyDevicesInstruction.
  ///
  /// In en, this message translates to:
  /// **'Hold devices next to each other to connect.'**
  String get pairNearbyDevicesInstruction;

  /// No description provided for @pairDirectSyncFormRelayLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get pairDirectSyncFormRelayLabel;

  /// No description provided for @pairDirectSyncFormSyncButton.
  ///
  /// In en, this message translates to:
  /// **'Connect Devices'**
  String get pairDirectSyncFormSyncButton;

  /// No description provided for @pairSyncingConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get pairSyncingConnecting;

  /// No description provided for @pairSyncingGeneratingKey.
  ///
  /// In en, this message translates to:
  /// **'Generating secure key ({size})'**
  String pairSyncingGeneratingKey(String size);

  /// No description provided for @pairSyncingSeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Key: {seed}'**
  String pairSyncingSeedLabel(String seed);

  /// No description provided for @pairSyncingPercentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String pairSyncingPercentComplete(int percent);

  /// No description provided for @pairSuccessConnectionSecured.
  ///
  /// In en, this message translates to:
  /// **'Successfully Connected'**
  String get pairSuccessConnectionSecured;

  /// No description provided for @pairSuccessGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Joined group \"{groupName}\". Secure keys generated locally on your device.'**
  String pairSuccessGroupBody(String groupName);

  /// No description provided for @pairSuccessOneOnOneBody.
  ///
  /// In en, this message translates to:
  /// **'Secure keys exchanged and generated on your device. Connected to {title} with a {label} chat capacity.'**
  String pairSuccessOneOnOneBody(String title, String label);

  /// No description provided for @pairSuccessReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Chats'**
  String get pairSuccessReturnButton;

  /// No description provided for @chatDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat details'**
  String get chatDetailsTitle;

  /// No description provided for @chatDetailsSubtitleWithNick.
  ///
  /// In en, this message translates to:
  /// **'Nick: {nick} · {type}'**
  String chatDetailsSubtitleWithNick(String nick, String type);

  /// No description provided for @chatDetailsOfficialRelay.
  ///
  /// In en, this message translates to:
  /// **'Official relay'**
  String get chatDetailsOfficialRelay;

  /// No description provided for @chatDetailsPrivateNode.
  ///
  /// In en, this message translates to:
  /// **'Private node'**
  String get chatDetailsPrivateNode;

  /// No description provided for @chatDetailsHeaderMeRemaining.
  ///
  /// In en, this message translates to:
  /// **'ME {remaining} · PEER {theirRemaining}'**
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining);

  /// No description provided for @chatDetailsSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get chatDetailsSectionProfile;

  /// No description provided for @chatDetailsProfileExplanation.
  ///
  /// In en, this message translates to:
  /// **'Avatars and nicknames sync automatically when you connect. You can manually sync yours now if needed.'**
  String get chatDetailsProfileExplanation;

  /// No description provided for @chatDetailsProfileSyncButton.
  ///
  /// In en, this message translates to:
  /// **'Sync Profile'**
  String get chatDetailsProfileSyncButton;

  /// No description provided for @chatDetailsProfileSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Profile sent.'**
  String get chatDetailsProfileSnackBar;

  /// No description provided for @chatDetailsSectionPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get chatDetailsSectionPermissions;

  /// No description provided for @chatDetailsPermissionsPhotos.
  ///
  /// In en, this message translates to:
  /// **'Allow sharing photos'**
  String get chatDetailsPermissionsPhotos;

  /// No description provided for @chatDetailsPermissionsEmojis.
  ///
  /// In en, this message translates to:
  /// **'Custom emojis'**
  String get chatDetailsPermissionsEmojis;

  /// No description provided for @chatDetailsPermissionsEmojisAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get chatDetailsPermissionsEmojisAvailable;

  /// No description provided for @chatDetailsPermissionsEmojisNeedsSize.
  ///
  /// In en, this message translates to:
  /// **'Requires larger chat'**
  String get chatDetailsPermissionsEmojisNeedsSize;

  /// No description provided for @chatDetailsSectionMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata Space'**
  String get chatDetailsSectionMetadata;

  /// No description provided for @chatDetailsMetadataExplanation.
  ///
  /// In en, this message translates to:
  /// **'This chat allocates {budget} of the {max} space for settings, profile pictures, and custom emojis.'**
  String chatDetailsMetadataExplanation(String budget, String max);

  /// No description provided for @chatDetailsSectionLanes.
  ///
  /// In en, this message translates to:
  /// **'Secure Lanes'**
  String get chatDetailsSectionLanes;

  /// No description provided for @chatDetailsLanesMySend.
  ///
  /// In en, this message translates to:
  /// **'My send capacity'**
  String get chatDetailsLanesMySend;

  /// No description provided for @chatDetailsLanesPeerSend.
  ///
  /// In en, this message translates to:
  /// **'Peer send capacity'**
  String get chatDetailsLanesPeerSend;

  /// No description provided for @chatDetailsLanesBorrowed.
  ///
  /// In en, this message translates to:
  /// **'Borrowed space'**
  String get chatDetailsLanesBorrowed;

  /// No description provided for @chatDetailsLanesCapacityLeft.
  ///
  /// In en, this message translates to:
  /// **'My remaining capacity'**
  String get chatDetailsLanesCapacityLeft;

  /// No description provided for @chatDetailsLanesExplanation.
  ///
  /// In en, this message translates to:
  /// **'If you run low on chat capacity, you can borrow unused space from your peer. This can also happen automatically so you can keep chatting.'**
  String get chatDetailsLanesExplanation;

  /// No description provided for @chatDetailsLanesBorrowButton.
  ///
  /// In en, this message translates to:
  /// **'Request chat space'**
  String get chatDetailsLanesBorrowButton;

  /// No description provided for @chatDetailsLanesSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Request sent to peer.'**
  String get chatDetailsLanesSnackBar;

  /// No description provided for @chatDetailsSectionEmojis.
  ///
  /// In en, this message translates to:
  /// **'Custom emojis'**
  String get chatDetailsSectionEmojis;

  /// No description provided for @chatDetailsEmojisExplanation.
  ///
  /// In en, this message translates to:
  /// **'Use these custom emojis in your messages with the :name: format.'**
  String get chatDetailsEmojisExplanation;

  /// No description provided for @chatDetailsEmojisExplanationDisabled.
  ///
  /// In en, this message translates to:
  /// **'This chat capacity is too small for custom emojis. Connect with more capacity to enable them.'**
  String get chatDetailsEmojisExplanationDisabled;

  /// No description provided for @chatDetailsEmojisCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get chatDetailsEmojisCreate;

  /// No description provided for @chatDetailsSectionDestructive.
  ///
  /// In en, this message translates to:
  /// **'Dangerous Settings'**
  String get chatDetailsSectionDestructive;

  /// No description provided for @chatDetailsNukeButton.
  ///
  /// In en, this message translates to:
  /// **'Nuke Chat (Both Sides)'**
  String get chatDetailsNukeButton;

  /// No description provided for @chatDetailsDeleteEmojiTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete emoji?'**
  String get chatDetailsDeleteEmojiTitle;

  /// No description provided for @chatDetailsDeleteEmojiBody.
  ///
  /// In en, this message translates to:
  /// **'This custom emoji will be permanently deleted. Do you want to proceed?'**
  String get chatDetailsDeleteEmojiBody;

  /// No description provided for @chatDetailsDeleteEmojiDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDetailsDeleteEmojiDelete;

  /// No description provided for @chatDetailsAddEmojiSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Added :{name}:'**
  String chatDetailsAddEmojiSnackBar(String name);

  /// No description provided for @chatImageTooLargeSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Image too large ({cost}) for remaining space ({charge}).'**
  String chatImageTooLargeSnackBar(String cost, String charge);

  /// No description provided for @chatImageExceedsMaxSizeSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Image too large to send.'**
  String get chatImageExceedsMaxSizeSnackBar;

  /// Shown when a free-tier user tries to send an image bigger than the 5 MB free limit but within the 50 MB Plus limit.
  ///
  /// In en, this message translates to:
  /// **'Image too large for the free tier — WiltKey Plus raises the limit to 50 MB.'**
  String get chatImageNeedsPlusSnackBar;

  /// No description provided for @chatTapForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for details'**
  String get chatTapForDetails;

  /// No description provided for @chatSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync messages'**
  String get chatSyncTooltip;

  /// No description provided for @chatStickerHint.
  ///
  /// In en, this message translates to:
  /// **'Hold an emoji to send a sticker'**
  String get chatStickerHint;

  /// No description provided for @chatSyncStarted.
  ///
  /// In en, this message translates to:
  /// **'Checking for missed messages…'**
  String get chatSyncStarted;

  /// No description provided for @chatSyncOffline.
  ///
  /// In en, this message translates to:
  /// **'Can\'t sync while offline.'**
  String get chatSyncOffline;

  /// No description provided for @chatEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting…'**
  String get chatEncrypting;

  /// No description provided for @chatScreenshotDetected.
  ///
  /// In en, this message translates to:
  /// **'Screenshot Detected'**
  String get chatScreenshotDetected;

  /// No description provided for @chatScreenshotExplanation.
  ///
  /// In en, this message translates to:
  /// **'A screenshot was detected. For your security, you can wipe your keys and messages now.'**
  String get chatScreenshotExplanation;

  /// No description provided for @chatScreenshotWipeButton.
  ///
  /// In en, this message translates to:
  /// **'Wipe messages and keys'**
  String get chatScreenshotWipeButton;

  /// No description provided for @chatScreenshotIgnoreButton.
  ///
  /// In en, this message translates to:
  /// **'Ignore warning'**
  String get chatScreenshotIgnoreButton;

  /// No description provided for @chatSimulateScreenshotButton.
  ///
  /// In en, this message translates to:
  /// **'Simulate screenshot'**
  String get chatSimulateScreenshotButton;

  /// No description provided for @chatCostIndicator.
  ///
  /// In en, this message translates to:
  /// **'Cost: {cost}'**
  String chatCostIndicator(String cost);

  /// No description provided for @groupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get groupCreateTitle;

  /// No description provided for @groupCreatePixelArtIcon.
  ///
  /// In en, this message translates to:
  /// **'Group Icon'**
  String get groupCreatePixelArtIcon;

  /// No description provided for @groupCreateRandomIcon.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get groupCreateRandomIcon;

  /// No description provided for @groupCreateClearIcon.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get groupCreateClearIcon;

  /// No description provided for @groupCreateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupCreateNameLabel;

  /// No description provided for @groupCreateNameEmptyValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name'**
  String get groupCreateNameEmptyValidator;

  /// No description provided for @groupCreateNameLengthValidator.
  ///
  /// In en, this message translates to:
  /// **'Maximum 24 characters'**
  String get groupCreateNameLengthValidator;

  /// No description provided for @groupCreatePoliciesSection.
  ///
  /// In en, this message translates to:
  /// **'Group Policy Settings'**
  String get groupCreatePoliciesSection;

  /// No description provided for @groupCreatePolicyPadSize.
  ///
  /// In en, this message translates to:
  /// **'Group Chat Size'**
  String get groupCreatePolicyPadSize;

  /// No description provided for @groupCreatePolicyLaneSize.
  ///
  /// In en, this message translates to:
  /// **'Capacity per member'**
  String get groupCreatePolicyLaneSize;

  /// No description provided for @groupCreatePolicyMaxMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Max member capacity'**
  String get groupCreatePolicyMaxMembersLabel;

  /// No description provided for @groupCreatePolicyMaxMembersValue.
  ///
  /// In en, this message translates to:
  /// **'{count} members max'**
  String groupCreatePolicyMaxMembersValue(int count);

  /// No description provided for @groupCreatePolicyAllowImages.
  ///
  /// In en, this message translates to:
  /// **'Allow sharing photos'**
  String get groupCreatePolicyAllowImages;

  /// No description provided for @groupCreatePolicyAllowImagesSub.
  ///
  /// In en, this message translates to:
  /// **'Allow members to send photos'**
  String get groupCreatePolicyAllowImagesSub;

  /// No description provided for @groupCreatePolicyPayloadSize.
  ///
  /// In en, this message translates to:
  /// **'Max message size'**
  String get groupCreatePolicyPayloadSize;

  /// No description provided for @groupCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get groupCreateButton;

  /// No description provided for @groupCreateProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating group…'**
  String get groupCreateProgressTitle;

  /// No description provided for @groupCreateProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing your group\'s encryption pad and member capacity. This can take a moment — hang tight.'**
  String get groupCreateProgressSubtitle;

  /// No description provided for @groupCreateFailedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group: {error}'**
  String groupCreateFailedSnackBar(String error);

  /// No description provided for @pairSyncingAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for friend to accept...'**
  String get pairSyncingAwaitingApproval;

  /// No description provided for @pairSyncingCoordinating.
  ///
  /// In en, this message translates to:
  /// **'Setting up key exchange...'**
  String get pairSyncingCoordinating;

  /// No description provided for @pairSyncingStep1.
  ///
  /// In en, this message translates to:
  /// **'Establishing secure link...'**
  String get pairSyncingStep1;

  /// No description provided for @pairSyncingStep2.
  ///
  /// In en, this message translates to:
  /// **'Generating security seed...'**
  String get pairSyncingStep2;

  /// No description provided for @pairSyncingStep3.
  ///
  /// In en, this message translates to:
  /// **'Exchanging public keys... {seed}'**
  String pairSyncingStep3(String seed);

  /// No description provided for @pairSyncingStep4.
  ///
  /// In en, this message translates to:
  /// **'Generating secure chat keys...'**
  String get pairSyncingStep4;

  /// No description provided for @pairSyncingStep5.
  ///
  /// In en, this message translates to:
  /// **'Verifying key integrity...'**
  String get pairSyncingStep5;

  /// No description provided for @pairSyncingStep6.
  ///
  /// In en, this message translates to:
  /// **'Secure setup completed successfully.'**
  String get pairSyncingStep6;

  /// No description provided for @chatRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'{bytes} remaining'**
  String chatRemainingLabel(String bytes);

  /// No description provided for @chatLockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Locked · pair in person to continue'**
  String get chatLockedLabel;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatMessageHint;

  /// No description provided for @chatVoiceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Voice messages are coming soon.'**
  String get chatVoiceComingSoon;

  /// No description provided for @chatVoiceHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to record a voice message.'**
  String get chatVoiceHoldHint;

  /// No description provided for @chatVoiceReleaseCancel.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get chatVoiceReleaseCancel;

  /// No description provided for @chatVoiceSlideToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel'**
  String get chatVoiceSlideToCancel;

  /// No description provided for @chatVoiceSlideToLock.
  ///
  /// In en, this message translates to:
  /// **'Slide up to lock'**
  String get chatVoiceSlideToLock;

  /// No description provided for @chatVoiceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel recording'**
  String get chatVoiceCancel;

  /// No description provided for @chatVoiceSend.
  ///
  /// In en, this message translates to:
  /// **'Send voice message'**
  String get chatVoiceSend;

  /// No description provided for @chatVoicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to record voice messages.'**
  String get chatVoicePermissionDenied;

  /// No description provided for @chatVoiceQualityLofi.
  ///
  /// In en, this message translates to:
  /// **'Lo-fi'**
  String get chatVoiceQualityLofi;

  /// No description provided for @chatVoiceQualityVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get chatVoiceQualityVoice;

  /// No description provided for @chatVoiceQualityClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get chatVoiceQualityClear;

  /// No description provided for @chatVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice note unavailable'**
  String get chatVoiceUnavailable;

  /// No description provided for @chatVoiceTooLargeSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Voice note too large ({cost}) for remaining space ({charge}).'**
  String chatVoiceTooLargeSnackBar(String cost, String charge);

  /// No description provided for @chatDetailsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get chatDetailsDeleteConfirmTitle;

  /// No description provided for @chatDetailsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all messages and encryption keys for this contact. This cannot be undone.'**
  String get chatDetailsDeleteConfirmBody;

  /// No description provided for @chatDetailsDeleteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get chatDetailsDeleteConfirmButton;

  /// No description provided for @chatsActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatsActionArchive;

  /// No description provided for @chatsActionNuke.
  ///
  /// In en, this message translates to:
  /// **'Nuke chat'**
  String get chatsActionNuke;

  /// No description provided for @chatsActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatsActionDelete;

  /// No description provided for @chatsArchivedBadge.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get chatsArchivedBadge;

  /// No description provided for @chatsArchivedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Archived · read-only'**
  String get chatsArchivedSubtitle;

  /// No description provided for @chatsArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive chat?'**
  String get chatsArchiveConfirmTitle;

  /// No description provided for @chatsArchiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This frees up space by deleting this chat\'s one-time pad. Your messages stay readable, but the chat becomes read-only — you can\'t send or receive in it again.'**
  String get chatsArchiveConfirmBody;

  /// No description provided for @chatsArchiveConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatsArchiveConfirmButton;

  /// No description provided for @chatsActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatsActionPin;

  /// No description provided for @chatsActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatsActionUnpin;

  /// No description provided for @chatsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chatsFilterAll;

  /// No description provided for @chatsFilterDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get chatsFilterDirect;

  /// No description provided for @chatsFilterGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get chatsFilterGroups;

  /// No description provided for @chatsSectionArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get chatsSectionArchived;

  /// No description provided for @groupTapForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for details · Host: {hostName}'**
  String groupTapForDetails(String hostName);

  /// No description provided for @groupEmptySlots.
  ///
  /// In en, this message translates to:
  /// **'{count} empty lane {count, plural, =1{slot} other{slots}} available'**
  String groupEmptySlots(int count);

  /// No description provided for @groupHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get groupHost;

  /// No description provided for @groupMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get groupMember;

  /// No description provided for @groupDepleted.
  ///
  /// In en, this message translates to:
  /// **'Depleted'**
  String get groupDepleted;

  /// No description provided for @groupNotYetMet.
  ///
  /// In en, this message translates to:
  /// **'Not yet met'**
  String get groupNotYetMet;

  /// No description provided for @groupRechargeButton.
  ///
  /// In en, this message translates to:
  /// **'Recharge group'**
  String get groupRechargeButton;

  /// No description provided for @groupRechargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Recharge group?'**
  String get groupRechargeTitle;

  /// No description provided for @groupRechargeBody.
  ///
  /// In en, this message translates to:
  /// **'Starts a fresh secure enclave with a new key. Everyone keeps their message history, but each member must meet you again in person to rejoin. Members you don\'t re-add keep their history but lose access.'**
  String get groupRechargeBody;

  /// No description provided for @groupRechargeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Recharge'**
  String get groupRechargeConfirm;

  /// No description provided for @groupRechargeDone.
  ///
  /// In en, this message translates to:
  /// **'Group recharged — meet members again to re-add them.'**
  String get groupRechargeDone;

  /// No description provided for @groupRechargeNeededComposer.
  ///
  /// In en, this message translates to:
  /// **'Host recharged this group — meet them again to rejoin'**
  String get groupRechargeNeededComposer;

  /// No description provided for @groupTimeWiltToggle.
  ///
  /// In en, this message translates to:
  /// **'Time Wilt group'**
  String get groupTimeWiltToggle;

  /// No description provided for @groupTimeWiltToggleSub.
  ///
  /// In en, this message translates to:
  /// **'Limited time, unlimited budget. The group wilts to read-only when your timer runs out; meet the host again to renew it.'**
  String get groupTimeWiltToggleSub;

  /// No description provided for @groupTimeWiltMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Max members'**
  String get groupTimeWiltMembersLabel;

  /// No description provided for @groupTimeWiltMembersUpsell.
  ///
  /// In en, this message translates to:
  /// **'Unlock up to 100 members with Plus'**
  String get groupTimeWiltMembersUpsell;

  /// No description provided for @groupTimeWiltHostInfinite.
  ///
  /// In en, this message translates to:
  /// **'Host · ∞'**
  String get groupTimeWiltHostInfinite;

  /// No description provided for @groupTimeWiltRenewComposer.
  ///
  /// In en, this message translates to:
  /// **'Wilted — meet the host again to renew your access'**
  String get groupTimeWiltRenewComposer;

  /// No description provided for @groupTimeWiltHostAllWilted.
  ///
  /// In en, this message translates to:
  /// **'All members have wilted — meet someone again to revive the group'**
  String get groupTimeWiltHostAllWilted;

  /// No description provided for @groupNukeProposeButton.
  ///
  /// In en, this message translates to:
  /// **'Propose destroying for everyone'**
  String get groupNukeProposeButton;

  /// No description provided for @groupNukeProposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Destroy this group for everyone?'**
  String get groupNukeProposeTitle;

  /// No description provided for @groupNukeProposeBody.
  ///
  /// In en, this message translates to:
  /// **'Asks the other members to vote. If a majority agree, the group and its history are destroyed on every device. This can\'t be undone.'**
  String get groupNukeProposeBody;

  /// No description provided for @groupNukeProposeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Propose'**
  String get groupNukeProposeConfirm;

  /// No description provided for @groupNukeVoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Destroy group?'**
  String get groupNukeVoteTitle;

  /// No description provided for @groupNukeVoteBody.
  ///
  /// In en, this message translates to:
  /// **'A member proposed destroying this group for everyone. If a majority agree, it\'s wiped on every device.'**
  String get groupNukeVoteBody;

  /// No description provided for @groupNukeVoteAllow.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get groupNukeVoteAllow;

  /// No description provided for @groupNukeVoteDeny.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get groupNukeVoteDeny;

  /// No description provided for @groupNukeVotePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for members to vote…'**
  String get groupNukeVotePending;

  /// No description provided for @groupNukeVotePassed.
  ///
  /// In en, this message translates to:
  /// **'The group was destroyed by majority vote.'**
  String get groupNukeVotePassed;

  /// No description provided for @groupNukeVoteFailed.
  ///
  /// In en, this message translates to:
  /// **'The proposal to destroy the group did not pass.'**
  String get groupNukeVoteFailed;

  /// No description provided for @groupNukeVoteSent.
  ///
  /// In en, this message translates to:
  /// **'Proposal sent — waiting for members to vote.'**
  String get groupNukeVoteSent;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet. Events like a chat being destroyed will show up here.'**
  String get activityEmpty;

  /// No description provided for @activityClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get activityClear;

  /// No description provided for @activityClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear activity?'**
  String get activityClearConfirmTitle;

  /// No description provided for @activityClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all activity entries from this device. It can\'t be undone.'**
  String get activityClearConfirmBody;

  /// No description provided for @eventNukeReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat destroyed'**
  String get eventNukeReceivedTitle;

  /// No description provided for @eventNukeReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'A secure chat was destroyed.'**
  String get eventNukeReceivedBody;

  /// No description provided for @eventGroupNukedTitle.
  ///
  /// In en, this message translates to:
  /// **'Group destroyed'**
  String get eventGroupNukedTitle;

  /// No description provided for @eventGroupNukedBody.
  ///
  /// In en, this message translates to:
  /// **'A secure group was destroyed.'**
  String get eventGroupNukedBody;

  /// No description provided for @eventContactRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a contact request'**
  String eventContactRequestTitle(String name);

  /// No description provided for @eventContactRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to accept or decline in your chat'**
  String get eventContactRequestBody;

  /// No description provided for @eventContactRemovedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} removed you'**
  String eventContactRemovedTitle(String name);

  /// No description provided for @eventContactRemovedBody.
  ///
  /// In en, this message translates to:
  /// **'They removed you from their contacts'**
  String get eventContactRemovedBody;

  /// No description provided for @groupSyncingFromMember.
  ///
  /// In en, this message translates to:
  /// **'Syncing details and messages from {name}...'**
  String groupSyncingFromMember(String name);

  /// No description provided for @groupInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite member'**
  String get groupInviteMember;

  /// No description provided for @groupLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeaveGroup;

  /// No description provided for @groupRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get groupRemoveMember;

  /// No description provided for @groupRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get groupRemoveMemberTitle;

  /// No description provided for @groupRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the group? This drains their pairwise key.'**
  String groupRemoveMemberBody(String name);

  /// No description provided for @groupLeaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave group?'**
  String get groupLeaveGroupTitle;

  /// No description provided for @groupLeaveGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Leave this group? Wipes local pairwise keys and logs.'**
  String get groupLeaveGroupBody;

  /// No description provided for @groupSyncStepText.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get groupSyncStepText;

  /// No description provided for @groupDecryptingImage.
  ///
  /// In en, this message translates to:
  /// **'Decrypting image...'**
  String get groupDecryptingImage;

  /// No description provided for @chatFileTapToDownload.
  ///
  /// In en, this message translates to:
  /// **'Tap to download'**
  String get chatFileTapToDownload;

  /// No description provided for @chatFileDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get chatFileDownloadFailed;

  /// No description provided for @chatFileKindPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatFileKindPhoto;

  /// No description provided for @chatFileKindVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get chatFileKindVoice;

  /// No description provided for @chatFileKindFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileKindFile;

  /// No description provided for @groupTapToRevealImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal image'**
  String get groupTapToRevealImage;

  /// No description provided for @groupImageSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String groupImageSize(String size);

  /// No description provided for @groupImageFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get groupImageFailedToLoad;

  /// No description provided for @groupScreenshotWipeButton.
  ///
  /// In en, this message translates to:
  /// **'Wipe all keys now'**
  String get groupScreenshotWipeButton;

  /// No description provided for @groupRefillGranted.
  ///
  /// In en, this message translates to:
  /// **'Lane refill granted successfully.'**
  String get groupRefillGranted;

  /// No description provided for @groupRefillFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to grant refill: {error}'**
  String groupRefillFailed(String error);

  /// No description provided for @groupLaneDepleted.
  ///
  /// In en, this message translates to:
  /// **'Lane depleted'**
  String get groupLaneDepleted;

  /// No description provided for @groupLaneDepletedExplanation.
  ///
  /// In en, this message translates to:
  /// **'Request byte refill from the group host.'**
  String get groupLaneDepletedExplanation;

  /// No description provided for @groupRefillRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Refill request transmitted to host.'**
  String get groupRefillRequestSent;

  /// No description provided for @groupRequestRefill.
  ///
  /// In en, this message translates to:
  /// **'Request refill'**
  String get groupRequestRefill;

  /// No description provided for @groupExceedsSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Exceeds size limit ({size} B)'**
  String groupExceedsSizeLimit(int size);

  /// No description provided for @groupDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group details'**
  String get groupDetailsTitle;

  /// No description provided for @groupDetailsSharedPadHost.
  ///
  /// In en, this message translates to:
  /// **'Shared pad · Host: {hostName}'**
  String groupDetailsSharedPadHost(String hostName);

  /// No description provided for @groupDetailsSectionEditPolicies.
  ///
  /// In en, this message translates to:
  /// **'Group Policies'**
  String get groupDetailsSectionEditPolicies;

  /// No description provided for @groupDetailsSavePoliciesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Policies'**
  String get groupDetailsSavePoliciesButton;

  /// No description provided for @groupDetailsSavePoliciesSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Group policies saved.'**
  String get groupDetailsSavePoliciesSnackBar;

  /// No description provided for @groupDetailsSectionEmojis.
  ///
  /// In en, this message translates to:
  /// **'Custom Emojis'**
  String get groupDetailsSectionEmojis;

  /// No description provided for @groupDetailsSectionMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata Space'**
  String get groupDetailsSectionMetadata;

  /// No description provided for @groupDetailsMetadataExplanation.
  ///
  /// In en, this message translates to:
  /// **'Slot 0 of the shared pad reserves 1 MB for group metadata — the group icon, member roster, and custom emojis live here.'**
  String get groupDetailsMetadataExplanation;

  /// No description provided for @groupDetailsSectionSync.
  ///
  /// In en, this message translates to:
  /// **'Group Sync'**
  String get groupDetailsSectionSync;

  /// No description provided for @groupDetailsSyncExplanation.
  ///
  /// In en, this message translates to:
  /// **'Request the latest group details, policies, and member lists from the host.'**
  String get groupDetailsSyncExplanation;

  /// No description provided for @groupDetailsSyncButton.
  ///
  /// In en, this message translates to:
  /// **'Sync Details'**
  String get groupDetailsSyncButton;

  /// No description provided for @groupDetailsSyncSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Requested group update from host.'**
  String get groupDetailsSyncSnackBar;

  /// No description provided for @groupDetailsSectionDestructive.
  ///
  /// In en, this message translates to:
  /// **'Dangerous Settings'**
  String get groupDetailsSectionDestructive;

  /// No description provided for @groupDetailsLeaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get groupDetailsLeaveButton;

  /// No description provided for @groupDetailsNukeButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get groupDetailsNukeButton;

  /// No description provided for @groupDetailsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get groupDetailsDeleteConfirmTitle;

  /// No description provided for @groupDetailsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this group and wipe all chat history and keys for all members. This cannot be undone.'**
  String get groupDetailsDeleteConfirmBody;

  /// No description provided for @groupDetailsDeleteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get groupDetailsDeleteConfirmButton;

  /// No description provided for @chatImageCompressionTitle.
  ///
  /// In en, this message translates to:
  /// **'Compress image'**
  String get chatImageCompressionTitle;

  /// No description provided for @chatImageCompressionOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original: {size}'**
  String chatImageCompressionOriginal(String size);

  /// No description provided for @chatImageCompressionEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated: {size}'**
  String chatImageCompressionEstimated(String size);

  /// No description provided for @chatImageCompressionEstimatedWithSaving.
  ///
  /// In en, this message translates to:
  /// **'Estimated: {size} (saving ~{saving})'**
  String chatImageCompressionEstimatedWithSaving(String size, String saving);

  /// No description provided for @chatImageCompressionCost.
  ///
  /// In en, this message translates to:
  /// **'Payload sent: ~{cost}'**
  String chatImageCompressionCost(String cost);

  /// No description provided for @chatImageCompressionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Converted to WebP, max 2000px.'**
  String get chatImageCompressionExplanation;

  /// No description provided for @chatImageCompressionLowSize.
  ///
  /// In en, this message translates to:
  /// **'Low size'**
  String get chatImageCompressionLowSize;

  /// No description provided for @chatImageCompressionHighSize.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get chatImageCompressionHighSize;

  /// No description provided for @chatImageCompressionMaxQuality.
  ///
  /// In en, this message translates to:
  /// **'Max quality'**
  String get chatImageCompressionMaxQuality;

  /// Last slider step past 100% WebP: full resolution, no downscale.
  ///
  /// In en, this message translates to:
  /// **'Uncompressed'**
  String get chatImageCompressionUncompressed;

  /// No description provided for @chatImageCompressionPercentQuality.
  ///
  /// In en, this message translates to:
  /// **'{percent}% quality'**
  String chatImageCompressionPercentQuality(int percent);

  /// No description provided for @chatImageCompressionSendHidden.
  ///
  /// In en, this message translates to:
  /// **'Send hidden (tap to reveal)'**
  String get chatImageCompressionSendHidden;

  /// No description provided for @chatImageCompressionSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatImageCompressionSendButton;

  /// No description provided for @groupGrantRefill.
  ///
  /// In en, this message translates to:
  /// **'Grant refill'**
  String get groupGrantRefill;

  /// No description provided for @groupLaneLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked · out of bytes'**
  String get groupLaneLocked;

  /// No description provided for @groupMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Members'**
  String get groupMembersTitle;

  /// No description provided for @groupMembersExplanation.
  ///
  /// In en, this message translates to:
  /// **'All members share one chat size split into lanes. Messages are sent through the server.'**
  String get groupMembersExplanation;

  /// No description provided for @pairChatSize.
  ///
  /// In en, this message translates to:
  /// **'Chat Size'**
  String get pairChatSize;

  /// No description provided for @chatSystemConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected. Chat session secure.'**
  String get chatSystemConnected;

  /// No description provided for @chatSystemJoinedGroup.
  ///
  /// In en, this message translates to:
  /// **'Joined group \"{groupName}\". Connections secure.'**
  String chatSystemJoinedGroup(String groupName);

  /// No description provided for @themeCyberpunkName.
  ///
  /// In en, this message translates to:
  /// **'Neon Grid'**
  String get themeCyberpunkName;

  /// No description provided for @themeCyberpunkDesc.
  ///
  /// In en, this message translates to:
  /// **'The original. Obsidian, glowing cyan, terminal type.'**
  String get themeCyberpunkDesc;

  /// No description provided for @themeGardenName.
  ///
  /// In en, this message translates to:
  /// **'Dusk Garden'**
  String get themeGardenName;

  /// No description provided for @themeGardenDesc.
  ///
  /// In en, this message translates to:
  /// **'Soft soil tones, warm linen, petals for your budget.'**
  String get themeGardenDesc;

  /// No description provided for @themePaperinkName.
  ///
  /// In en, this message translates to:
  /// **'Paper & Ink'**
  String get themePaperinkName;

  /// No description provided for @themePaperinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm washi paper, sumi ink dilutions, vermilion hanko seal.'**
  String get themePaperinkDesc;

  /// Snackbar shown on the FOSS build when tapping a locked premium theme (which can only be bought in the Play version).
  ///
  /// In en, this message translates to:
  /// **'This theme is exclusive to the Play Store version of WiltKey.'**
  String get themePickerPlayExclusive;

  /// No description provided for @themePreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get themePreviewTooltip;

  /// No description provided for @themePreviewSectionDashboard.
  ///
  /// In en, this message translates to:
  /// **'Chat list'**
  String get themePreviewSectionDashboard;

  /// No description provided for @themePreviewSectionChat.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get themePreviewSectionChat;

  /// No description provided for @themePreviewSectionEffects.
  ///
  /// In en, this message translates to:
  /// **'Special effects'**
  String get themePreviewSectionEffects;

  /// No description provided for @themePreviewPlayUnlock.
  ///
  /// In en, this message translates to:
  /// **'Play unlock animation'**
  String get themePreviewPlayUnlock;

  /// No description provided for @themePreviewPlayNuke.
  ///
  /// In en, this message translates to:
  /// **'Play self-destruct animation'**
  String get themePreviewPlayNuke;

  /// No description provided for @themePreviewApply.
  ///
  /// In en, this message translates to:
  /// **'Use this theme'**
  String get themePreviewApply;

  /// No description provided for @themePreviewGetInShop.
  ///
  /// In en, this message translates to:
  /// **'Get it in the shop'**
  String get themePreviewGetInShop;

  /// No description provided for @themePreviewMsgThem1.
  ///
  /// In en, this message translates to:
  /// **'Only 800 bytes left on our pad, wanna meet up?'**
  String get themePreviewMsgThem1;

  /// No description provided for @themePreviewMsgMe.
  ///
  /// In en, this message translates to:
  /// **'Sure! Movie night at mine? We can recharge too'**
  String get themePreviewMsgMe;

  /// No description provided for @themePreviewMsgThem2.
  ///
  /// In en, this message translates to:
  /// **'deal, bringing snacks 🍿'**
  String get themePreviewMsgThem2;

  /// No description provided for @themePreviewRowPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo from the bouldering gym 🧗'**
  String get themePreviewRowPhoto;

  /// No description provided for @themePreviewRowLost.
  ///
  /// In en, this message translates to:
  /// **'Out of pad — meet up to recharge'**
  String get themePreviewRowLost;

  /// No description provided for @themePreviewSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile backdrop'**
  String get themePreviewSectionProfile;

  /// No description provided for @themePreviewFullscreenProfile.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen profile preview'**
  String get themePreviewFullscreenProfile;

  /// No description provided for @linkWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'External link warning'**
  String get linkWarningTitle;

  /// No description provided for @linkWarningBody.
  ///
  /// In en, this message translates to:
  /// **'You are about to open an external link in your browser. This will connect to the destination server and reveal your IP address.'**
  String get linkWarningBody;

  /// No description provided for @linkWarningOpen.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get linkWarningOpen;

  /// No description provided for @linkWarningCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get linkWarningCopy;

  /// No description provided for @linkWarningCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkWarningCopied;

  /// No description provided for @chatActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatActionEdit;

  /// No description provided for @chatActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatActionDelete;

  /// No description provided for @chatEditingBanner.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get chatEditingBanner;

  /// No description provided for @chatCancelEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel edit'**
  String get chatCancelEdit;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message for everyone?'**
  String get chatDeleteBody;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteConfirm;

  /// No description provided for @chatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'[Message deleted]'**
  String get chatMessageDeleted;

  /// No description provided for @chatEditedTag.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chatEditedTag;

  /// No description provided for @accessibilityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Accessibility service active'**
  String get accessibilityWarningTitle;

  /// No description provided for @accessibilityWarningBody.
  ///
  /// In en, this message translates to:
  /// **'An accessibility service that can read on-screen content is active: {names}. This is normal for tools like screen readers or password managers. If you didn\'t turn one on, review your accessibility settings.'**
  String accessibilityWarningBody(String names);

  /// No description provided for @accessibilityWarningDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get accessibilityWarningDismiss;

  /// No description provided for @accessibilityWarningOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Review settings'**
  String get accessibilityWarningOpenSettings;

  /// No description provided for @chatImageCompressionAllowDownload.
  ///
  /// In en, this message translates to:
  /// **'Allow saving to gallery'**
  String get chatImageCompressionAllowDownload;

  /// Toggle in the image send dialog to make the image a disappearing (wilting) one.
  ///
  /// In en, this message translates to:
  /// **'Wilting image (disappears after opening)'**
  String get chatImageCompressionWilting;

  /// No description provided for @chatImageDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get chatImageDownload;

  /// No description provided for @chatImageSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get chatImageSaveAs;

  /// No description provided for @chatImageSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get chatImageSavedToGallery;

  /// No description provided for @chatImageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the image'**
  String get chatImageSaveFailed;

  /// No description provided for @chatImageSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a photo'**
  String get chatImageSourceTitle;

  /// No description provided for @chatImageSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get chatImageSourceCamera;

  /// No description provided for @chatImageSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chatImageSourceGallery;

  /// No description provided for @screenshotRequestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Request screenshot'**
  String get screenshotRequestTooltip;

  /// No description provided for @screenshotWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval…'**
  String get screenshotWaiting;

  /// No description provided for @screenshotConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Screenshot request'**
  String get screenshotConsentTitle;

  /// No description provided for @screenshotConsentBody.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to save a screenshot of this chat. Allow it?'**
  String screenshotConsentBody(String name);

  /// No description provided for @screenshotDenied.
  ///
  /// In en, this message translates to:
  /// **'Screenshot request was declined.'**
  String get screenshotDenied;

  /// No description provided for @screenshotCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t capture the screenshot.'**
  String get screenshotCaptureFailed;

  /// No description provided for @screenshotWatermark.
  ///
  /// In en, this message translates to:
  /// **'WiltKey — Screenshot with consent'**
  String get screenshotWatermark;

  /// Title of the in-history screenshot-request card.
  ///
  /// In en, this message translates to:
  /// **'{name} requested a screenshot'**
  String screenshotRequestInline(String name);

  /// No description provided for @screenshotRequestAllowed.
  ///
  /// In en, this message translates to:
  /// **'You allowed the screenshot'**
  String get screenshotRequestAllowed;

  /// No description provided for @screenshotRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'You declined the screenshot'**
  String get screenshotRequestDeclined;

  /// No description provided for @screenshotRequestExpired.
  ///
  /// In en, this message translates to:
  /// **'Screenshot request expired'**
  String get screenshotRequestExpired;

  /// Gated placeholder for a received disappearing message before it is opened.
  ///
  /// In en, this message translates to:
  /// **'Tap to see wilting message'**
  String get wiltingTapToReveal;

  /// Small tag shown on your own copy of a sent disappearing message.
  ///
  /// In en, this message translates to:
  /// **'Wilting message'**
  String get wiltingMessageTag;

  /// Tombstone shown once a disappearing message has expired and its content was destroyed.
  ///
  /// In en, this message translates to:
  /// **'Wilted message'**
  String get wiltedMessage;

  /// Title of the sheet for composing a disappearing message.
  ///
  /// In en, this message translates to:
  /// **'Wilting message'**
  String get wiltingSheetTitle;

  /// Explanation in the disappearing-message duration sheet.
  ///
  /// In en, this message translates to:
  /// **'The message disappears this many seconds after the recipient opens it.'**
  String get wiltingSheetBody;

  /// Confirm button in the disappearing-message duration sheet.
  ///
  /// In en, this message translates to:
  /// **'Send wilting message'**
  String get wiltingSheetSend;

  /// Tooltip on the send button hinting the long-press to send a disappearing message.
  ///
  /// In en, this message translates to:
  /// **'Hold to send a wilting message'**
  String get wiltingHoldToSendHint;

  /// Author label in a reply quote when quoting the local user's own message.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get replyYou;

  /// Fallback author label in a reply quote when the sender's name can't be resolved.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get replySomeone;

  /// One-line preview shown in a reply quote when the quoted message is an image.
  ///
  /// In en, this message translates to:
  /// **'📷 Photo'**
  String get replyPreviewImage;

  /// One-line preview shown in a reply quote when the quoted message is a voice note.
  ///
  /// In en, this message translates to:
  /// **'🎤 Voice message'**
  String get replyPreviewVoice;

  /// Generic one-line preview in a reply quote when there's no showable text.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get replyPreviewMessage;

  /// Shown in a reply quote when the parent message can't be found (not loaded / wilted).
  ///
  /// In en, this message translates to:
  /// **'Original message unavailable'**
  String get replyUnavailable;

  /// Settings row label opening the shop, on the Play build.
  ///
  /// In en, this message translates to:
  /// **'Shop & WiltKey Plus'**
  String get shopEntryTitle;

  /// Settings row subtitle under the shop entry, on the Play build.
  ///
  /// In en, this message translates to:
  /// **'Themes, unlocks & Plus'**
  String get shopEntrySubtitle;

  /// Settings row label opening the support page, on the FOSS build.
  ///
  /// In en, this message translates to:
  /// **'Support the project'**
  String get supportEntryTitle;

  /// Settings row subtitle under the support entry, on the FOSS build.
  ///
  /// In en, this message translates to:
  /// **'Help keep WiltKey running'**
  String get supportEntrySubtitle;

  /// App bar title of the shop screen (Play build).
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTitle;

  /// App bar title of the support screen (FOSS build).
  ///
  /// In en, this message translates to:
  /// **'Support WiltKey'**
  String get supportTitle;

  /// Section header for the subscription in the shop.
  ///
  /// In en, this message translates to:
  /// **'WiltKey Plus'**
  String get shopPlusSection;

  /// Section header for one-time cosmetic unlocks in the shop.
  ///
  /// In en, this message translates to:
  /// **'Unlocks'**
  String get shopUnlocksSection;

  /// One-line description of the WiltKey Plus subscription.
  ///
  /// In en, this message translates to:
  /// **'Longer offline message hold and bigger file transfers.'**
  String get shopPlusTagline;

  /// Title of the shop empty state when no products are available.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get shopEmptyTitle;

  /// Body of the shop empty state when no products are available.
  ///
  /// In en, this message translates to:
  /// **'Products are on the way — check back soon.'**
  String get shopEmptyBody;

  /// Button that re-queries and restores prior purchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get shopRestoreButton;

  /// Snackbar shown after a successful restore.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get shopRestoredSnack;

  /// Button to purchase a shop product.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get shopBuyButton;

  /// Badge on a one-time product the user already owns.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get shopOwnedLabel;

  /// Badge on the subscription when it is currently active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get shopActiveLabel;

  /// Hint under an active subscription pointing to Play to manage it.
  ///
  /// In en, this message translates to:
  /// **'Manage in Google Play'**
  String get shopManageNote;

  /// Snackbar when a purchase is awaiting payment confirmation.
  ///
  /// In en, this message translates to:
  /// **'Purchase pending…'**
  String get shopPurchasePendingSnack;

  /// Snackbar when a purchase attempt fails.
  ///
  /// In en, this message translates to:
  /// **'Purchase couldn\'t be completed'**
  String get shopPurchaseFailedSnack;

  /// Intro paragraph on the FOSS support page.
  ///
  /// In en, this message translates to:
  /// **'WiltKey is free and open source, and this build unlocks every cosmetic for free. If you\'d like to support development and the official relay, visit the page below.'**
  String get supportIntro;

  /// Button that opens the external support/donate URL.
  ///
  /// In en, this message translates to:
  /// **'Open support page'**
  String get supportOpenButton;

  /// Reassurance note on the FOSS support page that cosmetics are free.
  ///
  /// In en, this message translates to:
  /// **'All cosmetics are unlocked in this build.'**
  String get supportFreeNote;

  /// Shop tab label for colour palette packs.
  ///
  /// In en, this message translates to:
  /// **'Palettes'**
  String get shopTabPalettes;

  /// Shop tab label for premium themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get shopTabThemes;

  /// Shop tab label for avatar borders.
  ///
  /// In en, this message translates to:
  /// **'Borders'**
  String get shopTabBorders;

  /// Shop tab label for the WiltKey Plus subscription.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get shopTabPlus;

  /// Shop tab label for promo code redemption.
  ///
  /// In en, this message translates to:
  /// **'Promo'**
  String get shopTabPromo;

  /// Intro paragraph on the shop's palettes tab explaining the render-free rule.
  ///
  /// In en, this message translates to:
  /// **'Extra colours for drawing your avatar and group icons. Art you receive always renders in full — a pack only unlocks drawing with those colours yourself.'**
  String get shopPalettesIntro;

  /// Subtitle on a palette pack card stating how many colours it adds.
  ///
  /// In en, this message translates to:
  /// **'{count} extra colours'**
  String shopPaletteColorCount(int count);

  /// Title of the themes tab empty state when no premium themes are listed.
  ///
  /// In en, this message translates to:
  /// **'No themes yet'**
  String get shopThemesEmptyTitle;

  /// Body of the themes tab empty state.
  ///
  /// In en, this message translates to:
  /// **'Premium themes are on the way — the three built-in themes are free forever.'**
  String get shopThemesEmptyBody;

  /// Title of the avatar borders tab placeholder.
  ///
  /// In en, this message translates to:
  /// **'Borders are coming'**
  String get shopBordersSoonTitle;

  /// Body of the avatar borders tab placeholder.
  ///
  /// In en, this message translates to:
  /// **'Decorative frames for your avatar that everyone you chat with can see. In the works.'**
  String get shopBordersSoonBody;

  /// Section header above the WiltKey Plus benefit list.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get shopPlusBenefitsSection;

  /// Plus benefit: longer offline message hold.
  ///
  /// In en, this message translates to:
  /// **'Your messages wait 72 hours on the relay instead of 24 while you\'re offline.'**
  String get shopPlusBenefitHold;

  /// Plus benefit: future perks included.
  ///
  /// In en, this message translates to:
  /// **'Send large files — up to 50 MB per message, past the 5 MB free limit.'**
  String get shopPlusBenefitFiles;

  /// Plus benefit: larger OTP pad sizes at pairing and group creation.
  ///
  /// In en, this message translates to:
  /// **'Create bigger pads — up to 200 MB for a chat and 500 MB for a group.'**
  String get shopPlusBenefitPads;

  /// Plus benefit: larger Time Wilt group member cap.
  ///
  /// In en, this message translates to:
  /// **'Host bigger Time Wilt groups — up to 100 members instead of 20.'**
  String get shopPlusBenefitTimeWiltGroups;

  /// Plus benefit: supporting the project.
  ///
  /// In en, this message translates to:
  /// **'You keep the relay running and WiltKey independent.'**
  String get shopPlusBenefitSupport;

  /// Button to start the WiltKey Plus subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get shopSubscribeButton;

  /// Shown in place of a price when the product isn't available from Google Play.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get shopPriceUnavailable;

  /// Intro paragraph on the promo code tab.
  ///
  /// In en, this message translates to:
  /// **'Got a promo code? Enter it below and Google Play will apply it to your account.'**
  String get shopPromoIntro;

  /// Placeholder text in the promo code input field.
  ///
  /// In en, this message translates to:
  /// **'PROMO CODE'**
  String get shopPromoHint;

  /// Button that opens the Google Play redeem flow with the entered code.
  ///
  /// In en, this message translates to:
  /// **'Redeem in Google Play'**
  String get shopPromoRedeemButton;

  /// Footnote on the promo tab explaining that redemption happens in Play.
  ///
  /// In en, this message translates to:
  /// **'Codes are redeemed in the Play Store. Once applied, your unlock appears here automatically.'**
  String get shopPromoNote;

  /// Tappable hint under the pairing pad-size slider offering the larger tiers.
  ///
  /// In en, this message translates to:
  /// **'Larger pads with Plus — up to {max}'**
  String pairLargerPadsUpsell(String max);

  /// Warning when the device can't fit the OTP pad the pairing would create.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space — this chat needs {needed} and you have {free}.'**
  String pairNotEnoughSpace(String needed, String free);

  /// Progress label while the OTP pad file is being written during pairing.
  ///
  /// In en, this message translates to:
  /// **'Generating keystream… {written} / {total}'**
  String pairSyncingGenerating(String written, String total);

  /// Caution shown while the OTP pad generates, warning not to quit the app.
  ///
  /// In en, this message translates to:
  /// **'Keep the app open — the secure pad is still being created.'**
  String get pairKeepAppOpen;

  /// Tappable hint under the group total-size slider offering the larger tiers.
  ///
  /// In en, this message translates to:
  /// **'Larger group pads with Plus — up to {max}'**
  String groupLargerPadsUpsell(String max);

  /// Label above the avatar-border picker in Settings.
  ///
  /// In en, this message translates to:
  /// **'Avatar border'**
  String get settingsBorderSection;

  /// Intro paragraph on the shop's avatar-borders tab.
  ///
  /// In en, this message translates to:
  /// **'Frames and accessories for your avatar. Everyone you chat with sees your border — a locked one only stops you equipping it, never how it renders.'**
  String get shopBordersIntro;

  /// Subtitle on an avatar-border shop card.
  ///
  /// In en, this message translates to:
  /// **'Avatar border'**
  String get shopBorderSubtitle;

  /// Badge on a cosmetic that's free for everyone.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get shopFreeLabel;

  /// No description provided for @notificationModePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get notificationModePrivate;

  /// No description provided for @notificationModePrivateDesc.
  ///
  /// In en, this message translates to:
  /// **'Periodically checks for new messages in the background without using Google push services. Alerts may be delayed, but no signals pass through a 3rd-party service.'**
  String get notificationModePrivateDesc;

  /// No description provided for @connectSectionOneOnOne.
  ///
  /// In en, this message translates to:
  /// **'One-on-one'**
  String get connectSectionOneOnOne;

  /// No description provided for @connectSectionGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get connectSectionGroups;

  /// No description provided for @connectByteBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Byte budget'**
  String get connectByteBudgetTitle;

  /// No description provided for @connectByteBudgetDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlimited time, limited budget. Best for long-distance friends and family, and high-security chats.'**
  String get connectByteBudgetDesc;

  /// No description provided for @connectTimeWiltTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Wilt'**
  String get connectTimeWiltTitle;

  /// No description provided for @connectTimeWiltDesc.
  ///
  /// In en, this message translates to:
  /// **'Limited time, unlimited budget. Best for getting to know new people, blind dates, or friends you need an excuse to see.'**
  String get connectTimeWiltDesc;

  /// No description provided for @connectRemotePairTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote pair (testing)'**
  String get connectRemotePairTitle;

  /// No description provided for @connectRemotePairDesc.
  ///
  /// In en, this message translates to:
  /// **'Debug-only: pair with a tester over the relay using a PIN + identity hash.'**
  String get connectRemotePairDesc;

  /// No description provided for @connectByteBudgetGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Byte budget group'**
  String get connectByteBudgetGroupTitle;

  /// No description provided for @connectByteBudgetGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlimited time, limited budget. A group you build by inviting members in person.'**
  String get connectByteBudgetGroupDesc;

  /// No description provided for @connectTimeWiltGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Wilt group'**
  String get connectTimeWiltGroupTitle;

  /// No description provided for @connectTimeWiltGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Limited time, unlimited budget. A casual group whose messages expire as you go.'**
  String get connectTimeWiltGroupDesc;

  /// No description provided for @connectJoinGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get connectJoinGroupTitle;

  /// No description provided for @connectJoinGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Someone nearby invited you — find their group beacon.'**
  String get connectJoinGroupDesc;

  /// No description provided for @connectJoinRemoteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Join remote group (testing)'**
  String get connectJoinRemoteGroupTitle;

  /// No description provided for @connectJoinRemoteGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Debug-only: join a tester\'s group over the relay.'**
  String get connectJoinRemoteGroupDesc;

  /// No description provided for @connectBadgeSoon.
  ///
  /// In en, this message translates to:
  /// **'SOON'**
  String get connectBadgeSoon;

  /// No description provided for @timeWiltLifetimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat lifetime'**
  String get timeWiltLifetimeLabel;

  /// No description provided for @timeWiltPlusHint.
  ///
  /// In en, this message translates to:
  /// **'Unlock up to 6 months with Plus'**
  String get timeWiltPlusHint;

  /// No description provided for @timeWiltExplanation.
  ///
  /// In en, this message translates to:
  /// **'The chat becomes read-only when the timer runs out.'**
  String get timeWiltExplanation;

  /// No description provided for @timeWiltPairRequestDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Accept a Time Wilt chat from {peerName}? It becomes read-only in {lifetime}.'**
  String timeWiltPairRequestDialogBody(String peerName, String lifetime);

  /// No description provided for @timeWiltLifetimeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String timeWiltLifetimeDays(int count);

  /// No description provided for @timeWiltLifetimeHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String timeWiltLifetimeHours(int count);

  /// No description provided for @timeWiltLifetimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String timeWiltLifetimeMinutes(int count);

  /// No description provided for @timeWiltLifetimeMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String timeWiltLifetimeMonths(int count);

  /// No description provided for @timeWiltLifetimeMoments.
  ///
  /// In en, this message translates to:
  /// **'moments'**
  String get timeWiltLifetimeMoments;

  /// No description provided for @navContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get navContacts;

  /// No description provided for @contactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @contactsSectionFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get contactsSectionFriends;

  /// No description provided for @contactsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get contactsEmptyTitle;

  /// No description provided for @contactsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add someone from an existing chat to see them here.'**
  String get contactsEmptyBody;

  /// No description provided for @contactsOwnProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get contactsOwnProfile;

  /// No description provided for @contactsOwnProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to set status or wilting story'**
  String get contactsOwnProfileHint;

  /// No description provided for @contactRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Contact request sent to {name}'**
  String contactRequestSent(String name);

  /// No description provided for @contactRequestReceived.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to add you as a contact'**
  String contactRequestReceived(String name);

  /// No description provided for @contactRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Contact request accepted'**
  String get contactRequestApproved;

  /// No description provided for @contactRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Contact request declined'**
  String get contactRequestDeclined;

  /// No description provided for @contactRequestApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get contactRequestApprove;

  /// No description provided for @contactRequestDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get contactRequestDeny;

  /// No description provided for @contactAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactAddTitle;

  /// No description provided for @contactAddBody.
  ///
  /// In en, this message translates to:
  /// **'Add {name} to your contacts?'**
  String contactAddBody(String name);

  /// No description provided for @contactAddConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactAddConfirm;

  /// No description provided for @contactAddAlready.
  ///
  /// In en, this message translates to:
  /// **'Already in your contacts'**
  String get contactAddAlready;

  /// No description provided for @contactAddSent.
  ///
  /// In en, this message translates to:
  /// **'Contact request sent'**
  String get contactAddSent;

  /// No description provided for @contactProfileOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open Chat'**
  String get contactProfileOpenChat;

  /// No description provided for @contactProfileRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Contact'**
  String get contactProfileRemove;

  /// No description provided for @contactProfileBlock.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get contactProfileBlock;

  /// No description provided for @contactProfileStatusPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'No status yet'**
  String get contactProfileStatusPlaceholder;

  /// No description provided for @contactProfileEmergencyChat.
  ///
  /// In en, this message translates to:
  /// **'Emergency chat'**
  String get contactProfileEmergencyChat;

  /// No description provided for @contactPin.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get contactPin;

  /// No description provided for @contactUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get contactUnpin;

  /// No description provided for @contactUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get contactUnblock;

  /// No description provided for @contactsSectionPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get contactsSectionPinned;

  /// No description provided for @contactStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get contactStatusLabel;

  /// No description provided for @contactStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Share a status with your contacts…'**
  String get contactStatusHint;

  /// No description provided for @contactStatusSave.
  ///
  /// In en, this message translates to:
  /// **'Save status'**
  String get contactStatusSave;

  /// No description provided for @contactStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated'**
  String get contactStatusUpdated;

  /// No description provided for @contactRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String contactRemoveConfirmTitle(String name);

  /// No description provided for @contactRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes them from your contact list. You can add them again later.'**
  String get contactRemoveConfirmBody;

  /// No description provided for @contactBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String contactBlockConfirmTitle(String name);

  /// No description provided for @contactBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to contact you or send contact requests.'**
  String get contactBlockConfirmBody;

  /// No description provided for @settingsBlockedContacts.
  ///
  /// In en, this message translates to:
  /// **'Blocked Contacts'**
  String get settingsBlockedContacts;

  /// No description provided for @settingsBlockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No blocked contacts'**
  String get settingsBlockedEmpty;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get commonBlock;

  /// No description provided for @contactProfileChatNotFound.
  ///
  /// In en, this message translates to:
  /// **'No chat found for this contact — it may have been deleted'**
  String get contactProfileChatNotFound;

  /// No description provided for @emergencyChatStart.
  ///
  /// In en, this message translates to:
  /// **'Start emergency chat'**
  String get emergencyChatStart;

  /// No description provided for @emergencyChatConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start emergency chat with {name}?'**
  String emergencyChatConfirmTitle(String name);

  /// No description provided for @emergencyChatConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This starts a 12-hour Time Wilt chat created remotely, without pairing in person. Any existing chat and messages with {name} will be permanently replaced, and the session will be active once {name} connects.'**
  String emergencyChatConfirmBody(String name);

  /// No description provided for @emergencyChatAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'You already have an active chat with this contact'**
  String get emergencyChatAlreadyActive;

  /// No description provided for @emergencyChatStarted.
  ///
  /// In en, this message translates to:
  /// **'Emergency chat requested'**
  String get emergencyChatStarted;

  /// No description provided for @chatsEmergencyPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting emergency chat…'**
  String get chatsEmergencyPendingSubtitle;

  /// No description provided for @chatsEmergencyPendingSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Emergency chat with {name} is waiting for them to connect.'**
  String chatsEmergencyPendingSnackBar(String name);

  /// No description provided for @emergencyChatPending.
  ///
  /// In en, this message translates to:
  /// **'Emergency chat pending…'**
  String get emergencyChatPending;

  /// No description provided for @gestureSwipeForContacts.
  ///
  /// In en, this message translates to:
  /// **'Swipe from left edge for contacts'**
  String get gestureSwipeForContacts;

  /// No description provided for @contactProfileSafetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Identity Key Fingerprint'**
  String get contactProfileSafetyNumber;

  /// No description provided for @contactProfileWiltedHint.
  ///
  /// In en, this message translates to:
  /// **'Start a temporary 12-hour Time Wilt chat'**
  String get contactProfileWiltedHint;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get commonCopied;

  /// No description provided for @eventMentionTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} mentioned you'**
  String eventMentionTitle(String name);

  /// No description provided for @eventReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} replied to you'**
  String eventReplyTitle(String name);

  /// No description provided for @chatNotificationModeAll.
  ///
  /// In en, this message translates to:
  /// **'All messages'**
  String get chatNotificationModeAll;

  /// No description provided for @chatNotificationModeMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions & replies only'**
  String get chatNotificationModeMentions;

  /// No description provided for @chatNotificationModeMuted.
  ///
  /// In en, this message translates to:
  /// **'Mute (Silent)'**
  String get chatNotificationModeMuted;

  /// No description provided for @chatNotificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get chatNotificationSettingsTitle;

  /// No description provided for @chatMuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Mute chat'**
  String get chatMuteTitle;

  /// No description provided for @chatUnmuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmute chat'**
  String get chatUnmuteTitle;

  /// No description provided for @settingsNotifyCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsNotifyCategories;

  /// No description provided for @settingsNotifyDirectMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get settingsNotifyDirectMessages;

  /// No description provided for @settingsNotifyDirectMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications for 1:1 chat messages'**
  String get settingsNotifyDirectMessagesSubtitle;

  /// No description provided for @settingsNotifyGroupMessages.
  ///
  /// In en, this message translates to:
  /// **'Group Messages'**
  String get settingsNotifyGroupMessages;

  /// No description provided for @settingsNotifyGroupMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications for group chat messages'**
  String get settingsNotifyGroupMessagesSubtitle;

  /// No description provided for @settingsNotifyEvents.
  ///
  /// In en, this message translates to:
  /// **'Security & Activity Events'**
  String get settingsNotifyEvents;

  /// No description provided for @settingsNotifyEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contact requests, group nuke votes, screenshot alerts'**
  String get settingsNotifyEventsSubtitle;

  /// No description provided for @settingsMutedChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Muted Chats'**
  String get settingsMutedChatsTitle;

  /// No description provided for @settingsNoMutedChats.
  ///
  /// In en, this message translates to:
  /// **'No muted chats'**
  String get settingsNoMutedChats;

  /// No description provided for @settingsUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get settingsUnmute;

  /// No description provided for @settingsCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckForUpdates;

  /// No description provided for @settingsCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get settingsCheckingUpdates;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: v{version}'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsUpToDate.
  ///
  /// In en, this message translates to:
  /// **'WiltKey is up to date'**
  String get settingsUpToDate;

  /// No description provided for @settingsWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get settingsWhatsNew;

  /// No description provided for @settingsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage & History'**
  String get settingsStorageSection;

  /// No description provided for @settingsHistoryLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Message History Retention'**
  String get settingsHistoryLimitTitle;

  /// No description provided for @settingsHistoryLimitDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically prune older local messages and media files to conserve storage space. Encryption keys and contacts are always preserved.'**
  String get settingsHistoryLimitDescription;

  /// No description provided for @settingsHistoryLimitAll.
  ///
  /// In en, this message translates to:
  /// **'Keep all messages (Unlimited)'**
  String get settingsHistoryLimitAll;

  /// No description provided for @settingsHistoryLimitCount.
  ///
  /// In en, this message translates to:
  /// **'Keep last {count} messages'**
  String settingsHistoryLimitCount(int count);

  /// No description provided for @chatDetailsClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear Message History'**
  String get chatDetailsClearHistory;

  /// No description provided for @chatDetailsClearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get chatDetailsClearHistoryConfirm;

  /// No description provided for @chatDetailsClearHistoryDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all local message history in this chat? Encryption keys and contact status will be preserved.'**
  String get chatDetailsClearHistoryDialogBody;

  /// No description provided for @chatDetailsClearHistoryPrune100.
  ///
  /// In en, this message translates to:
  /// **'Keep only last 100 messages'**
  String get chatDetailsClearHistoryPrune100;

  /// No description provided for @chatDetailsClearHistorySuccess.
  ///
  /// In en, this message translates to:
  /// **'Chat history cleared'**
  String get chatDetailsClearHistorySuccess;

  /// No description provided for @chatDetailsSectionMedia.
  ///
  /// In en, this message translates to:
  /// **'Media, Voice & Links'**
  String get chatDetailsSectionMedia;

  /// No description provided for @chatDetailsMediaPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get chatDetailsMediaPhotos;

  /// No description provided for @chatDetailsMediaVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice Notes'**
  String get chatDetailsMediaVoice;

  /// No description provided for @chatDetailsMediaLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get chatDetailsMediaLinks;

  /// No description provided for @chatDetailsNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No shared photos yet'**
  String get chatDetailsNoMedia;

  /// No description provided for @chatDetailsNoVoice.
  ///
  /// In en, this message translates to:
  /// **'No voice notes yet'**
  String get chatDetailsNoVoice;

  /// No description provided for @chatDetailsNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No links shared yet'**
  String get chatDetailsNoLinks;

  /// No description provided for @qrConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Connect'**
  String get qrConnectTitle;

  /// No description provided for @qrConnectScanTab.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get qrConnectScanTab;

  /// No description provided for @qrConnectMyCodeTab.
  ///
  /// In en, this message translates to:
  /// **'My QR Code'**
  String get qrConnectMyCodeTab;

  /// No description provided for @qrConnectScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Point camera at a WiltKey QR code to connect instantly'**
  String get qrConnectScanPrompt;

  /// No description provided for @qrConnect7DayNotice.
  ///
  /// In en, this message translates to:
  /// **'Remote connections automatically start as a 7-day Time Wilt chat. In-person BLE pairing is required for one-time pad recharging.'**
  String get qrConnect7DayNotice;

  /// No description provided for @qrConnectRechargeBlocked.
  ///
  /// In en, this message translates to:
  /// **'This contact already exists. Pad recharging requires in-person BLE pairing and cannot be performed remotely.'**
  String get qrConnectRechargeBlocked;

  /// No description provided for @qrConnectManualPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN manually'**
  String get qrConnectManualPin;

  /// No description provided for @qrConnectShowYourCode.
  ///
  /// In en, this message translates to:
  /// **'Scan complete! Now show your QR code to them too.'**
  String get qrConnectShowYourCode;

  /// No description provided for @qrConnectFinishPairing.
  ///
  /// In en, this message translates to:
  /// **'Finish pairing'**
  String get qrConnectFinishPairing;

  /// No description provided for @qrConnectOutdatedCode.
  ///
  /// In en, this message translates to:
  /// **'This QR code is from an older app version. Both of you need the latest update to connect this way.'**
  String get qrConnectOutdatedCode;

  /// No description provided for @qrConnectOwnCode.
  ///
  /// In en, this message translates to:
  /// **'That\'s your own QR code — point the camera at theirs instead.'**
  String get qrConnectOwnCode;

  /// No description provided for @qrConnectAlreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'You already have a chat with this person. Refreshing an existing chat requires an in-person pairing.'**
  String get qrConnectAlreadyPaired;

  /// No description provided for @testRelayBanner.
  ///
  /// In en, this message translates to:
  /// **'TEST SERVER — NOT PRODUCTION'**
  String get testRelayBanner;

  /// No description provided for @securingTitle.
  ///
  /// In en, this message translates to:
  /// **'Securing your connection'**
  String get securingTitle;

  /// No description provided for @securingBody.
  ///
  /// In en, this message translates to:
  /// **'Your device is verifying itself with the relay before connecting. This one-time proof-of-work protects everyone from spam and abuse — no phone number, no email, no account.'**
  String get securingBody;

  /// No description provided for @securingWorking.
  ///
  /// In en, this message translates to:
  /// **'PROVING DEVICE — WORKING…'**
  String get securingWorking;

  /// No description provided for @securingOnceNote.
  ///
  /// In en, this message translates to:
  /// **'This happens only on your first connection. Reconnecting afterwards is instant.'**
  String get securingOnceNote;

  /// No description provided for @puzzleInstruction.
  ///
  /// In en, this message translates to:
  /// **'A piece of your connection check is scrambled. Slide the strip until the picture locks in, then confirm.'**
  String get puzzleInstruction;

  /// No description provided for @puzzleLockIn.
  ///
  /// In en, this message translates to:
  /// **'Lock in'**
  String get puzzleLockIn;

  /// No description provided for @puzzleFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t line up — starting a fresh check…'**
  String get puzzleFailedRetry;

  /// No description provided for @reauthenticatingBanner.
  ///
  /// In en, this message translates to:
  /// **'REAUTHENTICATING — PLEASE WAIT…'**
  String get reauthenticatingBanner;

  /// No description provided for @badgePlayPlus.
  ///
  /// In en, this message translates to:
  /// **'Play Store · Plus'**
  String get badgePlayPlus;

  /// No description provided for @badgePlayPlusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Google Play Build + Plus Supporter'**
  String get badgePlayPlusSubtitle;

  /// No description provided for @badgePlayPlusExplainer.
  ///
  /// In en, this message translates to:
  /// **'This user is running an official, unmodified build verified through Google Play Integrity, and is actively supporting WiltKey with an active Plus membership.'**
  String get badgePlayPlusExplainer;

  /// No description provided for @badgePlayVerified.
  ///
  /// In en, this message translates to:
  /// **'Play Store'**
  String get badgePlayVerified;

  /// No description provided for @badgePlayVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Google Play Build'**
  String get badgePlayVerifiedSubtitle;

  /// No description provided for @badgePlayVerifiedExplainer.
  ///
  /// In en, this message translates to:
  /// **'This user is running an official, unmodified build cryptographically verified through Google Play Integrity.'**
  String get badgePlayVerifiedExplainer;

  /// No description provided for @badgeFoss.
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get badgeFoss;

  /// No description provided for @badgeFossSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community / FOSS Build'**
  String get badgeFossSubtitle;

  /// No description provided for @badgeFossExplainer.
  ///
  /// In en, this message translates to:
  /// **'This client is running an open-source or custom build. Because it does not run Google proprietary services, it is treated as a community build. All messages and encryption remain 100% secure and private.'**
  String get badgeFossExplainer;

  /// No description provided for @groupAnonymousMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get groupAnonymousMember;

  /// No description provided for @groupMemberRoleHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get groupMemberRoleHost;

  /// No description provided for @contactSelfBadge.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get contactSelfBadge;

  /// No description provided for @chatAttachContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach to chat'**
  String get chatAttachContentTitle;

  /// No description provided for @chatAttachPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos & Camera'**
  String get chatAttachPhotos;

  /// No description provided for @chatAttachPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a picture or choose from gallery'**
  String get chatAttachPhotosSubtitle;

  /// No description provided for @chatAttachPixelArt.
  ///
  /// In en, this message translates to:
  /// **'Pixel Art & Avatars'**
  String get chatAttachPixelArt;

  /// No description provided for @chatAttachPixelArtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Draw a pixel drawing or send from saved templates'**
  String get chatAttachPixelArtSubtitle;

  /// No description provided for @chatAttachVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatAttachVideo;

  /// No description provided for @chatAttachVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted short video clips in a future update'**
  String get chatAttachVideoSubtitle;

  /// No description provided for @chatAttachComingSoon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get chatAttachComingSoon;

  /// No description provided for @chatPixelArtDrawNew.
  ///
  /// In en, this message translates to:
  /// **'Draw New Pixel Art'**
  String get chatPixelArtDrawNew;

  /// No description provided for @chatPixelArtTemplates.
  ///
  /// In en, this message translates to:
  /// **'Saved Avatar Templates'**
  String get chatPixelArtTemplates;

  /// No description provided for @chatPixelArtSend.
  ///
  /// In en, this message translates to:
  /// **'Send to Chat'**
  String get chatPixelArtSend;

  /// No description provided for @chatPixelArtNoTemplates.
  ///
  /// In en, this message translates to:
  /// **'No saved avatar templates yet'**
  String get chatPixelArtNoTemplates;

  /// No description provided for @chatPixelArtActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Pixel Art Options'**
  String get chatPixelArtActionTitle;

  /// No description provided for @chatPixelArtActionApplyAvatar.
  ///
  /// In en, this message translates to:
  /// **'Apply as My Profile Avatar'**
  String get chatPixelArtActionApplyAvatar;

  /// No description provided for @chatPixelArtActionSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save to Avatar Templates'**
  String get chatPixelArtActionSaveTemplate;

  /// No description provided for @chatPixelArtActionSaveEmoji.
  ///
  /// In en, this message translates to:
  /// **'Save as Custom Emoji'**
  String get chatPixelArtActionSaveEmoji;

  /// No description provided for @chatPixelArtActionExportPng.
  ///
  /// In en, this message translates to:
  /// **'Export PNG to Photos'**
  String get chatPixelArtActionExportPng;

  /// No description provided for @chatPixelArtActionAppliedAvatarSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile avatar updated and synced'**
  String get chatPixelArtActionAppliedAvatarSuccess;

  /// No description provided for @chatPixelArtActionSavedTemplateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to Avatar Templates library'**
  String get chatPixelArtActionSavedTemplateSuccess;

  /// No description provided for @chatPixelArtActionExportedPngSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved PNG image to photos'**
  String get chatPixelArtActionExportedPngSuccess;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in chat...'**
  String get chatSearchHint;

  /// No description provided for @chatSearchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'0 matches'**
  String get chatSearchNoMatches;

  /// No description provided for @contactPrivateNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Private Notes & Nickname'**
  String get contactPrivateNoteTitle;

  /// No description provided for @contactPrivateNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add private notes about this contact (stored locally only)...'**
  String get contactPrivateNoteHint;

  /// No description provided for @contactCustomNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Nickname'**
  String get contactCustomNicknameTitle;

  /// No description provided for @contactCustomNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Override display name locally...'**
  String get contactCustomNicknameHint;

  /// No description provided for @contactNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Contact details saved'**
  String get contactNotesSaved;

  /// No description provided for @onboardingSocialTitle.
  ///
  /// In en, this message translates to:
  /// **'WiltKey Social Account'**
  String get onboardingSocialTitle;

  /// No description provided for @onboardingSocialExplanation.
  ///
  /// In en, this message translates to:
  /// **'Enables your WiltKey Social profile and server-assisted discovery. Your public identity key is registered with the relay (and can be permanently revoked/wiped anytime by you) to verify authorship of 24h Wilting Stories and broadcast posts. All content remains zero-knowledge end-to-end encrypted.'**
  String get onboardingSocialExplanation;

  /// No description provided for @onboardingSocialEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable WiltKey Social (Recommended)'**
  String get onboardingSocialEnable;

  /// No description provided for @onboardingSocialEnableDesc.
  ///
  /// In en, this message translates to:
  /// **'Share 24h Wilting Stories with mutual contacts, send custom pixel art, and participate in social broadcasts.'**
  String get onboardingSocialEnableDesc;

  /// No description provided for @onboardingSocialZeroServer.
  ///
  /// In en, this message translates to:
  /// **'Zero Server Data Mode (Absolute Privacy)'**
  String get onboardingSocialZeroServer;

  /// No description provided for @onboardingSocialZeroServerDesc.
  ///
  /// In en, this message translates to:
  /// **'Maximum anonymity. Strictly peer-to-peer and direct 1:1/group messaging without any server identity registration. Remote social features and stories are disabled.'**
  String get onboardingSocialZeroServerDesc;

  /// No description provided for @settingsSocialAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'WiltKey Social Account'**
  String get settingsSocialAccountTitle;

  /// No description provided for @settingsSocialAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow server-assisted 24h stories and discovery'**
  String get settingsSocialAccountSubtitle;

  /// No description provided for @settingsStoriesReelTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Stories Reel'**
  String get settingsStoriesReelTitle;

  /// No description provided for @settingsStoriesReelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show 24-hour stories on top of the chats tab'**
  String get settingsStoriesReelSubtitle;

  /// No description provided for @connectTabConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectTabConnect;

  /// No description provided for @connectTabSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get connectTabSocial;

  /// No description provided for @forcedUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get forcedUpdateTitle;

  /// No description provided for @forcedUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A mandatory update is required to continue using WiltKey safely.'**
  String get forcedUpdateSubtitle;

  /// No description provided for @forcedUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get forcedUpdateAction;

  /// No description provided for @forcedUpdateCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check Again'**
  String get forcedUpdateCheckAgain;

  /// No description provided for @forcedUpdateSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'This version includes critical protocol or security updates. Older versions can no longer communicate with the network.'**
  String get forcedUpdateSecurityNotice;

  /// No description provided for @forcedUpdateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s in this update'**
  String get forcedUpdateWhatsNew;

  /// No description provided for @settingsSwipeGesturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Swipe Gestures'**
  String get settingsSwipeGesturesTitle;

  /// No description provided for @settingsSwipeGesturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize swipe right and swipe left actions in the chats list'**
  String get settingsSwipeGesturesSubtitle;

  /// No description provided for @settingsSwipeRight.
  ///
  /// In en, this message translates to:
  /// **'Swipe Right'**
  String get settingsSwipeRight;

  /// No description provided for @settingsSwipeLeft.
  ///
  /// In en, this message translates to:
  /// **'Swipe Left'**
  String get settingsSwipeLeft;

  /// No description provided for @swipeActionMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark Read / Unread'**
  String get swipeActionMarkRead;

  /// No description provided for @swipeActionMute.
  ///
  /// In en, this message translates to:
  /// **'Mute / Unmute'**
  String get swipeActionMute;

  /// No description provided for @swipeActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin / Unpin'**
  String get swipeActionPin;

  /// No description provided for @swipeActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get swipeActionArchive;

  /// No description provided for @swipeActionNone.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get swipeActionNone;

  /// No description provided for @chatSwipeMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark Read'**
  String get chatSwipeMarkRead;

  /// No description provided for @chatSwipeMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark Unread'**
  String get chatSwipeMarkUnread;

  /// No description provided for @chatSwipePin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatSwipePin;

  /// No description provided for @chatSwipeUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatSwipeUnpin;

  /// No description provided for @chatSwipeMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatSwipeMute;

  /// No description provided for @chatSwipeUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatSwipeUnmute;

  /// No description provided for @chatSwipeArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get chatSwipeArchive;

  /// No description provided for @chatAttachVideoSubtitleEnabled.
  ///
  /// In en, this message translates to:
  /// **'Record up to 15s or pick from gallery'**
  String get chatAttachVideoSubtitleEnabled;

  /// No description provided for @chatVideoSelectSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Video'**
  String get chatVideoSelectSourceTitle;

  /// No description provided for @chatVideoQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get chatVideoQualityLabel;

  /// No description provided for @chatVideoQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get chatVideoQualityLow;

  /// No description provided for @chatVideoQualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get chatVideoQualityMedium;

  /// No description provided for @chatVideoQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get chatVideoQualityHigh;

  /// No description provided for @chatVideoCompressionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t compress this clip. Try a shorter or lower-quality selection.'**
  String get chatVideoCompressionFailed;

  /// No description provided for @chatVideoRecordCamera.
  ///
  /// In en, this message translates to:
  /// **'Record Video (Camera)'**
  String get chatVideoRecordCamera;

  /// No description provided for @chatVideoPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose Video from Gallery'**
  String get chatVideoPickGallery;

  /// No description provided for @chatVideoCompressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing video...'**
  String get chatVideoCompressing;

  /// No description provided for @chatVideoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Video exceeds size limit ({size})'**
  String chatVideoTooLarge(String size);

  /// No description provided for @chatVideoTooLong.
  ///
  /// In en, this message translates to:
  /// **'Video exceeds 15-second duration limit'**
  String get chatVideoTooLong;

  /// No description provided for @chatVideoSaveGallery.
  ///
  /// In en, this message translates to:
  /// **'Save Video to Gallery'**
  String get chatVideoSaveGallery;

  /// No description provided for @chatVideoSavedGallery.
  ///
  /// In en, this message translates to:
  /// **'Video saved to gallery'**
  String get chatVideoSavedGallery;

  /// No description provided for @chatVideoError.
  ///
  /// In en, this message translates to:
  /// **'Unable to play video clip'**
  String get chatVideoError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'fr',
    'hu',
    'pl',
    'sv',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'hu':
      return AppLocalizationsHu();
    case 'pl':
      return AppLocalizationsPl();
    case 'sv':
      return AppLocalizationsSv();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
