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
  String get settingsTabSecurity => 'Sicherheit';

  @override
  String get settingsSecuritySectionAccess => 'Zugriff & Entsperren';

  @override
  String get settingsSecuritySectionDanger => 'Gefahrenzone';

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
  String get settingsProfileSectionOtherVisuals => 'Weitere Optik';

  @override
  String get settingsThemeLabel => 'Design';

  @override
  String get settingsPixelArtEditor => 'Pixel-Art-Editor';

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
  String get changePinVerifyTitle => 'Aktuelle PIN bestätigen';

  @override
  String get changePinVerifyPrompt =>
      'Gib deine aktuelle PIN ein, um fortzufahren.';

  @override
  String get changePinSetTitle => 'Neue PIN festlegen';

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
      'Prüft im Hintergrund regelmäßig auf neue Nachrichten – schnell direkt nach dem Schließen der App, dann seltener, um den Akku zu schonen. Keine ständige Verbindung, daher können Benachrichtigungen verzögert eintreffen.';

  @override
  String get notificationModeInstant => 'Sofort';

  @override
  String get notificationModeInstantDesc =>
      'Optional. Hält im Hintergrund eine Ende-zu-Ende-verschlüsselte Verbindung offen, um eingehende Nachrichten in Echtzeit zu synchronisieren, angezeigt durch eine dauerhafte Benachrichtigung. Wiltkey nutzt dies aus Datenschutzgründen anstelle von Push-Diensten von Google oder Apple und funktioniert daher auch ohne Google Play Services – auf Kosten von mehr Akkuverbrauch.';

  @override
  String get notificationNewMessageBody => 'Du hast eine Nachricht';

  @override
  String get notificationSecureLinkActive =>
      'Sichere Nachrichten werden synchronisiert';

  @override
  String get onboardingNotificationsTitle => 'Benachrichtigungen';

  @override
  String get onboardingNotificationsExplanation =>
      'Wiltkey verwendet keine Push-Dienste von Google oder Apple – nichts über deine Nachrichten erreicht deren Server. Wähle, wie du benachrichtigt werden möchtest. Du kannst dies jederzeit in den Einstellungen ändern.';

  @override
  String get onboardingFactPushTitle => 'KEINE PUSH-SERVER';

  @override
  String get onboardingFactPushBody =>
      'Normale Apps leiten deine Benachrichtigungen über Google oder Apple und verraten so, wer dir wann schreibt. Wiltkey tut das nie – standardmäßig gibt es keine Hintergrundabfragen, und jede Benachrichtigung läuft vollständig auf deinem Gerät.';

  @override
  String get notificationModeInstantDescFcm =>
      'Optional. Nutzt den Push-Dienst von Google als leichtes Wecksignal, damit neue Nachrichten in Echtzeit ankommen. Über Google läuft nur ein inhaltsloser Ping – niemals deine Nachrichten, die Ende-zu-Ende-verschlüsselt auf dem Relay bleiben, bis dein Gerät sie abruft. Schont den Akku mehr als eine dauerhafte Verbindung.';

  @override
  String get onboardingNotificationsExplanationFcm =>
      'Für Echtzeit-Benachrichtigungen nutzt diese Version den Push-Dienst von Google nur als Wecksignal – ein inhaltsloser Ping, niemals deine Nachrichten, die die Server von Google nie berühren. Wähle, wie du benachrichtigt werden möchtest; du kannst das jederzeit in den Einstellungen ändern.';

  @override
  String get onboardingFactPushTitleFcm => 'INHALTSLOSER PUSH';

  @override
  String get onboardingFactPushBodyFcm =>
      'Normale Apps leiten deine Benachrichtigungsinhalte über Google und verraten, was wann gesendet wird. Diese Version nutzt Google nur als inhaltslosen Weck-Ping – keine Nachrichtendaten, keine lesbaren Metadaten – und alles bleibt Ende-zu-Ende-verschlüsselt.';

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
      'Mit dem Fingerabdruck statt der PIN entsperren. Nach dem unten eingestellten Zeitraum wird wieder die PIN verlangt.';

  @override
  String get settingsBiometricIdleTitle => 'PIN-Rückfall';

  @override
  String get settingsBiometricIdleDescription =>
      'Nach dieser Zeit ohne Entsperren wird wieder die PIN verlangt.';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours Std.';
  }

  @override
  String get settingsBiometricIdleNever => 'Nie';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Fingerabdruck-Entsperrung konnte nicht aktiviert werden.';

  @override
  String get pinForgotButton => 'PIN vergessen? Gerät zurücksetzen';

  @override
  String get pairTitle => 'Geräte koppeln';

  @override
  String get pairRescanTooltip => 'Suche aktualisieren';

  @override
  String get pairBluetoothOffWarning =>
      'Bluetooth ist aus. Zum Koppeln wird Bluetooth benötigt, um Geräte in der Nähe zu finden — bitte einschalten, um fortzufahren.';

  @override
  String get pairBluetoothTurnOnButton => 'Bluetooth einschalten';

  @override
  String get pairDoNotExitWarning =>
      'Lass WiltKey geöffnet – wechsle nicht die App und beende sie nicht, bis die Kopplung auf BEIDEN Geräten abgeschlossen ist.';

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
  String get chatImageNeedsPlusSnackBar =>
      'Bild zu groß für die kostenlose Stufe – WiltKey Plus hebt das Limit auf 50 MB an.';

  @override
  String get chatTapForDetails => 'Tippen für Details';

  @override
  String get chatSyncTooltip => 'Nachrichten synchronisieren';

  @override
  String get chatStickerHint => 'Emoji halten, um einen Sticker zu senden';

  @override
  String get chatSyncStarted => 'Suche nach verpassten Nachrichten…';

  @override
  String get chatSyncOffline => 'Synchronisierung offline nicht möglich.';

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
  String get groupCreateProgressTitle => 'Gruppe wird erstellt…';

  @override
  String get groupCreateProgressSubtitle =>
      'Der Verschlüsselungsvorrat der Gruppe und die Kapazität der Mitglieder werden vorbereitet. Das kann einen Moment dauern – bitte hab Geduld.';

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
  String get chatVoiceHoldHint =>
      'Zum Aufnehmen einer Sprachnachricht gedrückt halten.';

  @override
  String get chatVoiceReleaseCancel => 'Loslassen zum Abbrechen';

  @override
  String get chatVoicePermissionDenied =>
      'Zum Aufnehmen von Sprachnachrichten wird die Mikrofonberechtigung benötigt.';

  @override
  String get chatVoiceQualityLofi => 'Lo-fi';

  @override
  String get chatVoiceQualityVoice => 'Sprache';

  @override
  String get chatVoiceQualityClear => 'Klar';

  @override
  String get chatVoiceUnavailable => 'Sprachnachricht nicht verfügbar';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return 'Sprachnachricht zu groß ($cost) für den verbleibenden Platz ($charge).';
  }

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
  String get chatFileTapToDownload => 'Zum Herunterladen tippen';

  @override
  String get chatFileDownloadFailed => 'Zum Wiederholen tippen';

  @override
  String get chatFileKindPhoto => 'Foto';

  @override
  String get chatFileKindVoice => 'Sprachnachricht';

  @override
  String get chatFileKindFile => 'Datei';

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
  String get chatImageCompressionUncompressed => 'Unkomprimiert';

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

  @override
  String get themePickerPlayExclusive =>
      'Dieses Theme gibt es exklusiv in der Play-Store-Version von WiltKey.';

  @override
  String get themePreviewTooltip => 'Vorschau';

  @override
  String get themePreviewSectionDashboard => 'Chatliste';

  @override
  String get themePreviewSectionChat => 'Unterhaltung';

  @override
  String get themePreviewSectionEffects => 'Spezialeffekte';

  @override
  String get themePreviewPlayUnlock => 'Entsperr-Animation abspielen';

  @override
  String get themePreviewPlayNuke => 'Selbstzerstörungs-Animation abspielen';

  @override
  String get themePreviewApply => 'Dieses Theme verwenden';

  @override
  String get themePreviewGetInShop => 'Im Shop holen';

  @override
  String get themePreviewMsgThem1 =>
      'Nur noch 800 Bytes auf unserem Pad, wollen wir uns treffen?';

  @override
  String get themePreviewMsgMe =>
      'Klar! Filmabend bei mir? Dann laden wir auch gleich auf';

  @override
  String get themePreviewMsgThem2 => 'deal, ich bring Snacks 🍿';

  @override
  String get themePreviewRowPhoto => 'Foto aus der Boulderhalle 🧗';

  @override
  String get themePreviewRowLost => 'Pad leer — zum Aufladen treffen';

  @override
  String get accessibilityWarningTitle => 'Bedienungshilfe aktiv';

  @override
  String accessibilityWarningBody(String names) {
    return 'Ein Bedienungshilfedienst, der Bildschirminhalte lesen kann, ist aktiv: $names. Das ist bei Tools wie Screenreadern oder Passwortmanagern normal. Falls du keinen aktiviert hast, überprüfe deine Bedienungshilfe-Einstellungen.';
  }

  @override
  String get accessibilityWarningDismiss => 'Schließen';

  @override
  String get accessibilityWarningOpenSettings => 'Einstellungen prüfen';

  @override
  String get chatImageCompressionAllowDownload =>
      'Speichern in Galerie erlauben';

  @override
  String get chatImageCompressionWilting =>
      'Welkendes Bild (verschwindet nach dem Öffnen)';

  @override
  String get chatImageDownload => 'Herunterladen';

  @override
  String get chatImageSaveAs => 'Speichern als';

  @override
  String get chatImageSavedToGallery => 'In Galerie gespeichert';

  @override
  String get chatImageSaveFailed => 'Bild konnte nicht gespeichert werden';

  @override
  String get chatImageSourceTitle => 'Foto senden';

  @override
  String get chatImageSourceCamera => 'Foto aufnehmen';

  @override
  String get chatImageSourceGallery => 'Aus Galerie wählen';

  @override
  String get screenshotRequestTooltip => 'Screenshot anfragen';

  @override
  String get screenshotWaiting => 'Warten auf Zustimmung…';

  @override
  String get screenshotConsentTitle => 'Screenshot-Anfrage';

  @override
  String screenshotConsentBody(String name) {
    return '$name möchte einen Screenshot dieses Chats speichern. Erlauben?';
  }

  @override
  String get screenshotDenied => 'Screenshot-Anfrage wurde abgelehnt.';

  @override
  String get screenshotCaptureFailed =>
      'Screenshot konnte nicht erstellt werden.';

  @override
  String get screenshotWatermark => 'WiltKey — Screenshot mit Zustimmung';

  @override
  String screenshotRequestInline(String name) {
    return '$name hat einen Screenshot angefordert';
  }

  @override
  String get screenshotRequestAllowed => 'Du hast den Screenshot erlaubt';

  @override
  String get screenshotRequestDeclined => 'Du hast den Screenshot abgelehnt';

  @override
  String get screenshotRequestExpired => 'Screenshot-Anfrage abgelaufen';

  @override
  String get wiltingTapToReveal => 'Tippen, um die welkende Nachricht zu sehen';

  @override
  String get wiltingMessageTag => 'Welkende Nachricht';

  @override
  String get wiltedMessage => 'Verwelkte Nachricht';

  @override
  String get wiltingSheetTitle => 'Welkende Nachricht';

  @override
  String get wiltingSheetBody =>
      'Die Nachricht verschwindet so viele Sekunden, nachdem der Empfänger sie geöffnet hat.';

  @override
  String get wiltingSheetSend => 'Welkende Nachricht senden';

  @override
  String get wiltingHoldToSendHint =>
      'Halten, um eine welkende Nachricht zu senden';

  @override
  String get replyYou => 'Du';

  @override
  String get replySomeone => 'Jemand';

  @override
  String get replyPreviewImage => '📷 Foto';

  @override
  String get replyPreviewVoice => '🎤 Sprachnachricht';

  @override
  String get replyPreviewMessage => 'Nachricht';

  @override
  String get replyUnavailable => 'Originalnachricht nicht verfügbar';

  @override
  String get shopEntryTitle => 'Shop & WiltKey Plus';

  @override
  String get shopEntrySubtitle => 'Themes, Inhalte & Plus';

  @override
  String get supportEntryTitle => 'Projekt unterstützen';

  @override
  String get supportEntrySubtitle => 'Hilf, WiltKey am Laufen zu halten';

  @override
  String get shopTitle => 'Shop';

  @override
  String get supportTitle => 'WiltKey unterstützen';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => 'Freischaltungen';

  @override
  String get shopPlusTagline =>
      'Längere Offline-Speicherung von Nachrichten und größere Dateiübertragungen.';

  @override
  String get shopEmptyTitle => 'Hier ist noch nichts';

  @override
  String get shopEmptyBody =>
      'Produkte sind unterwegs – schau bald wieder vorbei.';

  @override
  String get shopRestoreButton => 'Käufe wiederherstellen';

  @override
  String get shopRestoredSnack => 'Käufe wiederhergestellt';

  @override
  String get shopBuyButton => 'Kaufen';

  @override
  String get shopOwnedLabel => 'Gekauft';

  @override
  String get shopActiveLabel => 'Aktiv';

  @override
  String get shopManageNote => 'In Google Play verwalten';

  @override
  String get shopPurchasePendingSnack => 'Kauf ausstehend…';

  @override
  String get shopPurchaseFailedSnack =>
      'Kauf konnte nicht abgeschlossen werden';

  @override
  String get supportIntro =>
      'WiltKey ist kostenlos und quelloffen, und in dieser Version sind alle kosmetischen Inhalte kostenlos freigeschaltet. Wenn du die Entwicklung und den offiziellen Relay unterstützen möchtest, besuche die Seite unten.';

  @override
  String get supportOpenButton => 'Support-Seite öffnen';

  @override
  String get supportFreeNote =>
      'In dieser Version sind alle kosmetischen Inhalte freigeschaltet.';

  @override
  String get shopTabPalettes => 'Paletten';

  @override
  String get shopTabThemes => 'Themes';

  @override
  String get shopTabBorders => 'Rahmen';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'Promo';

  @override
  String get shopPalettesIntro =>
      'Zusätzliche Farben zum Zeichnen deines Avatars und deiner Gruppensymbole. Empfangene Bilder werden immer vollständig dargestellt — ein Paket schaltet nur das eigene Zeichnen mit diesen Farben frei.';

  @override
  String shopPaletteColorCount(int count) {
    return '$count zusätzliche Farben';
  }

  @override
  String get shopThemesEmptyTitle => 'Noch keine Themes';

  @override
  String get shopThemesEmptyBody =>
      'Premium-Themes sind unterwegs – die drei eingebauten Themes bleiben für immer kostenlos.';

  @override
  String get shopBordersSoonTitle => 'Rahmen kommen bald';

  @override
  String get shopBordersSoonBody =>
      'Dekorative Rahmen für deinen Avatar, die alle sehen, mit denen du chattest. In Arbeit.';

  @override
  String get shopPlusBenefitsSection => 'Das bekommst du';

  @override
  String get shopPlusBenefitHold =>
      'Deine Nachrichten warten 72 Stunden statt 24 auf dem Relay, während du offline bist.';

  @override
  String get shopPlusBenefitFiles =>
      'Sende große Dateien – bis zu 50 MB pro Nachricht, über das kostenlose 5-MB-Limit hinaus.';

  @override
  String get shopPlusBenefitPads =>
      'Erstelle größere Pads – bis zu 200 MB für einen Chat und 500 MB für eine Gruppe.';

  @override
  String get shopPlusBenefitSupport =>
      'Du hältst den Relay am Laufen und WiltKey unabhängig.';

  @override
  String get shopSubscribeButton => 'Abonnieren';

  @override
  String get shopPriceUnavailable => 'Nicht verfügbar';

  @override
  String get shopPromoIntro =>
      'Du hast einen Promo-Code? Gib ihn unten ein, und Google Play wendet ihn auf dein Konto an.';

  @override
  String get shopPromoHint => 'PROMO-CODE';

  @override
  String get shopPromoRedeemButton => 'In Google Play einlösen';

  @override
  String get shopPromoNote =>
      'Codes werden im Play Store eingelöst. Nach der Anwendung erscheint deine Freischaltung hier automatisch.';

  @override
  String pairLargerPadsUpsell(String max) {
    return 'Größere Pads mit Plus – bis zu $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return 'Nicht genug freier Speicher – dieser Chat benötigt $needed, du hast $free.';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return 'Keystream wird erzeugt… $written / $total';
  }

  @override
  String get pairKeepAppOpen =>
      'Lass die App geöffnet — das sichere Pad wird noch erstellt.';

  @override
  String groupLargerPadsUpsell(String max) {
    return 'Größere Gruppen-Pads mit Plus – bis zu $max';
  }

  @override
  String get settingsBorderSection => 'Avatar-Rahmen';

  @override
  String get shopBordersIntro =>
      'Rahmen und Accessoires für deinen Avatar. Alle, mit denen du chattest, sehen deinen Rahmen — ein gesperrter verhindert nur das Anlegen, nie die Darstellung.';

  @override
  String get shopBorderSubtitle => 'Avatar-Rahmen';

  @override
  String get shopFreeLabel => 'Gratis';
}
