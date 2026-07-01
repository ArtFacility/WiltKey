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
  String get navPair => 'Pair';

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
      'Checks for new messages about every 10 minutes. Easy on the battery.';

  @override
  String get notificationModeInstant => 'Instant';

  @override
  String get notificationModeInstantDesc =>
      'Keeps a secure link active in the background for instant alerts. Shows an ongoing notification and uses more battery.';

  @override
  String get notificationNewMessageBody => 'You got a message';

  @override
  String get notificationSecureLinkActive => 'Secure link active';

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
      'Use your fingerprint to unlock instead of the PIN. The PIN is still required after 4 hours of inactivity.';

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
    return 'Charge cost: ~$cost';
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
}
