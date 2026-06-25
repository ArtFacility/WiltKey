// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navChats => 'Chats';

  @override
  String get navPair => 'Koppeln';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get nukedTitle => 'Gerät zurückgesetzt';

  @override
  String get nukedExplanation =>
      'Alle Nachrichten und Schlüssel wurden von diesem Gerät gelöscht. Die sichere Datenbank wurde geleert.';

  @override
  String get nukedResetButton => 'Neue Identität erstellen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonFinish => 'Fertigstellen';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'Wiltkey ist ein privater Messenger, der keine Metadaten, Protokolle oder den Serververlauf speichert. Nachrichten werden lokal verschlüsselt und zerstören sich selbst, wenn ein Screenshot gemacht wird.';

  @override
  String get onboardingWelcomeNoHistory =>
      'Kein Serververlauf. Keine Wiederherstellungsschlüssel.';

  @override
  String get onboardingIntelTitle => 'Sicherheits-Info';

  @override
  String get onboardingLanguageDescription =>
      'Wähle deine bevorzugte Sprache, um fortzufahren. Du kannst sie jederzeit in den Einstellungen ändern.';

  @override
  String get onboardingFactLanguageTitle => 'Spracheinstellung';

  @override
  String get onboardingFactLanguageBody =>
      'Wähle deine bevorzugte Sprache, um fortzufahren. Du kannst sie jederzeit in den Einstellungen ändern. Deine Auswahl wird lokal gespeichert.';

  @override
  String get onboardingThemeTitle => 'Wähle dein Design';

  @override
  String get onboardingThemeDescription =>
      'Wähle unten ein Design aus. Du kannst dies später in den Einstellungen ändern.';

  @override
  String get onboardingProfileTitle => 'Deine Identität';

  @override
  String get onboardingProfileUsernameLabel => 'Benutzername';

  @override
  String get onboardingProfileUsernameHint => 'Benutzername eingeben';

  @override
  String get onboardingProfileCodenameLabel =>
      'Verbindungscode (5 Buchstaben/Zahlen)';

  @override
  String get onboardingProfileCodenameExplanation =>
      'Dieser Code wird beim Koppeln geteilt, um sich mit Freunden in der Nähe zu verbinden.';

  @override
  String get onboardingProfileUsernameError =>
      'Bitte richte einen Benutzernamen ein.';

  @override
  String get onboardingProfileCodenameError =>
      'Der Verbindungscode muss genau 5 Zeichen lang sein.';

  @override
  String get onboardingAvatarTitle => 'Pixel-Avatar';

  @override
  String get onboardingAvatarBrushColor => 'Pinselfarbe';

  @override
  String get onboardingAvatarRandom => 'Zufällig';

  @override
  String get onboardingAvatarClear => 'Löschen';

  @override
  String get onboardingPinTitle => 'Passcode-PIN';

  @override
  String get onboardingPinExplanation =>
      'Richte eine PIN (4–6 Ziffern) ein, um deine Chats zu schützen. Du musst diese PIN jedes Mal eingeben, wenn du die App öffnest. Wenn du diese PIN vergisst, können deine Nachrichten nicht wiederhergestellt werden.';

  @override
  String get onboardingPinEnter => 'PIN eingeben';

  @override
  String get onboardingPinConfirm => 'PIN bestätigen';

  @override
  String get onboardingPinLengthError =>
      'Die PIN muss zwischen 4 und 6 Ziffern lang sein.';

  @override
  String get onboardingPinMatchError => 'Die PINs stimmen nicht überein.';

  @override
  String onboardingSetupFailed(String error) {
    return 'Einrichtung fehlgeschlagen: $error';
  }

  @override
  String get onboardingFactMetadataTitle => 'DAS METADATEN-PROBLEM';

  @override
  String get onboardingFactMetadataBody =>
      'Die meisten Chat-Apps verschlüsseln Nachrichteninhalte, verfolgen aber immer noch, mit wem du wann und wie oft kommunizierst. Wiltkey protokolliert keine Metadaten, serverbasierten Daten oder Verbindungen.';

  @override
  String get onboardingFactThemeTitle => 'WÄHLE DEIN DESIGN';

  @override
  String get onboardingFactThemeBody =>
      'Designs sind kosmetisch. Für jedes Design gelten die gleichen Sicherheitsstandards. Du kannst das Design jederzeit in den Einstellungen wechseln.';

  @override
  String get onboardingFactOtpTitle => 'PERFEKTE GEHEIMHALTUNG';

  @override
  String get onboardingFactOtpBody =>
      'Wiltkey verwendet One-Time-Pads (OTP), bei denen die Schlüssel der Nachrichtengröße entsprechen, völlig zufällig sind und nie wiederverwendet werden. Dies bietet mathematisch perfekte Sicherheit und macht es unmöglich, Nachrichten ohne die Schlüssel zu entschlüsseln.';

  @override
  String get onboardingFactLimitsTitle => 'VERBINDUNGS-LIMITS';

  @override
  String get onboardingFactLimitsBody =>
      'Die Limits für die Chat-Kapazität sollen zu bewussten, bedeutungsvollen Beziehungen anregen. Die Begrenzung der Kapazität sorgt dafür, dass Gespräche zielgerichtet bleiben und auf echten Kontakten basieren.';

  @override
  String get onboardingFactKdfTitle => 'SICHERHEITS-HASHING';

  @override
  String get onboardingFactKdfBody =>
      'Eine Standard-PIN kann in Millisekunden per Brute-Force geknackt werden. Wiltkey verarbeitet deine PIN durch eine Härtungsfunktion, wodurch Brute-Force-Angriffe auf die lokale Datenbank unmöglich werden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsTabProfile => 'Profil';

  @override
  String get settingsTabNetwork => 'Netzwerk';

  @override
  String get settingsTabAlerts => 'Benachrichtigungen';

  @override
  String get settingsSavedIndicator => 'Gespeichert';

  @override
  String get settingsProfileSectionAppearance => 'Aussehen';

  @override
  String get settingsProfileSectionAvatar => 'Pixel-Art-Avatar';

  @override
  String get settingsProfileSectionProfile => 'Profileinstellungen';

  @override
  String get settingsProfileBrushColor => 'Pinselfarbe';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Löschen';

  @override
  String get settingsProfileChipRandom => 'Zufällig';

  @override
  String get avatarEditButton => 'Avatar bearbeiten';

  @override
  String get groupCreateEditIcon => 'Symbol bearbeiten';

  @override
  String get settingsProfileUsername => 'Benutzername';

  @override
  String get settingsProfileBleNick => 'Kurzname (5 Zeichen)';

  @override
  String get settingsProfileKeyhash => 'Konto-ID';

  @override
  String get settingsProfileKeyhashCopied =>
      'Konto-ID in die Zwischenablage kopiert';

  @override
  String get settingsProfileChangePinButton => 'PIN ändern';

  @override
  String get settingsProfileResetIdentityButton => 'Konto zurücksetzen';

  @override
  String get settingsResetConfirmTitle => 'Identität zurücksetzen?';

  @override
  String get settingsResetConfirmBody =>
      'Dies wird dauerhaft alle Nachrichten und Kontakte löschen und eine neue Identität erstellen. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get settingsResetConfirmCancel => 'Abbrechen';

  @override
  String get settingsResetConfirmReset => 'Zurücksetzen';

  @override
  String get settingsChangePinTitle => 'PIN ändern';

  @override
  String get settingsChangePinOldPin => 'Aktuelle PIN eingeben';

  @override
  String get settingsChangePinNewPin => 'Neue PIN eingeben (4–6 Ziffern)';

  @override
  String get settingsChangePinConfirmPin => 'Neue PIN bestätigen';

  @override
  String get settingsChangePinEmptyFieldsError =>
      'Bitte fülle alle Felder aus.';

  @override
  String get settingsChangePinLengthError =>
      'Die neue PIN muss 4 bis 6 Ziffern lang sein.';

  @override
  String get settingsChangePinMatchError =>
      'Die neuen PINs stimmen nicht überein.';

  @override
  String get settingsChangePinUpdatedSnackBar => 'PIN aktualisiert.';

  @override
  String get settingsChangePinIncorrectError => 'Die aktuelle PIN ist falsch.';

  @override
  String get settingsNetworkRoutingTitle => 'Netzwerkeinstellungen';

  @override
  String get settingsNetworkDevRelayToggle =>
      'Lokalen Entwickler-Server verwenden';

  @override
  String get settingsNetworkDevRelayUrlLabel => 'Entwickler-Server-URL';

  @override
  String get settingsNetworkDevRelayDescription =>
      'Das Aktivieren dieser Option überschreibt den Produktionsserver und leitet Nachrichten über einen lokalen Server um.';

  @override
  String get settingsNetworkActiveGateway => 'Aktuelle Server-URL';

  @override
  String get settingsNetworkDiagnostics => 'Diagnose';

  @override
  String get settingsNetworkDebugButton => 'Debug-Konsole öffnen';

  @override
  String get settingsDebugButtonsToggle => 'Debugger-Schaltflächen';

  @override
  String get settingsDebugButtonsDescription =>
      'Zeigt die Terminal-Konsolen-Schaltfläche in der Chatliste und in Chats an.';

  @override
  String get settingsDebugTitle => 'Debug-Konsole';

  @override
  String get settingsAlertsBackgroundNotifications =>
      'Hintergrund-Benachrichtigungen';

  @override
  String get settingsAlertsExplanation =>
      'Benachrichtigungen zeigen nur \'Du hast eine Nachricht\' an. Deine Nachrichten bleiben verschlüsselt, bis du die App entsperrst.';

  @override
  String get settingsTextSizeLabel => 'Chat-Textgröße';

  @override
  String get settingsTextSizePreview => 'So werden deine Nachrichten aussehen.';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemsprache';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageHungarian => 'Magyar (Ungarisch)';

  @override
  String get settingsLanguagePolish => 'Polski (Polnisch)';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageFrench => 'Français (Französisch)';

  @override
  String get settingsLanguageSwedish => 'Svenska (Schwedisch)';

  @override
  String get settingsLanguageChinese => '中文 (Chinesisch)';

  @override
  String get notificationModeOff => 'Aus';

  @override
  String get notificationModeOffDesc =>
      'Keine Hintergrundprüfung. Du siehst Nachrichten erst, wenn du die App öffnest.';

  @override
  String get notificationModeLowPower => 'Energiesparen';

  @override
  String get notificationModeLowPowerDesc =>
      'Prüft etwa alle 10 Minuten auf neue Nachrichten. Schont den Akku.';

  @override
  String get notificationModeInstant => 'Sofort';

  @override
  String get notificationModeInstantDesc =>
      'Hält eine sichere Verbindung im Hintergrund aktiv für sofortige Benachrichtigungen. Zeigt eine dauerhafte Benachrichtigung und verbraucht mehr Akku.';

  @override
  String get notificationNewMessageBody => 'Du hast eine Nachricht';

  @override
  String get notificationSecureLinkActive => 'Sichere Verbindung aktiv';

  @override
  String get chatsLockedSubtitle =>
      'Gesperrt · zum Entsperren persönlich koppeln';

  @override
  String chatsMemberCount(int count) {
    return '$count Mitglieder';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: 'Kontakte',
      one: 'Kontakt',
    );
    return '$totalCount $_temp0 · $lockedCount gesperrt';
  }

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsPopupPair => 'Gerät koppeln';

  @override
  String get chatsPopupCreateGroup => 'Gruppe erstellen';

  @override
  String get chatsPopupJoinGroup => 'Gruppe beitreten';

  @override
  String get chatsSearchHint => 'Suchen';

  @override
  String get chatsEmptyNoMatches => 'Keine Treffer';

  @override
  String get chatsEmptyNoChats => 'Noch keine Chats';

  @override
  String get chatsEmptyPairInstruction =>
      'Kopple ein Gerät persönlich, um mit dem Chatten zu beginnen.';

  @override
  String get chatsEmptyPairButton => 'Gerät koppeln';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return 'ICH $remaining · PARTNER $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded =>
      'Zu viele falsche Versuche. Gerät gelöscht.';

  @override
  String pinAccessDenied(int attempts) {
    return 'Falsche PIN. Noch $attempts Versuche übrig.';
  }

  @override
  String get pinMinLengthError =>
      'Die PIN muss mindestens 4 Ziffern lang sein.';

  @override
  String get pinPurgeConfirmTitle => 'Gerät zurücksetzen?';

  @override
  String get pinPurgeConfirmBody =>
      'PIN vergessen? Dies wird dauerhaft alle Nachrichten löschen und dein Konto zurücksetzen. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get pinPurgeConfirmButton => 'Gerät zurücksetzen';

  @override
  String get pinLockedTitle => 'Gesperrt';

  @override
  String get pinLockedSubtitle => 'PIN eingeben, um zu entsperren';

  @override
  String get pinUnlockButton => 'Entsperren';

  @override
  String get pinUseFingerprintButton => 'Fingerabdruck verwenden';

  @override
  String get settingsBiometricToggle => 'Entsperren per Fingerabdruck';

  @override
  String get settingsBiometricDescription =>
      'Mit dem Fingerabdruck statt der PIN entsperren. Nach 4 Stunden Inaktivität wird wieder die PIN verlangt.';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Fingerabdruck-Entsperrung konnte nicht aktiviert werden.';

  @override
  String get pinForgotButton => 'PIN vergessen? Gerät zurücksetzen';

  @override
  String get pairTitle => 'Geräte koppeln';

  @override
  String get pairRequestDialogTitle => 'Kopplungsanfrage';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName möchte sich koppeln.\n\nChat-Größe: $size.\n\nSicheres Koppeln akzeptieren?';
  }

  @override
  String get pairRequestReject => 'Ablehnen';

  @override
  String get pairRequestAccept => 'Akzeptieren';

  @override
  String get pairPingStatusPinging => 'Testen...';

  @override
  String pairPingStatusLatency(String latency) {
    return 'Latenz: ${latency}ms';
  }

  @override
  String get pairPingStatusFailed => 'Fehlgeschlagen';

  @override
  String get pairPingStatusTest => 'Verbindung testen';

  @override
  String get pairDeviceNameLabel => 'Dein Gerätename';

  @override
  String get pairDeviceNameHint => 'Name eingeben';

  @override
  String get pairDiscoverableTitle => 'Gerät sichtbar machen';

  @override
  String get pairDiscoverableSubtitle =>
      'Erlaube Freunden in der Nähe, dich zu finden';

  @override
  String get pairNearbyDevicesTitle => 'Geräte in der Nähe';

  @override
  String get pairNearbyDevicesInstruction =>
      'Halte die Geräte nebeneinander, um sich zu verbinden.';

  @override
  String get pairDirectSyncFormRelayLabel => 'Server-URL';

  @override
  String get pairDirectSyncFormSyncButton => 'Geräte verbinden';

  @override
  String get pairSyncingConnecting => 'Verbinden...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return 'Erstelle sicheren Schlüssel ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return 'Schlüssel: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return '$percent% abgeschlossen';
  }

  @override
  String get pairSuccessConnectionSecured => 'Erfolgreich verbunden';

  @override
  String pairSuccessGroupBody(String groupName) {
    return 'Gruppe \"$groupName\" beigetreten. Sichere Schlüssel wurden lokal auf deinem Gerät erstellt.';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return 'Sichere Schlüssel wurden ausgetauscht und auf deinem Gerät generiert. Verbunden mit $title mit einer Kapazität von $label.';
  }

  @override
  String get pairSuccessReturnButton => 'Gehe zu Chats';

  @override
  String get chatDetailsTitle => 'Chat-Details';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return 'Name: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => 'Offizielles Relay';

  @override
  String get chatDetailsPrivateNode => 'Privater Knoten';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return 'ICH $remaining · PARTNER $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => 'Profil';

  @override
  String get chatDetailsProfileExplanation =>
      'Avatare und Spitznamen werden beim Verbinden automatisch synchronisiert. Du kannst deinen jetzt manuell synchronisieren, falls nötig.';

  @override
  String get chatDetailsProfileSyncButton => 'Profil synchronisieren';

  @override
  String get chatDetailsProfileSnackBar => 'Profil gesendet.';

  @override
  String get chatDetailsSectionPermissions => 'Berechtigungen';

  @override
  String get chatDetailsPermissionsPhotos => 'Teilen von Fotos erlauben';

  @override
  String get chatDetailsPermissionsEmojis => 'Eigene Emojis';

  @override
  String get chatDetailsPermissionsEmojisAvailable => 'Verfügbar';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize => 'Erfordert größeren Chat';

  @override
  String get chatDetailsSectionMetadata => 'Metadaten-Bereich';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return 'Dieser Chat reserviert $budget des gesamten Speicherplatzes ($max) für Einstellungen, Profilbilder und eigene Emojis.';
  }

  @override
  String get chatDetailsSectionLanes => 'Sichere Kanäle';

  @override
  String get chatDetailsLanesMySend => 'Meine Sende-Kapazität';

  @override
  String get chatDetailsLanesPeerSend => 'Partner-Sende-Kapazität';

  @override
  String get chatDetailsLanesBorrowed => 'Geliehener Speicherplatz';

  @override
  String get chatDetailsLanesCapacityLeft => 'Meine verbleibende Kapazität';

  @override
  String get chatDetailsLanesExplanation =>
      'Wenn deine Sende-Kapazität zur Neige geht, kannst du ungenutzten Speicherplatz von deinem Partner leihen. Dies kann auch automatisch geschehen, damit du weiterchatten kannst.';

  @override
  String get chatDetailsLanesBorrowButton => 'Chat-Speicherplatz anfordern';

  @override
  String get chatDetailsLanesSnackBar => 'Anforderung an Partner gesendet.';

  @override
  String get chatDetailsSectionEmojis => 'Eigene Emojis';

  @override
  String get chatDetailsEmojisExplanation =>
      'Verwende diese eigenen Emojis in deinen Nachrichten im Format :name:.';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      'Diese Chat-Kapazität ist zu klein für eigene Emojis. Verbinde dich mit mehr Kapazität, um sie zu aktivieren.';

  @override
  String get chatDetailsEmojisCreate => 'Erstellen';

  @override
  String get chatDetailsSectionDestructive => 'Gefährliche Einstellungen';

  @override
  String get chatDetailsNukeButton => 'Chat sprengen (beide Seiten)';

  @override
  String get chatDetailsDeleteEmojiTitle => 'Emoji löschen?';

  @override
  String get chatDetailsDeleteEmojiBody =>
      'Dieses eigene Emoji wird dauerhaft gelöscht. Möchtest du fortfahren?';

  @override
  String get chatDetailsDeleteEmojiDelete => 'Löschen';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return ':$name: hinzugefügt';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return 'Bild zu groß ($cost) für verbleibenden Speicherplatz ($charge).';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar => 'Bild zu groß zum Senden.';

  @override
  String get chatTapForDetails => 'Tippen für Details';

  @override
  String get chatEncrypting => 'Verschlüsseln…';

  @override
  String get chatScreenshotDetected => 'Screenshot erkannt';

  @override
  String get chatScreenshotExplanation =>
      'Ein Screenshot wurde erkannt. Zu deiner Sicherheit kannst du deine Schlüssel und Nachrichten jetzt löschen.';

  @override
  String get chatScreenshotWipeButton => 'Nachrichten und Schlüssel löschen';

  @override
  String get chatScreenshotIgnoreButton => 'Warnung ignorieren';

  @override
  String get chatSimulateScreenshotButton => 'Screenshot simulieren';

  @override
  String chatCostIndicator(String cost) {
    return 'Kosten: $cost';
  }

  @override
  String get groupCreateTitle => 'Gruppe erstellen';

  @override
  String get groupCreatePixelArtIcon => 'Gruppenbild';

  @override
  String get groupCreateRandomIcon => 'Generieren';

  @override
  String get groupCreateClearIcon => 'Löschen';

  @override
  String get groupCreateNameLabel => 'Gruppenname';

  @override
  String get groupCreateNameEmptyValidator => 'Gib einen Gruppennamen ein';

  @override
  String get groupCreateNameLengthValidator => 'Maximal 24 Zeichen';

  @override
  String get groupCreatePoliciesSection => 'Gruppenrichtlinien-Einstellungen';

  @override
  String get groupCreatePolicyPadSize => 'Gruppen-Chat-Größe';

  @override
  String get groupCreatePolicyLaneSize => 'Kapazität pro Mitglied';

  @override
  String get groupCreatePolicyMaxMembersLabel => 'Maximale Mitgliederzahl';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return 'Max. $count Mitglieder';
  }

  @override
  String get groupCreatePolicyAllowImages => 'Teilen von Fotos erlauben';

  @override
  String get groupCreatePolicyAllowImagesSub =>
      'Mitgliedern das Senden von Fotos erlauben';

  @override
  String get groupCreatePolicyPayloadSize => 'Maximale Nachrichtengröße';

  @override
  String get groupCreateButton => 'Gruppe erstellen';

  @override
  String groupCreateFailedSnackBar(String error) {
    return 'Fehler beim Erstellen der Gruppe: $error';
  }

  @override
  String get pairSyncingAwaitingApproval =>
      'Warte darauf, dass dein Freund akzeptiert...';

  @override
  String get pairSyncingCoordinating => 'Richte Schlüsselaustausch ein...';

  @override
  String get pairSyncingStep1 => 'Erstelle sichere Verbindung...';

  @override
  String get pairSyncingStep2 => 'Erzeuge Sicherheits-Seed...';

  @override
  String pairSyncingStep3(String seed) {
    return 'Tausche öffentliche Schlüssel aus... $seed';
  }

  @override
  String get pairSyncingStep4 => 'Generiere sichere Chat-Schlüssel...';

  @override
  String get pairSyncingStep5 => 'Überprüfe Schlüssel-Integrität...';

  @override
  String get pairSyncingStep6 =>
      'Sichere Einrichtung erfolgreich abgeschlossen.';

  @override
  String chatRemainingLabel(String bytes) {
    return '$bytes verbleibend';
  }

  @override
  String get chatLockedLabel => 'Gesperrt · zum Fortfahren persönlich koppeln';

  @override
  String get chatMessageHint => 'Nachricht';

  @override
  String get chatVoiceComingSoon => 'Sprachnachrichten kommen bald.';

  @override
  String get chatDetailsDeleteConfirmTitle => 'Chat löschen?';

  @override
  String get chatDetailsDeleteConfirmBody =>
      'Dies wird dauerhaft alle Nachrichten und Verschlüsselungsschlüssel für diesen kontakt löschen. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get chatDetailsDeleteConfirmButton => 'Chat löschen';

  @override
  String get chatsActionArchive => 'Archivieren';

  @override
  String get chatsActionNuke => 'Chat & Schlüssel löschen';

  @override
  String get chatsActionDelete => 'Löschen';

  @override
  String get chatsArchivedBadge => 'Archiviert';

  @override
  String get chatsArchivedSubtitle => 'Archiviert · schreibgeschützt';

  @override
  String get chatsArchiveConfirmTitle => 'Chat archivieren?';

  @override
  String get chatsArchiveConfirmBody =>
      'Das schafft Platz, indem der Einmalschlüssel dieses Chats gelöscht wird. Deine Nachrichten bleiben lesbar, aber der Chat wird schreibgeschützt — du kannst darin nichts mehr senden oder empfangen.';

  @override
  String get chatsArchiveConfirmButton => 'Archivieren';

  @override
  String get chatsActionPin => 'Anpinnen';

  @override
  String get chatsActionUnpin => 'Lösen';

  @override
  String get chatsFilterAll => 'Alle';

  @override
  String get chatsFilterDirect => 'Direkt';

  @override
  String get chatsFilterGroups => 'Gruppen';

  @override
  String get chatsSectionArchived => 'Archiviert';

  @override
  String groupTapForDetails(String hostName) {
    return 'Tippen für Details · Host: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    return '$count freie Kanäle verfügbar';
  }

  @override
  String get groupHost => 'Host';

  @override
  String get groupMember => 'Mitglied';

  @override
  String get groupDepleted => 'Aufgebraucht';

  @override
  String groupSyncingFromMember(String name) {
    return 'Synchronisiere Details und Nachrichten von $name...';
  }

  @override
  String get groupInviteMember => 'Mitglied einladen';

  @override
  String get groupLeaveGroup => 'Gruppe verlassen';

  @override
  String get groupRemoveMember => 'Mitglied entfernen';

  @override
  String get groupRemoveMemberTitle => 'Mitglied entfernen?';

  @override
  String groupRemoveMemberBody(String name) {
    return 'Möchtest du $name aus der Gruppe entfernen? Dadurch wird ihr paarweiser Schlüssel gelöscht.';
  }

  @override
  String get groupLeaveGroupTitle => 'Gruppe verlassen?';

  @override
  String get groupLeaveGroupBody =>
      'Möchtest du diese Gruppe verlassen? Dadurch werden lokale paarweise Schlüssel und Protokolle gelöscht.';

  @override
  String get groupSyncStepText => 'Synchronisieren';

  @override
  String get groupDecryptingImage => 'Entschlüssele Bild...';

  @override
  String get groupTapToRevealImage => 'Tippen, um Bild zu zeigen';

  @override
  String groupImageSize(String size) {
    return 'Größe: $size';
  }

  @override
  String get groupImageFailedToLoad => 'Bild konnte nicht geladen werden';

  @override
  String get groupScreenshotWipeButton => 'Alle Schlüssel jetzt löschen';

  @override
  String get groupRefillGranted => 'Kanal-Nachfüllung erfolgreich gewährt.';

  @override
  String groupRefillFailed(String error) {
    return 'Fehler beim Nachfüllen: $error';
  }

  @override
  String get groupLaneDepleted => 'Kanal aufgebraucht';

  @override
  String get groupLaneDepletedExplanation =>
      'Fordere eine Byte-Nachfüllung vom Gruppen-Host an.';

  @override
  String get groupRefillRequestSent => 'Nachfüllanfrage an Host übertragen.';

  @override
  String get groupRequestRefill => 'Nachfüllung anfordern';

  @override
  String groupExceedsSizeLimit(int size) {
    return 'Überschreitet Größenlimit ($size B)';
  }

  @override
  String get groupDetailsTitle => 'Gruppendetails';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return 'Gemeinsamer Bereich · Host: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => 'Gruppenrichtlinien';

  @override
  String get groupDetailsSavePoliciesButton => 'Richtlinien speichern';

  @override
  String get groupDetailsSavePoliciesSnackBar =>
      'Gruppenrichtlinien gespeichert.';

  @override
  String get groupDetailsSectionEmojis => 'Eigene Emojis';

  @override
  String get groupDetailsSectionMetadata => 'Metadaten-Bereich';

  @override
  String get groupDetailsMetadataExplanation =>
      'Kanal 0 des gemeinsamen Bereichs reserviert 1 MB für Gruppen-Metadaten – das Gruppenbild, die Mitgliederliste und eigene Emojis befinden sich hier.';

  @override
  String get groupDetailsSectionSync => 'Gruppensynchronisierung';

  @override
  String get groupDetailsSyncExplanation =>
      'Fordere die neuesten Gruppendetails, Richtlinien und Mitgliederlisten vom Host an.';

  @override
  String get groupDetailsSyncButton => 'Details synchronisieren';

  @override
  String get groupDetailsSyncSnackBar =>
      'Gruppenaktualisierung vom Host angefordert.';

  @override
  String get groupDetailsSectionDestructive => 'Gefährliche Einstellungen';

  @override
  String get groupDetailsLeaveButton => 'Gruppe verlassen';

  @override
  String get groupDetailsNukeButton => 'Gruppe löschen';

  @override
  String get groupDetailsDeleteConfirmTitle => 'Gruppe löschen?';

  @override
  String get groupDetailsDeleteConfirmBody =>
      'Dies wird diese Gruppe dauerhaft löschen und den gesamten Chatverlauf sowie die Schlüssel für alle Mitglieder löschen. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get groupDetailsDeleteConfirmButton => 'Gruppe löschen';

  @override
  String get chatImageCompressionTitle => 'Bild komprimieren';

  @override
  String chatImageCompressionOriginal(String size) {
    return 'Original: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return 'Geschätzt: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return 'Geschätzt: $size (Ersparnis ~$saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return 'Kostenbelastung: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation =>
      'Konvertiert in WebP, max. 2000px.';

  @override
  String get chatImageCompressionLowSize => 'Klein';

  @override
  String get chatImageCompressionHighSize => 'Groß';

  @override
  String get chatImageCompressionMaxQuality => 'Beste Qualität';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return '$percent% Qualität';
  }

  @override
  String get chatImageCompressionSendHidden =>
      'Versteckt senden (Tippen zum Anzeigen)';

  @override
  String get chatImageCompressionSendButton => 'Senden';

  @override
  String get groupGrantRefill => 'Nachfüllung gewähren';

  @override
  String get groupLaneLocked => 'Gesperrt · keine Bytes übrig';

  @override
  String get groupMembersTitle => 'Gruppenmitglieder';

  @override
  String get groupMembersExplanation =>
      'Alle Mitglieder teilen sich eine in Kanäle aufgeteilte Chat-Größe. Nachrichten werden über den Server gesendet.';

  @override
  String get pairChatSize => 'Chat-Größe';

  @override
  String get chatSystemConnected => 'Verbunden. Chat-Sitzung sicher.';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return 'Gruppe \"$groupName\" beigetreten. Verbindungen sicher.';
  }

  @override
  String get themeCyberpunkName => 'Neon-Gitter';

  @override
  String get themeCyberpunkDesc =>
      'Das Original. Obsidian, leuchtendes Cyan, Terminal-Stil.';

  @override
  String get themeGardenName => 'Abendgarten';

  @override
  String get themeGardenDesc =>
      'Weiche Erdtöne, warmes Leinen, Blütenblätter für dein Budget.';

  @override
  String get themePaperinkName => 'Papier & Tinte';

  @override
  String get themePaperinkDesc =>
      'Warmes Washi-Papier, Sumi-Tinte in Abstufungen, zinnoberrotes Hanko-Siegel.';
}
