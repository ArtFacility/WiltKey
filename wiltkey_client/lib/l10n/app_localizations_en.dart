// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navChats => 'Chats';

  @override
  String get navPair => 'Connect';

  @override
  String get navSettings => 'Settings';

  @override
  String get nukedTitle => 'Device Reset';

  @override
  String get nukedExplanation =>
      'All messages and keys have been deleted from this device. The secure database has been cleared.';

  @override
  String get nukedResetButton => 'Create New Identity';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonFinish => 'Finish';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'Wiltkey is a private messenger that doesn\'t save metadata, logs, or server history. Messages are encrypted locally and self-destruct if a screenshot is taken.';

  @override
  String get onboardingWelcomeNoHistory =>
      'No server history. No recovery keys.';

  @override
  String get onboardingIntelTitle => 'Security Info';

  @override
  String get onboardingLanguageDescription =>
      'Choose your preferred language to continue. You can change this at any time in Settings.';

  @override
  String get onboardingFactLanguageTitle => 'Language setup';

  @override
  String get onboardingFactLanguageBody =>
      'Select your preferred language to continue. You can change this at any time in Settings. Your preference is saved locally.';

  @override
  String get onboardingThemeTitle => 'Choose your theme';

  @override
  String get onboardingThemeDescription =>
      'Choose a theme below. You can change this later in Settings.';

  @override
  String get onboardingProfileTitle => 'Your Identity';

  @override
  String get onboardingProfileUsernameLabel => 'Username';

  @override
  String get onboardingProfileUsernameHint => 'Enter username';

  @override
  String get onboardingProfileCodenameLabel =>
      'Connection code (5 letters/numbers)';

  @override
  String get onboardingProfileCodenameExplanation =>
      'This code is shared during pairing to connect with nearby friends.';

  @override
  String get onboardingProfileUsernameError => 'Please set a username.';

  @override
  String get onboardingProfileCodenameError =>
      'Connection code must be exactly 5 characters.';

  @override
  String get onboardingAvatarTitle => 'Pixel Avatar';

  @override
  String get onboardingAvatarBrushColor => 'Brush color';

  @override
  String get onboardingAvatarRandom => 'Random';

  @override
  String get onboardingAvatarClear => 'Clear';

  @override
  String get onboardingPinTitle => 'Passcode PIN';

  @override
  String get onboardingPinExplanation =>
      'Set a PIN (4–6 digits) to protect your chats. You will need to enter this PIN every time you open the app. If you forget this PIN, your messages cannot be recovered.';

  @override
  String get onboardingPinEnter => 'Enter PIN';

  @override
  String get onboardingPinConfirm => 'Confirm PIN';

  @override
  String get onboardingPinLengthError => 'PIN must be between 4 and 6 digits.';

  @override
  String get onboardingPinMatchError => 'PINs do not match.';

  @override
  String onboardingSetupFailed(String error) {
    return 'Setup failed: $error';
  }

  @override
  String get onboardingFactMetadataTitle => 'THE METADATA PROBLEM';

  @override
  String get onboardingFactMetadataBody =>
      'Most chat apps encrypt message content but still track who you talk to, when, and how often. Wiltkey does not log any metadata, server-side data, or connections.';

  @override
  String get onboardingFactThemeTitle => 'CHOOSE YOUR THEME';

  @override
  String get onboardingFactThemeBody =>
      'Themes are cosmetic. The same security standards apply to every theme. You can switch themes at any time in Settings.';

  @override
  String get onboardingFactOtpTitle => 'PERFECT SECRECY';

  @override
  String get onboardingFactOtpBody =>
      'Wiltkey uses One-Time Pads (OTP) where keys match the message size, are completely random, and are never reused. This provides mathematical perfect secrecy, making messages impossible to decrypt without the keys.';

  @override
  String get onboardingFactLimitsTitle => 'CONNECTION LIMITS';

  @override
  String get onboardingFactLimitsBody =>
      'Chat capacity limits are designed to encourage meaningful, deliberate relationships. Restricting capacity ensures conversations are purposeful and grounded in real-world connections.';

  @override
  String get onboardingFactKdfTitle => 'SECURITY HASHING';

  @override
  String get onboardingFactKdfBody =>
      'A standard PIN can be brute-forced in milliseconds. Wiltkey processes your PIN through a hardening function, making brute-force attacks on the local database impossible.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTabProfile => 'Profile';

  @override
  String get settingsTabSecurity => 'Security';

  @override
  String get settingsSecuritySectionAccess => 'Access & unlock';

  @override
  String get settingsSecuritySectionDanger => 'Danger zone';

  @override
  String get settingsTabNetwork => 'Network';

  @override
  String get settingsTabAlerts => 'Notifications';

  @override
  String get settingsSavedIndicator => 'Saved';

  @override
  String get settingsProfileSectionAppearance => 'Appearance';

  @override
  String get settingsProfileSectionAvatar => 'Pixel Art Avatar';

  @override
  String get settingsProfileSectionProfile => 'Profile Settings';

  @override
  String get settingsProfileSectionOtherVisuals => 'Other Visuals';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsPixelArtEditor => 'Pixel Art Editor';

  @override
  String get settingsProfileBrushColor => 'Brush color';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Clear';

  @override
  String get settingsProfileChipRandom => 'Random';

  @override
  String get avatarEditButton => 'Edit avatar';

  @override
  String get groupCreateEditIcon => 'Edit icon';

  @override
  String get settingsProfileUsername => 'Username';

  @override
  String get settingsProfileBleNick => 'Short Nickname (5 chars)';

  @override
  String get settingsProfileKeyhash => 'Account ID';

  @override
  String get settingsProfileKeyhashCopied => 'Account ID copied to clipboard';

  @override
  String get settingsProfileChangePinButton => 'Change PIN';

  @override
  String get settingsProfileResetIdentityButton => 'Reset Account';

  @override
  String get settingsResetConfirmTitle => 'Reset identity?';

  @override
  String get settingsResetConfirmBody =>
      'This will permanently delete all messages, contacts, and generate a new identity. This action cannot be undone.';

  @override
  String get settingsResetConfirmCancel => 'Cancel';

  @override
  String get settingsResetConfirmReset => 'Reset';

  @override
  String get settingsChangePinTitle => 'Change PIN';

  @override
  String get changePinVerifyTitle => 'Verify current PIN';

  @override
  String get changePinVerifyPrompt => 'Enter your current PIN to continue.';

  @override
  String get changePinSetTitle => 'Set new PIN';

  @override
  String get settingsChangePinOldPin => 'Enter current PIN';

  @override
  String get settingsChangePinNewPin => 'Enter new PIN (4–6 digits)';

  @override
  String get settingsChangePinConfirmPin => 'Confirm new PIN';

  @override
  String get settingsChangePinEmptyFieldsError => 'Please fill out all fields.';

  @override
  String get settingsChangePinLengthError => 'New PIN must be 4 to 6 digits.';

  @override
  String get settingsChangePinMatchError => 'New PINs do not match.';

  @override
  String get settingsChangePinUpdatedSnackBar => 'PIN updated.';

  @override
  String get settingsChangePinIncorrectError => 'Current PIN is incorrect.';

  @override
  String get settingsNetworkRoutingTitle => 'Network Settings';

  @override
  String get settingsNetworkDevRelayToggle => 'Use local developer server';

  @override
  String get settingsNetworkDevRelayUrlLabel => 'Developer Server URL';

  @override
  String get settingsNetworkDevRelayDescription =>
      'Enabling this overrides the production server and routes messages through a local server.';

  @override
  String get settingsNetworkActiveGateway => 'Current Server URL';

  @override
  String get settingsNetworkDiagnostics => 'Diagnostics';

  @override
  String get settingsNetworkDebugButton => 'Open debug console';

  @override
  String get settingsDebugButtonsToggle => 'Debugger buttons';

  @override
  String get settingsDebugButtonsDescription =>
      'Show the terminal console button on the chats list and inside chats.';

  @override
  String get settingsDebugTitle => 'Debug console';

  @override
  String get settingsAlertsBackgroundNotifications =>
      'Background Notifications';

  @override
  String get settingsAlertsExplanation =>
      'Notifications will only show \'You have a message\'. Your messages remain encrypted until you unlock the app.';

  @override
  String get settingsTextSizeLabel => 'Chat text size';

  @override
  String get settingsTextSizePreview => 'This is how your messages will look.';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSystem => 'System Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageHungarian => 'Magyar (Hungarian)';

  @override
  String get settingsLanguagePolish => 'Polski (Polish)';

  @override
  String get settingsLanguageGerman => 'Deutsch (German)';

  @override
  String get settingsLanguageFrench => 'Français (French)';

  @override
  String get settingsLanguageSwedish => 'Svenska (Swedish)';

  @override
  String get settingsLanguageChinese => '中文 (Chinese)';

  @override
  String get notificationModeOff => 'Off';

  @override
  String get notificationModeOffDesc =>
      'No background checks. You only see messages when you open the app.';

  @override
  String get notificationModeLowPower => 'Low Power';

  @override
  String get notificationModeLowPowerDesc =>
      'Periodically checks for new messages in the background — quickly right after you close the app, then less often to save battery. No constant connection, so alerts can be delayed.';

  @override
  String get notificationModeInstant => 'Instant';

  @override
  String get notificationModeInstantDesc =>
      'Optional. Keeps an end-to-end-encrypted connection open in the background to sync your incoming messages in real time, shown by an ongoing notification. Wiltkey uses this instead of Google or Apple push services for privacy, so it works even without Google Play Services — at the cost of more battery.';

  @override
  String get notificationNewMessageBody => 'You got a message';

  @override
  String get notificationSecureLinkActive => 'Syncing secure messages';

  @override
  String get onboardingNotificationsTitle => 'Alerts';

  @override
  String get onboardingNotificationsExplanation =>
      'Wiltkey doesn\'t use Google or Apple push notifications — nothing about your messages ever touches their servers. Choose how you\'d like to be alerted. You can change this any time in Settings.';

  @override
  String get onboardingFactPushTitle => 'NO PUSH SERVERS';

  @override
  String get onboardingFactPushBody =>
      'Normal apps route your notifications through Google or Apple, revealing who messages you and when. Wiltkey never does — the default is no background checks at all, and any alerting runs entirely on your device.';

  @override
  String get notificationModeInstantDescFcm =>
      'Optional. Uses Google\'s push service as a lightweight wake-up so new messages arrive in real time. Only a content-free ping goes through Google — never your messages, which stay end-to-end encrypted on the relay until your device fetches them. Lighter on battery than a constant connection.';

  @override
  String get onboardingNotificationsExplanationFcm =>
      'For real-time alerts, this build uses Google\'s push service purely as a wake-up signal — a content-free ping, never your messages, which never touch Google\'s servers. Choose how you\'d like to be alerted; you can change this any time in Settings.';

  @override
  String get onboardingFactPushTitleFcm => 'CONTENT-FREE PUSH';

  @override
  String get onboardingFactPushBodyFcm =>
      'Normal apps route your notification content through Google, revealing what\'s sent and when. This build uses Google only as a content-free wake-up ping — no message data, no readable metadata — and everything stays encrypted end to end.';

  @override
  String get chatsLockedSubtitle => 'Locked · pair in person to unlock';

  @override
  String chatsMemberCount(int count) {
    return '$count members';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: 'contacts',
      one: 'contact',
    );
    return '$totalCount $_temp0 · $lockedCount locked';
  }

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsPopupPair => 'Pair a device';

  @override
  String get chatsPopupCreateGroup => 'Create group';

  @override
  String get chatsPopupJoinGroup => 'Join group';

  @override
  String get chatsSearchHint => 'Search';

  @override
  String get chatsEmptyNoMatches => 'No matches';

  @override
  String get chatsEmptyNoChats => 'No chats yet';

  @override
  String get chatsEmptyPairInstruction =>
      'Pair a device in person to start chatting.';

  @override
  String get chatsEmptyPairButton => 'Pair a device';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return 'ME $remaining · PEER $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded =>
      'Too many incorrect attempts. Device wiped.';

  @override
  String pinAccessDenied(int attempts) {
    return 'Incorrect PIN. $attempts attempts remaining.';
  }

  @override
  String get pinMinLengthError => 'PIN must be at least 4 digits.';

  @override
  String get pinPurgeConfirmTitle => 'Reset device?';

  @override
  String get pinPurgeConfirmBody =>
      'Forget your PIN? This will permanently delete all messages and reset your account. This action cannot be undone.';

  @override
  String get pinPurgeConfirmButton => 'Reset Device';

  @override
  String get pinLockedTitle => 'Locked';

  @override
  String get pinLockedSubtitle => 'Enter PIN to unlock';

  @override
  String get pinUnlockButton => 'Unlock';

  @override
  String get pinUseFingerprintButton => 'Use fingerprint';

  @override
  String get settingsBiometricToggle => 'Fingerprint unlock';

  @override
  String get settingsBiometricDescription =>
      'Use your fingerprint to unlock instead of the PIN. Your PIN is still required after the fallback period below.';

  @override
  String get settingsBiometricIdleTitle => 'PIN fallback';

  @override
  String get settingsBiometricIdleDescription =>
      'Require your PIN again after this long without unlocking.';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours h';
  }

  @override
  String get settingsBiometricIdleNever => 'Never';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Couldn\'t enable fingerprint unlock.';

  @override
  String get pinForgotButton => 'Forgot PIN? Reset Device';

  @override
  String get pairTitle => 'Pair Devices';

  @override
  String get pairRescanTooltip => 'Refresh scan';

  @override
  String get pairBluetoothOffWarning =>
      'Bluetooth is off. Pairing needs Bluetooth to find nearby devices — turn it on to continue.';

  @override
  String get pairBluetoothTurnOnButton => 'Turn on Bluetooth';

  @override
  String get pairDoNotExitWarning =>
      'Keep WiltKey open — don\'t switch apps or exit until pairing has finished on BOTH devices.';

  @override
  String get pairRequestDialogTitle => 'Pairing Request';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName wants to pair.\n\nChat size: $size.\n\nAccept secure pairing?';
  }

  @override
  String get pairRequestReject => 'Reject';

  @override
  String get pairRequestAccept => 'Accept';

  @override
  String get pairPingStatusPinging => 'Testing...';

  @override
  String pairPingStatusLatency(String latency) {
    return 'Latency: ${latency}ms';
  }

  @override
  String get pairPingStatusFailed => 'Failed';

  @override
  String get pairPingStatusTest => 'Test Connection';

  @override
  String get pairDeviceNameLabel => 'Your Device Name';

  @override
  String get pairDeviceNameHint => 'Enter name';

  @override
  String get pairDiscoverableTitle => 'Make device discoverable';

  @override
  String get pairDiscoverableSubtitle => 'Allow nearby friends to find you';

  @override
  String get pairNearbyDevicesTitle => 'Nearby Devices';

  @override
  String get pairNearbyDevicesInstruction =>
      'Hold devices next to each other to connect.';

  @override
  String get pairDirectSyncFormRelayLabel => 'Server URL';

  @override
  String get pairDirectSyncFormSyncButton => 'Connect Devices';

  @override
  String get pairSyncingConnecting => 'Connecting...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return 'Generating secure key ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return 'Key: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get pairSuccessConnectionSecured => 'Successfully Connected';

  @override
  String pairSuccessGroupBody(String groupName) {
    return 'Joined group \"$groupName\". Secure keys generated locally on your device.';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return 'Secure keys exchanged and generated on your device. Connected to $title with a $label chat capacity.';
  }

  @override
  String get pairSuccessReturnButton => 'Go to Chats';

  @override
  String get chatDetailsTitle => 'Chat details';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return 'Nick: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => 'Official relay';

  @override
  String get chatDetailsPrivateNode => 'Private node';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return 'ME $remaining · PEER $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => 'Profile';

  @override
  String get chatDetailsProfileExplanation =>
      'Avatars and nicknames sync automatically when you connect. You can manually sync yours now if needed.';

  @override
  String get chatDetailsProfileSyncButton => 'Sync Profile';

  @override
  String get chatDetailsProfileSnackBar => 'Profile sent.';

  @override
  String get chatDetailsSectionPermissions => 'Permissions';

  @override
  String get chatDetailsPermissionsPhotos => 'Allow sharing photos';

  @override
  String get chatDetailsPermissionsEmojis => 'Custom emojis';

  @override
  String get chatDetailsPermissionsEmojisAvailable => 'Available';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize => 'Requires larger chat';

  @override
  String get chatDetailsSectionMetadata => 'Metadata Space';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return 'This chat allocates $budget of the $max space for settings, profile pictures, and custom emojis.';
  }

  @override
  String get chatDetailsSectionLanes => 'Secure Lanes';

  @override
  String get chatDetailsLanesMySend => 'My send capacity';

  @override
  String get chatDetailsLanesPeerSend => 'Peer send capacity';

  @override
  String get chatDetailsLanesBorrowed => 'Borrowed space';

  @override
  String get chatDetailsLanesCapacityLeft => 'My remaining capacity';

  @override
  String get chatDetailsLanesExplanation =>
      'If you run low on chat capacity, you can borrow unused space from your peer. This can also happen automatically so you can keep chatting.';

  @override
  String get chatDetailsLanesBorrowButton => 'Request chat space';

  @override
  String get chatDetailsLanesSnackBar => 'Request sent to peer.';

  @override
  String get chatDetailsSectionEmojis => 'Custom emojis';

  @override
  String get chatDetailsEmojisExplanation =>
      'Use these custom emojis in your messages with the :name: format.';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      'This chat capacity is too small for custom emojis. Connect with more capacity to enable them.';

  @override
  String get chatDetailsEmojisCreate => 'Create';

  @override
  String get chatDetailsSectionDestructive => 'Dangerous Settings';

  @override
  String get chatDetailsNukeButton => 'Nuke Chat (Both Sides)';

  @override
  String get chatDetailsDeleteEmojiTitle => 'Delete emoji?';

  @override
  String get chatDetailsDeleteEmojiBody =>
      'This custom emoji will be permanently deleted. Do you want to proceed?';

  @override
  String get chatDetailsDeleteEmojiDelete => 'Delete';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return 'Added :$name:';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return 'Image too large ($cost) for remaining space ($charge).';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar => 'Image too large to send.';

  @override
  String get chatImageNeedsPlusSnackBar =>
      'Image too large for the free tier — WiltKey Plus raises the limit to 50 MB.';

  @override
  String get chatTapForDetails => 'Tap for details';

  @override
  String get chatSyncTooltip => 'Sync messages';

  @override
  String get chatStickerHint => 'Hold an emoji to send a sticker';

  @override
  String get chatSyncStarted => 'Checking for missed messages…';

  @override
  String get chatSyncOffline => 'Can\'t sync while offline.';

  @override
  String get chatEncrypting => 'Encrypting…';

  @override
  String get chatScreenshotDetected => 'Screenshot Detected';

  @override
  String get chatScreenshotExplanation =>
      'A screenshot was detected. For your security, you can wipe your keys and messages now.';

  @override
  String get chatScreenshotWipeButton => 'Wipe messages and keys';

  @override
  String get chatScreenshotIgnoreButton => 'Ignore warning';

  @override
  String get chatSimulateScreenshotButton => 'Simulate screenshot';

  @override
  String chatCostIndicator(String cost) {
    return 'Cost: $cost';
  }

  @override
  String get groupCreateTitle => 'Create Group';

  @override
  String get groupCreatePixelArtIcon => 'Group Icon';

  @override
  String get groupCreateRandomIcon => 'Generate';

  @override
  String get groupCreateClearIcon => 'Clear';

  @override
  String get groupCreateNameLabel => 'Group name';

  @override
  String get groupCreateNameEmptyValidator => 'Enter a group name';

  @override
  String get groupCreateNameLengthValidator => 'Maximum 24 characters';

  @override
  String get groupCreatePoliciesSection => 'Group Policy Settings';

  @override
  String get groupCreatePolicyPadSize => 'Group Chat Size';

  @override
  String get groupCreatePolicyLaneSize => 'Capacity per member';

  @override
  String get groupCreatePolicyMaxMembersLabel => 'Max member capacity';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return '$count members max';
  }

  @override
  String get groupCreatePolicyAllowImages => 'Allow sharing photos';

  @override
  String get groupCreatePolicyAllowImagesSub => 'Allow members to send photos';

  @override
  String get groupCreatePolicyPayloadSize => 'Max message size';

  @override
  String get groupCreateButton => 'Create Group';

  @override
  String get groupCreateProgressTitle => 'Creating group…';

  @override
  String get groupCreateProgressSubtitle =>
      'Preparing your group\'s encryption pad and member capacity. This can take a moment — hang tight.';

  @override
  String groupCreateFailedSnackBar(String error) {
    return 'Failed to create group: $error';
  }

  @override
  String get pairSyncingAwaitingApproval => 'Waiting for friend to accept...';

  @override
  String get pairSyncingCoordinating => 'Setting up key exchange...';

  @override
  String get pairSyncingStep1 => 'Establishing secure link...';

  @override
  String get pairSyncingStep2 => 'Generating security seed...';

  @override
  String pairSyncingStep3(String seed) {
    return 'Exchanging public keys... $seed';
  }

  @override
  String get pairSyncingStep4 => 'Generating secure chat keys...';

  @override
  String get pairSyncingStep5 => 'Verifying key integrity...';

  @override
  String get pairSyncingStep6 => 'Secure setup completed successfully.';

  @override
  String chatRemainingLabel(String bytes) {
    return '$bytes remaining';
  }

  @override
  String get chatLockedLabel => 'Locked · pair in person to continue';

  @override
  String get chatMessageHint => 'Message';

  @override
  String get chatVoiceComingSoon => 'Voice messages are coming soon.';

  @override
  String get chatVoiceHoldHint => 'Hold to record a voice message.';

  @override
  String get chatVoiceReleaseCancel => 'Release to cancel';

  @override
  String get chatVoicePermissionDenied =>
      'Microphone permission is needed to record voice messages.';

  @override
  String get chatVoiceQualityLofi => 'Lo-fi';

  @override
  String get chatVoiceQualityVoice => 'Voice';

  @override
  String get chatVoiceQualityClear => 'Clear';

  @override
  String get chatVoiceUnavailable => 'Voice note unavailable';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return 'Voice note too large ($cost) for remaining space ($charge).';
  }

  @override
  String get chatDetailsDeleteConfirmTitle => 'Delete chat?';

  @override
  String get chatDetailsDeleteConfirmBody =>
      'This will permanently delete all messages and encryption keys for this contact. This cannot be undone.';

  @override
  String get chatDetailsDeleteConfirmButton => 'Delete Chat';

  @override
  String get chatsActionArchive => 'Archive';

  @override
  String get chatsActionNuke => 'Nuke chat';

  @override
  String get chatsActionDelete => 'Delete';

  @override
  String get chatsArchivedBadge => 'Archived';

  @override
  String get chatsArchivedSubtitle => 'Archived · read-only';

  @override
  String get chatsArchiveConfirmTitle => 'Archive chat?';

  @override
  String get chatsArchiveConfirmBody =>
      'This frees up space by deleting this chat\'s one-time pad. Your messages stay readable, but the chat becomes read-only — you can\'t send or receive in it again.';

  @override
  String get chatsArchiveConfirmButton => 'Archive';

  @override
  String get chatsActionPin => 'Pin';

  @override
  String get chatsActionUnpin => 'Unpin';

  @override
  String get chatsFilterAll => 'All';

  @override
  String get chatsFilterDirect => 'Direct';

  @override
  String get chatsFilterGroups => 'Groups';

  @override
  String get chatsSectionArchived => 'Archived';

  @override
  String groupTapForDetails(String hostName) {
    return 'Tap for details · Host: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'slots',
      one: 'slot',
    );
    return '$count empty lane $_temp0 available';
  }

  @override
  String get groupHost => 'Host';

  @override
  String get groupMember => 'Member';

  @override
  String get groupDepleted => 'Depleted';

  @override
  String get groupNotYetMet => 'Not yet met';

  @override
  String get groupRechargeButton => 'Recharge group';

  @override
  String get groupRechargeTitle => 'Recharge group?';

  @override
  String get groupRechargeBody =>
      'Starts a fresh secure enclave with a new key. Everyone keeps their message history, but each member must meet you again in person to rejoin. Members you don\'t re-add keep their history but lose access.';

  @override
  String get groupRechargeConfirm => 'Recharge';

  @override
  String get groupRechargeDone =>
      'Group recharged — meet members again to re-add them.';

  @override
  String get groupRechargeNeededComposer =>
      'Host recharged this group — meet them again to rejoin';

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityEmpty =>
      'No activity yet. Events like a chat being destroyed will show up here.';

  @override
  String get activityClear => 'Clear';

  @override
  String get activityClearConfirmTitle => 'Clear activity?';

  @override
  String get activityClearConfirmBody =>
      'This removes all activity entries from this device. It can\'t be undone.';

  @override
  String get eventNukeReceivedTitle => 'Chat destroyed';

  @override
  String get eventNukeReceivedBody => 'A secure chat was destroyed.';

  @override
  String get eventGroupNukedTitle => 'Group destroyed';

  @override
  String get eventGroupNukedBody => 'A secure group was destroyed.';

  @override
  String groupSyncingFromMember(String name) {
    return 'Syncing details and messages from $name...';
  }

  @override
  String get groupInviteMember => 'Invite member';

  @override
  String get groupLeaveGroup => 'Leave group';

  @override
  String get groupRemoveMember => 'Remove member';

  @override
  String get groupRemoveMemberTitle => 'Remove member?';

  @override
  String groupRemoveMemberBody(String name) {
    return 'Remove $name from the group? This drains their pairwise key.';
  }

  @override
  String get groupLeaveGroupTitle => 'Leave group?';

  @override
  String get groupLeaveGroupBody =>
      'Leave this group? Wipes local pairwise keys and logs.';

  @override
  String get groupSyncStepText => 'Sync';

  @override
  String get groupDecryptingImage => 'Decrypting image...';

  @override
  String get chatFileTapToDownload => 'Tap to download';

  @override
  String get chatFileDownloadFailed => 'Tap to retry';

  @override
  String get chatFileKindPhoto => 'Photo';

  @override
  String get chatFileKindVoice => 'Voice message';

  @override
  String get chatFileKindFile => 'File';

  @override
  String get groupTapToRevealImage => 'Tap to reveal image';

  @override
  String groupImageSize(String size) {
    return 'Size: $size';
  }

  @override
  String get groupImageFailedToLoad => 'Image failed to load';

  @override
  String get groupScreenshotWipeButton => 'Wipe all keys now';

  @override
  String get groupRefillGranted => 'Lane refill granted successfully.';

  @override
  String groupRefillFailed(String error) {
    return 'Failed to grant refill: $error';
  }

  @override
  String get groupLaneDepleted => 'Lane depleted';

  @override
  String get groupLaneDepletedExplanation =>
      'Request byte refill from the group host.';

  @override
  String get groupRefillRequestSent => 'Refill request transmitted to host.';

  @override
  String get groupRequestRefill => 'Request refill';

  @override
  String groupExceedsSizeLimit(int size) {
    return 'Exceeds size limit ($size B)';
  }

  @override
  String get groupDetailsTitle => 'Group details';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return 'Shared pad · Host: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => 'Group Policies';

  @override
  String get groupDetailsSavePoliciesButton => 'Save Policies';

  @override
  String get groupDetailsSavePoliciesSnackBar => 'Group policies saved.';

  @override
  String get groupDetailsSectionEmojis => 'Custom Emojis';

  @override
  String get groupDetailsSectionMetadata => 'Metadata Space';

  @override
  String get groupDetailsMetadataExplanation =>
      'Slot 0 of the shared pad reserves 1 MB for group metadata — the group icon, member roster, and custom emojis live here.';

  @override
  String get groupDetailsSectionSync => 'Group Sync';

  @override
  String get groupDetailsSyncExplanation =>
      'Request the latest group details, policies, and member lists from the host.';

  @override
  String get groupDetailsSyncButton => 'Sync Details';

  @override
  String get groupDetailsSyncSnackBar => 'Requested group update from host.';

  @override
  String get groupDetailsSectionDestructive => 'Dangerous Settings';

  @override
  String get groupDetailsLeaveButton => 'Leave Group';

  @override
  String get groupDetailsNukeButton => 'Delete Group';

  @override
  String get groupDetailsDeleteConfirmTitle => 'Delete group?';

  @override
  String get groupDetailsDeleteConfirmBody =>
      'This will permanently delete this group and wipe all chat history and keys for all members. This cannot be undone.';

  @override
  String get groupDetailsDeleteConfirmButton => 'Delete Group';

  @override
  String get chatImageCompressionTitle => 'Compress image';

  @override
  String chatImageCompressionOriginal(String size) {
    return 'Original: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return 'Estimated: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return 'Estimated: $size (saving ~$saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return 'Payload sent: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation =>
      'Converted to WebP, max 2000px.';

  @override
  String get chatImageCompressionLowSize => 'Low size';

  @override
  String get chatImageCompressionHighSize => 'High';

  @override
  String get chatImageCompressionMaxQuality => 'Max quality';

  @override
  String get chatImageCompressionUncompressed => 'Uncompressed';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return '$percent% quality';
  }

  @override
  String get chatImageCompressionSendHidden => 'Send hidden (tap to reveal)';

  @override
  String get chatImageCompressionSendButton => 'Send';

  @override
  String get groupGrantRefill => 'Grant refill';

  @override
  String get groupLaneLocked => 'Locked · out of bytes';

  @override
  String get groupMembersTitle => 'Group Members';

  @override
  String get groupMembersExplanation =>
      'All members share one chat size split into lanes. Messages are sent through the server.';

  @override
  String get pairChatSize => 'Chat Size';

  @override
  String get chatSystemConnected => 'Connected. Chat session secure.';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return 'Joined group \"$groupName\". Connections secure.';
  }

  @override
  String get themeCyberpunkName => 'Neon Grid';

  @override
  String get themeCyberpunkDesc =>
      'The original. Obsidian, glowing cyan, terminal type.';

  @override
  String get themeGardenName => 'Dusk Garden';

  @override
  String get themeGardenDesc =>
      'Soft soil tones, warm linen, petals for your budget.';

  @override
  String get themePaperinkName => 'Paper & Ink';

  @override
  String get themePaperinkDesc =>
      'Warm washi paper, sumi ink dilutions, vermilion hanko seal.';

  @override
  String get themePickerPlayExclusive =>
      'This theme is exclusive to the Play Store version of WiltKey.';

  @override
  String get themePreviewTooltip => 'Preview';

  @override
  String get themePreviewSectionDashboard => 'Chat list';

  @override
  String get themePreviewSectionChat => 'Conversation';

  @override
  String get themePreviewSectionEffects => 'Special effects';

  @override
  String get themePreviewPlayUnlock => 'Play unlock animation';

  @override
  String get themePreviewPlayNuke => 'Play self-destruct animation';

  @override
  String get themePreviewApply => 'Use this theme';

  @override
  String get themePreviewGetInShop => 'Get it in the shop';

  @override
  String get themePreviewMsgThem1 =>
      'Only 800 bytes left on our pad, wanna meet up?';

  @override
  String get themePreviewMsgMe =>
      'Sure! Movie night at mine? We can recharge too';

  @override
  String get themePreviewMsgThem2 => 'deal, bringing snacks 🍿';

  @override
  String get themePreviewRowPhoto => 'Photo from the bouldering gym 🧗';

  @override
  String get themePreviewRowLost => 'Out of pad — meet up to recharge';

  @override
  String get accessibilityWarningTitle => 'Accessibility service active';

  @override
  String accessibilityWarningBody(String names) {
    return 'An accessibility service that can read on-screen content is active: $names. This is normal for tools like screen readers or password managers. If you didn\'t turn one on, review your accessibility settings.';
  }

  @override
  String get accessibilityWarningDismiss => 'Dismiss';

  @override
  String get accessibilityWarningOpenSettings => 'Review settings';

  @override
  String get chatImageCompressionAllowDownload => 'Allow saving to gallery';

  @override
  String get chatImageCompressionWilting =>
      'Wilting image (disappears after opening)';

  @override
  String get chatImageDownload => 'Download';

  @override
  String get chatImageSaveAs => 'Save as';

  @override
  String get chatImageSavedToGallery => 'Saved to gallery';

  @override
  String get chatImageSaveFailed => 'Couldn\'t save the image';

  @override
  String get chatImageSourceTitle => 'Send a photo';

  @override
  String get chatImageSourceCamera => 'Take photo';

  @override
  String get chatImageSourceGallery => 'Choose from gallery';

  @override
  String get screenshotRequestTooltip => 'Request screenshot';

  @override
  String get screenshotWaiting => 'Waiting for approval…';

  @override
  String get screenshotConsentTitle => 'Screenshot request';

  @override
  String screenshotConsentBody(String name) {
    return '$name wants to save a screenshot of this chat. Allow it?';
  }

  @override
  String get screenshotDenied => 'Screenshot request was declined.';

  @override
  String get screenshotCaptureFailed => 'Couldn\'t capture the screenshot.';

  @override
  String get screenshotWatermark => 'WiltKey — Screenshot with consent';

  @override
  String screenshotRequestInline(String name) {
    return '$name requested a screenshot';
  }

  @override
  String get screenshotRequestAllowed => 'You allowed the screenshot';

  @override
  String get screenshotRequestDeclined => 'You declined the screenshot';

  @override
  String get screenshotRequestExpired => 'Screenshot request expired';

  @override
  String get wiltingTapToReveal => 'Tap to see wilting message';

  @override
  String get wiltingMessageTag => 'Wilting message';

  @override
  String get wiltedMessage => 'Wilted message';

  @override
  String get wiltingSheetTitle => 'Wilting message';

  @override
  String get wiltingSheetBody =>
      'The message disappears this many seconds after the recipient opens it.';

  @override
  String get wiltingSheetSend => 'Send wilting message';

  @override
  String get wiltingHoldToSendHint => 'Hold to send a wilting message';

  @override
  String get replyYou => 'You';

  @override
  String get replySomeone => 'Someone';

  @override
  String get replyPreviewImage => '📷 Photo';

  @override
  String get replyPreviewVoice => '🎤 Voice message';

  @override
  String get replyPreviewMessage => 'Message';

  @override
  String get replyUnavailable => 'Original message unavailable';

  @override
  String get shopEntryTitle => 'Shop & WiltKey Plus';

  @override
  String get shopEntrySubtitle => 'Themes, unlocks & Plus';

  @override
  String get supportEntryTitle => 'Support the project';

  @override
  String get supportEntrySubtitle => 'Help keep WiltKey running';

  @override
  String get shopTitle => 'Shop';

  @override
  String get supportTitle => 'Support WiltKey';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => 'Unlocks';

  @override
  String get shopPlusTagline =>
      'Longer offline message hold and bigger file transfers.';

  @override
  String get shopEmptyTitle => 'Nothing here yet';

  @override
  String get shopEmptyBody => 'Products are on the way — check back soon.';

  @override
  String get shopRestoreButton => 'Restore purchases';

  @override
  String get shopRestoredSnack => 'Purchases restored';

  @override
  String get shopBuyButton => 'Buy';

  @override
  String get shopOwnedLabel => 'Owned';

  @override
  String get shopActiveLabel => 'Active';

  @override
  String get shopManageNote => 'Manage in Google Play';

  @override
  String get shopPurchasePendingSnack => 'Purchase pending…';

  @override
  String get shopPurchaseFailedSnack => 'Purchase couldn\'t be completed';

  @override
  String get supportIntro =>
      'WiltKey is free and open source, and this build unlocks every cosmetic for free. If you\'d like to support development and the official relay, visit the page below.';

  @override
  String get supportOpenButton => 'Open support page';

  @override
  String get supportFreeNote => 'All cosmetics are unlocked in this build.';

  @override
  String get shopTabPalettes => 'Palettes';

  @override
  String get shopTabThemes => 'Themes';

  @override
  String get shopTabBorders => 'Borders';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'Promo';

  @override
  String get shopPalettesIntro =>
      'Extra colours for drawing your avatar and group icons. Art you receive always renders in full — a pack only unlocks drawing with those colours yourself.';

  @override
  String shopPaletteColorCount(int count) {
    return '$count extra colours';
  }

  @override
  String get shopThemesEmptyTitle => 'No themes yet';

  @override
  String get shopThemesEmptyBody =>
      'Premium themes are on the way — the three built-in themes are free forever.';

  @override
  String get shopBordersSoonTitle => 'Borders are coming';

  @override
  String get shopBordersSoonBody =>
      'Decorative frames for your avatar that everyone you chat with can see. In the works.';

  @override
  String get shopPlusBenefitsSection => 'What you get';

  @override
  String get shopPlusBenefitHold =>
      'Your messages wait 72 hours on the relay instead of 24 while you\'re offline.';

  @override
  String get shopPlusBenefitFiles =>
      'Send large files — up to 50 MB per message, past the 5 MB free limit.';

  @override
  String get shopPlusBenefitPads =>
      'Create bigger pads — up to 200 MB for a chat and 500 MB for a group.';

  @override
  String get shopPlusBenefitSupport =>
      'You keep the relay running and WiltKey independent.';

  @override
  String get shopSubscribeButton => 'Subscribe';

  @override
  String get shopPriceUnavailable => 'Unavailable';

  @override
  String get shopPromoIntro =>
      'Got a promo code? Enter it below and Google Play will apply it to your account.';

  @override
  String get shopPromoHint => 'PROMO CODE';

  @override
  String get shopPromoRedeemButton => 'Redeem in Google Play';

  @override
  String get shopPromoNote =>
      'Codes are redeemed in the Play Store. Once applied, your unlock appears here automatically.';

  @override
  String pairLargerPadsUpsell(String max) {
    return 'Larger pads with Plus — up to $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return 'Not enough free space — this chat needs $needed and you have $free.';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return 'Generating keystream… $written / $total';
  }

  @override
  String get pairKeepAppOpen =>
      'Keep the app open — the secure pad is still being created.';

  @override
  String groupLargerPadsUpsell(String max) {
    return 'Larger group pads with Plus — up to $max';
  }

  @override
  String get settingsBorderSection => 'Avatar border';

  @override
  String get shopBordersIntro =>
      'Frames and accessories for your avatar. Everyone you chat with sees your border — a locked one only stops you equipping it, never how it renders.';

  @override
  String get shopBorderSubtitle => 'Avatar border';

  @override
  String get shopFreeLabel => 'Free';

  @override
  String get notificationModePrivate => 'Private';

  @override
  String get notificationModePrivateDesc =>
      'Periodically checks for new messages in the background without using Google push services. Alerts may be delayed, but no signals pass through a 3rd-party service.';

  @override
  String get connectSectionOneOnOne => 'One-on-one';

  @override
  String get connectSectionGroups => 'Groups';

  @override
  String get connectByteBudgetTitle => 'Byte budget';

  @override
  String get connectByteBudgetDesc =>
      'Unlimited time, limited budget. Best for long-distance friends and family, and high-security chats.';

  @override
  String get connectTimeWiltTitle => 'Time Wilt';

  @override
  String get connectTimeWiltDesc =>
      'Limited time, unlimited budget. Best for getting to know new people, blind dates, or friends you need an excuse to see.';

  @override
  String get connectRemotePairTitle => 'Remote pair (testing)';

  @override
  String get connectRemotePairDesc =>
      'Debug-only: pair with a tester over the relay using a PIN + identity hash.';

  @override
  String get connectByteBudgetGroupTitle => 'Byte budget group';

  @override
  String get connectByteBudgetGroupDesc =>
      'Unlimited time, limited budget. A group you build by inviting members in person.';

  @override
  String get connectTimeWiltGroupTitle => 'Time Wilt group';

  @override
  String get connectTimeWiltGroupDesc =>
      'Limited time, unlimited budget. A casual group whose messages expire as you go.';

  @override
  String get connectJoinGroupTitle => 'Join a group';

  @override
  String get connectJoinGroupDesc =>
      'Someone nearby invited you — find their group beacon.';

  @override
  String get connectJoinRemoteGroupTitle => 'Join remote group (testing)';

  @override
  String get connectJoinRemoteGroupDesc =>
      'Debug-only: join a tester\'s group over the relay.';

  @override
  String get connectBadgeSoon => 'SOON';

  @override
  String get timeWiltLifetimeLabel => 'Chat lifetime';

  @override
  String get timeWiltPlusHint => 'Unlock up to 6 months with Plus';

  @override
  String get timeWiltExplanation =>
      'The chat becomes read-only when the timer runs out.';

  @override
  String timeWiltPairRequestDialogBody(String peerName, String lifetime) {
    return 'Accept a Time Wilt chat from $peerName? It becomes read-only in $lifetime.';
  }

  @override
  String timeWiltLifetimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeMinutes(int count) {
    return '$count min';
  }

  @override
  String timeWiltLifetimeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get timeWiltLifetimeMoments => 'moments';
}
