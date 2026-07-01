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
  /// **'Pair'**
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
  /// **'Checks for new messages about every 10 minutes. Easy on the battery.'**
  String get notificationModeLowPowerDesc;

  /// No description provided for @notificationModeInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get notificationModeInstant;

  /// No description provided for @notificationModeInstantDesc.
  ///
  /// In en, this message translates to:
  /// **'Keeps a secure link active in the background for instant alerts. Shows an ongoing notification and uses more battery.'**
  String get notificationModeInstantDesc;

  /// No description provided for @notificationNewMessageBody.
  ///
  /// In en, this message translates to:
  /// **'You got a message'**
  String get notificationNewMessageBody;

  /// No description provided for @notificationSecureLinkActive.
  ///
  /// In en, this message translates to:
  /// **'Secure link active'**
  String get notificationSecureLinkActive;

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
  /// **'Use your fingerprint to unlock instead of the PIN. The PIN is still required after 4 hours of inactivity.'**
  String get settingsBiometricDescription;

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
  /// **'Charge cost: ~{cost}'**
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
