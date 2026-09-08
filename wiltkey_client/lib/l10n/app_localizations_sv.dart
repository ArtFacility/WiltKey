// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get navChats => 'Chattar';

  @override
  String get navPair => 'Anslut';

  @override
  String get navSettings => 'Inställningar';

  @override
  String get nukedTitle => 'Enhet återställd';

  @override
  String get nukedExplanation =>
      'Alla meddelanden och nycklar har raderats från den här enheten. Den säkra databasen har tömts.';

  @override
  String get nukedResetButton => 'Skapa ny identitet';

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get commonClose => 'Stäng';

  @override
  String get commonSave => 'Spara';

  @override
  String get commonBack => 'Bakåt';

  @override
  String get commonContinue => 'Fortsätt';

  @override
  String get commonFinish => 'Slutför';

  @override
  String get onboardingWelcomeTitle => 'Välkommen till Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'Wiltkey är en privat meddelandeapp som inte sparar metadata, loggar eller serverhistorik. Meddelanden krypteras lokalt och självförstörs om en skärmdump tas.';

  @override
  String get onboardingWelcomeNoHistory =>
      'Ingen serverhistorik. Inga återställningsnycklar.';

  @override
  String get onboardingIntelTitle => 'Säkerhetsinfo';

  @override
  String get onboardingLanguageDescription =>
      'Välj ditt språk för att fortsätta. Du kan ändra det när som helst i Inställningar.';

  @override
  String get onboardingFactLanguageTitle => 'Språkinställning';

  @override
  String get onboardingFactLanguageBody =>
      'Välj ditt språk för att fortsätta. Du kan ändra det när som helst i Inställningar. Ditt val sparas lokalt.';

  @override
  String get onboardingThemeTitle => 'Välj ditt tema';

  @override
  String get onboardingThemeDescription =>
      'Välj ett tema nedan. Du kan ändra detta senare i Inställningar.';

  @override
  String get onboardingProfileTitle => 'Din identitet';

  @override
  String get onboardingProfileUsernameLabel => 'Användarnamn';

  @override
  String get onboardingProfileUsernameHint => 'Ange användarnamn';

  @override
  String get onboardingProfileCodenameLabel =>
      'Anslutningskod (5 bokstäver/siffror)';

  @override
  String get onboardingProfileCodenameExplanation =>
      'Den här koden delas under kopplingen för att ansluta med vänner i närheten.';

  @override
  String get onboardingProfileUsernameError =>
      'Vänligen ange ett användarnamn.';

  @override
  String get onboardingProfileCodenameError =>
      'Anslutningskoden måste vara exakt 5 tecken lång.';

  @override
  String get onboardingAvatarTitle => 'Pixel-avatar';

  @override
  String get onboardingAvatarBrushColor => 'Penselfärg';

  @override
  String get onboardingAvatarRandom => 'Slumpmässig';

  @override
  String get onboardingAvatarClear => 'Rensa';

  @override
  String get onboardingPinTitle => 'PIN-kod';

  @override
  String get onboardingPinExplanation =>
      'Välj en PIN-kod (4–6 siffror) för att skydda dina chattar. Du måste ange denna PIN-kod varje gång du öppnar appen. Om du glömmer koden kan dina meddelanden inte återställas.';

  @override
  String get onboardingPinEnter => 'Ange PIN-kod';

  @override
  String get onboardingPinConfirm => 'Bekräfta PIN-kod';

  @override
  String get onboardingPinLengthError =>
      'PIN-koden måste vara mellan 4 och 6 siffror.';

  @override
  String get onboardingPinMatchError => 'PIN-koderna stämmer inte överens.';

  @override
  String onboardingSetupFailed(String error) {
    return 'Konfigurationen misslyckades: $error';
  }

  @override
  String get onboardingFactMetadataTitle => 'METADATAPROBLEMET';

  @override
  String get onboardingFactMetadataBody =>
      'De flesta chattappar krypterar meddelandeinnehåll men spårar fortfarande vem du pratar med, när och hur ofta. Wiltkey loggar inte metadata, serverdata oder anslutningar.';

  @override
  String get onboardingFactThemeTitle => 'VÄLJ DITT TEMA';

  @override
  String get onboardingFactThemeBody =>
      'Teman är kosmetiska. Samma säkerhetsstandarder gäller för alla teman. Du kan byta tema när som helst i Inställningar.';

  @override
  String get onboardingFactOtpTitle => 'PERFEKT SEKRETESS';

  @override
  String get onboardingFactOtpBody =>
      'Wiltkey använder engångskryptering (OTP) där nycklarna matchar meddelandets storlek, är helt slumpmässiga och aldrig återanvänds. Detta ger matematiskt perfekt säkerhet, vilket gör meddelanden omöjliga att dekryptera utan nycklarna.';

  @override
  String get onboardingFactLimitsTitle => 'ANSLUTNINGSGRÄNSER';

  @override
  String get onboardingFactLimitsBody =>
      'Gränser för chattkapacitet är utformade för att uppmuntra till meningsfulla, medvetna relationer. Att begränsa kapaciteten säkerställer että konversationer är målmedvetna och förankrade i verkliga kontakter.';

  @override
  String get onboardingFactKdfTitle => 'SÄKERHETSHASHNING';

  @override
  String get onboardingFactKdfBody =>
      'En standard PIN-kod kan brute-force-knäckas på millisekunder. Wiltkey kör din PIN-kod genom en härdningsfunktion, vilket gör brute-force-attacker på den lokala databasen omöjliga.';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String get settingsTabProfile => 'Profil';

  @override
  String get settingsTabSecurity => 'Säkerhet';

  @override
  String get settingsSecuritySectionAccess => 'Åtkomst och upplåsning';

  @override
  String get settingsSecuritySectionDanger => 'Farozon';

  @override
  String get settingsTabNetwork => 'Nätverk';

  @override
  String get settingsTabAlerts => 'Aviseringar';

  @override
  String get settingsSavedIndicator => 'Sparad';

  @override
  String get settingsProfileSectionAppearance => 'Utseende';

  @override
  String get settingsProfileSectionAvatar => 'Pixel Art-avatar';

  @override
  String get settingsProfileSectionProfile => 'Profilinställningar';

  @override
  String get settingsProfileSectionOtherVisuals => 'Övrig visuell';

  @override
  String get settingsThemeLabel => 'Tema';

  @override
  String get settingsPixelArtEditor => 'Pixel art-redigerare';

  @override
  String get settingsProfileBrushColor => 'Penselfärg';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Rensa';

  @override
  String get settingsProfileChipRandom => 'Slumpmässig';

  @override
  String get settingsProfileChipTemplateSave => 'Lägg till i mallar';

  @override
  String get settingsProfileTemplateSaved => 'Sparad i mallar';

  @override
  String get settingsProfileTemplatesButton => 'Välj från mall';

  @override
  String get settingsProfileTemplatesTitle => 'Sparade mallar';

  @override
  String get settingsProfileNoTemplates => 'Inga sparade mallar än';

  @override
  String get settingsProfileTemplateEquipped => 'Avatarmall använd';

  @override
  String get avatarEditButton => 'Redigera avatar';

  @override
  String get groupCreateEditIcon => 'Redigera ikon';

  @override
  String get settingsProfileUsername => 'Användarnamn';

  @override
  String get settingsProfileBleNick => 'Kort smeknamn (5 tecken)';

  @override
  String get settingsProfileKeyhash => 'Konto-ID';

  @override
  String get settingsProfileKeyhashCopied => 'Konto-ID kopierat till urklipp';

  @override
  String get settingsProfileChangePinButton => 'Ändra PIN-kod';

  @override
  String get settingsProfileResetIdentityButton => 'Återställ konto';

  @override
  String get settingsResetConfirmTitle => 'Återställa identitet?';

  @override
  String get settingsResetConfirmBody =>
      'Detta kommer permanent att radera alla meddelanden, kontakter och generera en ny identitet. Denna åtgärd kan inte ångras.';

  @override
  String get settingsResetConfirmCancel => 'Avbryt';

  @override
  String get settingsResetConfirmReset => 'Återställ';

  @override
  String get settingsChangePinTitle => 'Ändra PIN-kod';

  @override
  String get changePinVerifyTitle => 'Verifiera nuvarande PIN-kod';

  @override
  String get changePinVerifyPrompt =>
      'Ange din nuvarande PIN-kod för att fortsätta.';

  @override
  String get changePinSetTitle => 'Ange ny PIN-kod';

  @override
  String get settingsChangePinOldPin => 'Ange nuvarande PIN-kod';

  @override
  String get settingsChangePinNewPin => 'Ange ny PIN-kod (4–6 siffror)';

  @override
  String get settingsChangePinConfirmPin => 'Bekräfta ny PIN-kod';

  @override
  String get settingsChangePinEmptyFieldsError => 'Vänligen fyll i alla fält.';

  @override
  String get settingsChangePinLengthError =>
      'Den nya PIN-koden måste vara 4 till 6 siffror.';

  @override
  String get settingsChangePinMatchError =>
      'De nya PIN-koderna stämmer inte överens.';

  @override
  String get settingsChangePinUpdatedSnackBar => 'PIN-kod uppdaterad.';

  @override
  String get settingsChangePinIncorrectError =>
      'Nuvarande PIN-kod är felaktig.';

  @override
  String get settingsNetworkRoutingTitle => 'Nätverksinställningar';

  @override
  String get settingsNetworkDevRelayToggle => 'Använd lokal utvecklar-server';

  @override
  String get settingsNetworkDevRelayUrlLabel => 'Utvecklar-server URL';

  @override
  String get settingsNetworkDevRelayDescription =>
      'Att aktivera detta åsidosätter produktionsservern och dirigerar meddelanden genom en lokal server.';

  @override
  String get settingsNetworkActiveGateway => 'Nuvarande server-URL';

  @override
  String get settingsNetworkDiagnostics => 'Diagnostik';

  @override
  String get settingsNetworkDebugButton => 'Öppna debugkonsol';

  @override
  String get settingsDebugButtonsToggle => 'Debugknappar';

  @override
  String get settingsDebugButtonsDescription =>
      'Visa terminalkonsolknappen i chattlistan och inuti chattar.';

  @override
  String get settingsDebugTitle => 'Debugkonsol';

  @override
  String get settingsAlertsBackgroundNotifications => 'Bakgrundsaviseringar';

  @override
  String get settingsAlertsExplanation =>
      'Aviseringar kommer bara att visa \'Du har fått ett meddelande\'. Dina meddelanden förblir krypterade tills du låser upp appen.';

  @override
  String get settingsTextSizeLabel => 'Textstorlek i chatten';

  @override
  String get settingsTextSizePreview =>
      'Så här kommer dina meddelanden att se ut.';

  @override
  String get settingsLanguageLabel => 'Språk';

  @override
  String get settingsLanguageSystem => 'Systemspråk';

  @override
  String get settingsLanguageEnglish => 'English (Engelska)';

  @override
  String get settingsLanguageHungarian => 'Magyar (Ungerska)';

  @override
  String get settingsLanguagePolish => 'Polski (Polska)';

  @override
  String get settingsLanguageGerman => 'Deutsch (Tyska)';

  @override
  String get settingsLanguageFrench => 'Français (Franska)';

  @override
  String get settingsLanguageSwedish => 'Svenska';

  @override
  String get settingsLanguageChinese => '中文 (Kinesiska)';

  @override
  String get notificationModeOff => 'Av';

  @override
  String get notificationModeOffDesc =>
      'Inga bakgrundskontroller. Du ser bara meddelanden när du öppnar appen.';

  @override
  String get notificationModeLowPower => 'Låg ström';

  @override
  String get notificationModeLowPowerDesc =>
      'Söker regelbundet efter nya meddelanden i bakgrunden – snabbt direkt efter att du stängt appen, sedan mer sällan för att spara batteri. Ingen konstant anslutning, så aviseringar kan fördröjas.';

  @override
  String get notificationModeInstant => 'Direkt';

  @override
  String get notificationModeInstantDesc =>
      'Valfritt. Håller en totalsträckskrypterad anslutning öppen i bakgrunden för att synkronisera dina inkommande meddelanden i realtid, vilket visas med en pågående avisering. Wiltkey använder detta i stället för push-tjänster från Google eller Apple av integritetsskäl, så att det fungerar även utan Google Play-tjänster – på bekostnad av mer batteri.';

  @override
  String get notificationNewMessageBody => 'Du har fått ett meddelande';

  @override
  String get notificationEmergencyChatBody => 'Begäran om nödchatt';

  @override
  String get notificationSecureLinkActive => 'Synkroniserar säkra meddelanden';

  @override
  String get onboardingNotificationsTitle => 'Aviseringar';

  @override
  String get onboardingNotificationsExplanation =>
      'Wiltkey använder inte push-aviseringar från Google eller Apple – ingenting om dina meddelanden når deras servrar. Välj hur du vill bli aviserad. Du kan ändra detta när som helst i Inställningar.';

  @override
  String get onboardingFactPushTitle => 'INGA PUSH-SERVRAR';

  @override
  String get onboardingFactPushBody =>
      'Vanliga appar skickar dina aviseringar via Google eller Apple och avslöjar vem som skriver till dig och när. Wiltkey gör aldrig det – som standard sker inga kontroller i bakgrunden, och all avisering körs helt på din enhet.';

  @override
  String get notificationModeInstantDescFcm =>
      'Valfritt. Använder Googles push-tjänst som en enkel väckningssignal så att nya meddelanden kommer fram i realtid. Endast en innehållslös signal går via Google – aldrig dina meddelanden, som förblir totalsträckskrypterade på reläet tills din enhet hämtar dem. Snällare mot batteriet än en ständig anslutning.';

  @override
  String get onboardingNotificationsExplanationFcm =>
      'För aviseringar i realtid använder den här versionen Googles push-tjänst enbart som en väckningssignal – en innehållslös signal, aldrig dina meddelanden, som aldrig rör Googles servrar. Välj hur du vill bli aviserad; du kan ändra detta när som helst i Inställningar.';

  @override
  String get onboardingFactPushTitleFcm => 'INNEHÅLLSLÖS PUSH';

  @override
  String get onboardingFactPushBodyFcm =>
      'Vanliga appar skickar innehållet i dina aviseringar via Google och avslöjar vad som skickas och när. Den här versionen använder Google bara som en innehållslös väckningssignal – ingen meddelandedata, inga läsbara metadata – och allt förblir totalsträckskrypterat.';

  @override
  String get chatsLockedSubtitle =>
      'Låst · koppla personligen för att låsa upp';

  @override
  String chatsMemberCount(int count) {
    return '$count medlemmar';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: 'kontakter',
      one: 'kontakt',
    );
    return '$totalCount $_temp0 · $lockedCount låsta';
  }

  @override
  String get chatsTitle => 'Chattar';

  @override
  String get chatsPopupPair => 'Koppla en enhet';

  @override
  String get chatsPopupCreateGroup => 'Skapa grupp';

  @override
  String get chatsPopupJoinGroup => 'Gå med i grupp';

  @override
  String get chatsSearchHint => 'Sök';

  @override
  String get chatsEmptyNoMatches => 'Inga träffar';

  @override
  String get chatsEmptyNoChats => 'Inga chattar än';

  @override
  String get chatsEmptyPairInstruction =>
      'Koppla en enhet personligen för att börja chatta.';

  @override
  String get chatsEmptyPairButton => 'Koppla en enhet';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return 'JAG $remaining · PEER $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded =>
      'För många felaktiga försök. Enheten rensad.';

  @override
  String pinAccessDenied(int attempts) {
    return 'Felaktig PIN-kod. $attempts försök kvar.';
  }

  @override
  String get pinMinLengthError => 'PIN-koden måste vara minst 4 siffror.';

  @override
  String get pinPurgeConfirmTitle => 'Återställa enhet?';

  @override
  String get pinPurgeConfirmBody =>
      'Glömt PIN-koden? Detta kommer permanent att radera alla meddelanden och återställa ditt konto. Denna åtgärd kan inte ångras.';

  @override
  String get pinPurgeConfirmButton => 'Återställ enhet';

  @override
  String get pinLockedTitle => 'Låst';

  @override
  String get pinLockedSubtitle => 'Ange PIN-kod för att låsa upp';

  @override
  String get pinUnlockButton => 'Lås upp';

  @override
  String get pinUseFingerprintButton => 'Använd fingeravtryck';

  @override
  String get settingsBiometricToggle => 'Lås upp med fingeravtryck';

  @override
  String get settingsBiometricDescription =>
      'Lås upp med fingeravtryck istället för PIN. PIN krävs igen efter perioden nedan.';

  @override
  String get settingsBiometricIdleTitle => 'PIN-återgång';

  @override
  String get settingsBiometricIdleDescription =>
      'Kräv PIN igen efter så här lång tid utan upplåsning.';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours tim';
  }

  @override
  String get settingsBiometricIdleNever => 'Aldrig';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Det gick inte att aktivera fingeravtrycksupplåsning.';

  @override
  String get pinForgotButton => 'Glömt PIN-kod? Återställ enhet';

  @override
  String get pairTitle => 'Koppla enheter';

  @override
  String get pairRescanTooltip => 'Uppdatera sökning';

  @override
  String get pairBluetoothOffWarning =>
      'Bluetooth är av. Parkoppling behöver Bluetooth för att hitta enheter i närheten — slå på det för att fortsätta.';

  @override
  String get pairBluetoothTurnOnButton => 'Slå på Bluetooth';

  @override
  String get pairDoNotExitWarning =>
      'Håll WiltKey öppen — byt inte app och avsluta inte förrän kopplingen är klar på BÅDA enheterna.';

  @override
  String get pairRequestDialogTitle => 'Kopplingsförfrågan';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName vill koppla.\n\nChattstorlek: $size.\n\nAcceptera säker koppling?';
  }

  @override
  String get pairRequestReject => 'Neka';

  @override
  String get pairRequestAccept => 'Acceptera';

  @override
  String get pairPingStatusPinging => 'Testar...';

  @override
  String pairPingStatusLatency(String latency) {
    return 'Latens: ${latency}ms';
  }

  @override
  String get pairPingStatusFailed => 'Misslyckades';

  @override
  String get pairPingStatusTest => 'Testa anslutning';

  @override
  String get pairDeviceNameLabel => 'Ditt enhetsnamn';

  @override
  String get pairDeviceNameHint => 'Ange namn';

  @override
  String get pairDiscoverableTitle => 'Gör enhet sökbar';

  @override
  String get pairDiscoverableSubtitle => 'Låt vänner i närheten hitta dig';

  @override
  String get pairNearbyDevicesTitle => 'Enheter in der Nähe';

  @override
  String get pairNearbyDevicesInstruction =>
      'Håll enheterna bredvid varandra för att ansluta.';

  @override
  String get pairDirectSyncFormRelayLabel => 'Server URL';

  @override
  String get pairDirectSyncFormSyncButton => 'Anslut enheter';

  @override
  String get pairSyncingConnecting => 'Ansluter...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return 'Genererar säker nyckel ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return 'Nyckel: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return '$percent% klart';
  }

  @override
  String get pairSuccessConnectionSecured => 'Ansluten!';

  @override
  String pairSuccessGroupBody(String groupName) {
    return 'Gick med i gruppen \"$groupName\". Säkra nycklar har genererats lokalt på din enhet.';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return 'Säkra nycklar har utbytts och genererats på din enhet. Ansluten till $title med $label chattkapacitet.';
  }

  @override
  String get pairSuccessReturnButton => 'Gå till chattar';

  @override
  String get chatDetailsTitle => 'Chattdetaljer';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return 'Namn: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => 'Officiellt relä';

  @override
  String get chatDetailsPrivateNode => 'Privat nod';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return 'JAG $remaining · PEER $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => 'Profil';

  @override
  String get chatDetailsProfileExplanation =>
      'Avatarer och smeknamn synkroniseras automatiskt när du ansluter. Du kan synkronisera din manuellt nu om det behövs.';

  @override
  String get chatDetailsProfileSyncButton => 'Synkronisera profil';

  @override
  String get chatDetailsProfileSnackBar => 'Profil skickad.';

  @override
  String get chatDetailsSectionPermissions => 'Rättigheter';

  @override
  String get chatDetailsPermissionsPhotos => 'Tillåt bilddelning';

  @override
  String get chatDetailsPermissionsEmojis => 'Egna emojis';

  @override
  String get chatDetailsPermissionsEmojisAvailable => 'Tillgänglig';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize => 'Kräver större chatt';

  @override
  String get chatDetailsSectionMetadata => 'Metadatautrymme';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return 'Den här chatten tilldelar $budget av det totala utrymmet ($max) för inställningar, profilbilder och egna emojis.';
  }

  @override
  String get chatDetailsSectionLanes => 'Säkra kanaler';

  @override
  String get chatDetailsLanesMySend => 'Min sändkapacitet';

  @override
  String get chatDetailsLanesPeerSend => 'Motpartens sändkapacitet';

  @override
  String get chatDetailsLanesBorrowed => 'Lånat utrymme';

  @override
  String get chatDetailsLanesCapacityLeft => 'Min återstående kapacitet';

  @override
  String get chatDetailsLanesExplanation =>
      'Om din kapacitet börjar ta slut kan du låna oanvänt utrymme från din motpart. Detta kan också ske automatiskt så att du kan fortsätta chatta.';

  @override
  String get chatDetailsLanesBorrowButton => 'Begär chattutrymme';

  @override
  String get chatDetailsLanesSnackBar => 'Begäran skickad till motparten.';

  @override
  String get chatDetailsSectionEmojis => 'Egna emojis';

  @override
  String get chatDetailsEmojisExplanation =>
      'Använd dessa egna emojis i dina meddelanden med formatet :namn:.';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      'Den här chattkapaciteten är för liten för egna emojis. Anslut med större kapacitet för att aktivera dem.';

  @override
  String get chatDetailsEmojisCreate => 'Skapa';

  @override
  String get chatDetailsSectionDestructive => 'Farliga inställningar';

  @override
  String get chatDetailsNukeButton => 'Spräng chatten (båda sidor)';

  @override
  String get chatDetailsDeleteEmojiTitle => 'Radera emoji?';

  @override
  String get chatDetailsDeleteEmojiBody =>
      'Den här egna emojin kommer att raderas permanent. Vill du fortsätta?';

  @override
  String get chatDetailsDeleteEmojiDelete => 'Radera';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return 'Lade till :$name:';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return 'Bilden är för stor ($cost) för återstående utrymme ($charge).';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar =>
      'Bilden är för stor för att skickas.';

  @override
  String get chatImageNeedsPlusSnackBar =>
      'Bilden är för stor för gratisnivån — WiltKey Plus höjer gränsen till 50 MB.';

  @override
  String get chatTapForDetails => 'Tryck för detaljer';

  @override
  String get chatSyncTooltip => 'Synka meddelanden';

  @override
  String get chatStickerHint =>
      'Håll in en emoji för att skicka ett klistermärke';

  @override
  String get chatSyncStarted => 'Letar efter missade meddelanden…';

  @override
  String get chatSyncOffline => 'Kan inte synka offline.';

  @override
  String get chatEncrypting => 'Krypterar…';

  @override
  String get chatScreenshotDetected => 'Skärmdump upptäckt';

  @override
  String get chatScreenshotExplanation =>
      'En skärmdump upptäcktes. För din säkerhet kan du radera dina nycklar och meddelanden nu.';

  @override
  String get chatScreenshotWipeButton => 'Radera meddelanden und nycklar';

  @override
  String get chatScreenshotIgnoreButton => 'Ignorera varning';

  @override
  String get chatSimulateScreenshotButton => 'Simulera skärmdump';

  @override
  String chatCostIndicator(String cost) {
    return 'Kostnad: $cost';
  }

  @override
  String get groupCreateTitle => 'Skapa grupp';

  @override
  String get groupCreatePixelArtIcon => 'Gruppikon';

  @override
  String get groupCreateRandomIcon => 'Generera';

  @override
  String get groupCreateClearIcon => 'Rensa';

  @override
  String get groupCreateNameLabel => 'Gruppnamn';

  @override
  String get groupCreateNameEmptyValidator => 'Ange ett gruppnamn';

  @override
  String get groupCreateNameLengthValidator => 'Maximalt 24 tecken';

  @override
  String get groupCreatePoliciesSection => 'Riktlinjer för gruppen';

  @override
  String get groupCreatePolicyPadSize => 'Gruppens chattstorlek';

  @override
  String get groupCreatePolicyLaneSize => 'Kapacitet per medlem';

  @override
  String get groupCreatePolicyMaxMembersLabel => 'Max antal medlemmar';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return 'Max $count medlemmar';
  }

  @override
  String get groupCreatePolicyAllowImages => 'Tillåt bilddelning';

  @override
  String get groupCreatePolicyAllowImagesSub =>
      'Tillåt medlemmar att skicka bilder';

  @override
  String get groupCreatePolicyPayloadSize => 'Maximal meddelandestorlek';

  @override
  String get groupCreateButton => 'Skapa grupp';

  @override
  String get groupCreateProgressTitle => 'Skapar grupp…';

  @override
  String get groupCreateProgressSubtitle =>
      'Förbereder gruppens krypteringsförråd och medlemmarnas kapacitet. Det kan ta en stund – ha tålamod.';

  @override
  String groupCreateFailedSnackBar(String error) {
    return 'Kunde inte skapa grupp: $error';
  }

  @override
  String get pairSyncingAwaitingApproval =>
      'Väntar på att vännen ska godkänna...';

  @override
  String get pairSyncingCoordinating => 'Konfigurerar nyckelutbyte...';

  @override
  String get pairSyncingStep1 => 'Upprättar säker anslutning...';

  @override
  String get pairSyncingStep2 => 'Genererar säkerhetsseed...';

  @override
  String pairSyncingStep3(String seed) {
    return 'Utbyter publika nycklar... $seed';
  }

  @override
  String get pairSyncingStep4 => 'Genererar säkra chattnycklar...';

  @override
  String get pairSyncingStep5 => 'Verifierar nyckelintegritet...';

  @override
  String get pairSyncingStep6 => 'Säker konfiguration slutförd.';

  @override
  String chatRemainingLabel(String bytes) {
    return '$bytes återstår';
  }

  @override
  String get chatLockedLabel => 'Låst · koppla personligen för att fortsätta';

  @override
  String get chatMessageHint => 'Meddelande';

  @override
  String get chatVoiceComingSoon => 'Röstmeddelanden kommer snart.';

  @override
  String get chatVoiceHoldHint =>
      'Håll in för att spela in ett röstmeddelande.';

  @override
  String get chatVoiceReleaseCancel => 'Släpp för att avbryta';

  @override
  String get chatVoiceSlideToCancel => 'Dra för att avbryta';

  @override
  String get chatVoiceSlideToLock => 'Dra uppåt för att låsa';

  @override
  String get chatVoiceCancel => 'Avbryt inspelning';

  @override
  String get chatVoiceSend => 'Skicka röstmeddelande';

  @override
  String get chatVoicePermissionDenied =>
      'Mikrofonbehörighet krävs för att spela in röstmeddelanden.';

  @override
  String get chatVoiceQualityLofi => 'Lo-fi';

  @override
  String get chatVoiceQualityVoice => 'Röst';

  @override
  String get chatVoiceQualityClear => 'Klar';

  @override
  String get chatVoiceUnavailable => 'Röstmeddelande otillgängligt';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return 'Röstmeddelandet är för stort ($cost) för återstående utrymme ($charge).';
  }

  @override
  String get chatDetailsDeleteConfirmTitle => 'Radera chatt?';

  @override
  String get chatDetailsDeleteConfirmBody =>
      'Detta kommer permanent att radera alla meddelanden och krypteringsnycklar för den här kontakten. Detta kan inte ångras.';

  @override
  String get chatDetailsDeleteConfirmButton => 'Radera chatt';

  @override
  String get chatsActionArchive => 'Arkivera';

  @override
  String get chatsActionNuke => 'Radera chatt & nycklar';

  @override
  String get chatsActionDelete => 'Radera';

  @override
  String get chatsArchivedBadge => 'Arkiverad';

  @override
  String get chatsArchivedSubtitle => 'Arkiverad · skrivskyddad';

  @override
  String get chatsArchiveConfirmTitle => 'Arkivera chatt?';

  @override
  String get chatsArchiveConfirmBody =>
      'Detta frigör utrymme genom att radera chattens engångsnyckel. Dina meddelanden förblir läsbara, men chatten blir skrivskyddad — du kan inte längre skicka eller ta emot i den.';

  @override
  String get chatsArchiveConfirmButton => 'Arkivera';

  @override
  String get chatsActionPin => 'Fäst';

  @override
  String get chatsActionUnpin => 'Lossa';

  @override
  String get chatsFilterAll => 'Alla';

  @override
  String get chatsFilterDirect => 'Direkt';

  @override
  String get chatsFilterGroups => 'Grupper';

  @override
  String get chatsSectionArchived => 'Arkiverade';

  @override
  String groupTapForDetails(String hostName) {
    return 'Tryck för detaljer · Värd: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    return '$count lediga kanaler tillgängliga';
  }

  @override
  String get groupHost => 'Värd';

  @override
  String get groupMember => 'Medlem';

  @override
  String get groupDepleted => 'Slut';

  @override
  String get groupNotYetMet => 'Inte träffats än';

  @override
  String get groupRechargeButton => 'Ladda om grupp';

  @override
  String get groupRechargeTitle => 'Ladda om grupp?';

  @override
  String get groupRechargeBody =>
      'Laddar om chatten med en ny nyckel. Historiken finns kvar, men alla måste träffa dig igen för att gå med på nytt.';

  @override
  String get groupRechargeConfirm => 'Ladda om';

  @override
  String get groupRechargeDone =>
      'Gruppen är omladdad — träffa medlemmarna igen för att lägga till dem.';

  @override
  String get groupRechargeNeededComposer =>
      'Värden laddade om gruppen — träffa dem igen för att gå med på nytt';

  @override
  String get groupTimeWiltToggle => 'Time Wilt-grupp';

  @override
  String get groupTimeWiltToggleSub =>
      'Begränsad tid, obegränsad budget. Gruppen blir skrivskyddad när timern tar slut; träffa värden igen för att förnya den.';

  @override
  String get groupTimeWiltMembersLabel => 'Max antal medlemmar';

  @override
  String get groupTimeWiltMembersUpsell =>
      'Lås upp upp till 100 medlemmar med Plus';

  @override
  String get groupTimeWiltHostInfinite => 'Värd · ∞';

  @override
  String get groupTimeWiltRenewComposer =>
      'Utgången — träffa värden igen för att förnya din åtkomst';

  @override
  String get groupTimeWiltHostAllWilted =>
      'Alla medlemmar har gått ut — träffa någon för att återuppliva gruppen';

  @override
  String get groupNukeProposeButton => 'Föreslå radering för alla';

  @override
  String get groupNukeProposeTitle => 'Radera denna grupp för alla?';

  @override
  String get groupNukeProposeBody =>
      'Startar en omröstning bland medlemmarna. Om majoriteten godkänner raderas gruppen och dess historik på varje enhet. Kan inte ångras.';

  @override
  String get groupNukeProposeConfirm => 'Föreslå';

  @override
  String get groupNukeVoteTitle => 'Radera grupp?';

  @override
  String get groupNukeVoteBody =>
      'En medlem föreslog att radera denna grupp för alla. Om majoriteten godkänner rensas den på varje enhet.';

  @override
  String get groupNukeVoteAllow => 'Godkänn';

  @override
  String get groupNukeVoteDeny => 'Behåll';

  @override
  String get groupNukeVotePending => 'Väntar på medlemmarnas röster…';

  @override
  String get groupNukeVotePassed => 'Gruppen raderades genom majoritetsbeslut.';

  @override
  String get groupNukeVoteFailed =>
      'Förslaget att radera gruppen röstades ned.';

  @override
  String get groupNukeVoteSent => 'Förslag skickat — väntar på omröstning.';

  @override
  String get activityTitle => 'Aktivitet';

  @override
  String get activityEmpty =>
      'Ingen aktivitet än. Händelser som raderade chattar visas här.';

  @override
  String get activityClear => 'Rensa';

  @override
  String get activityClearConfirmTitle => 'Rensa aktivitet?';

  @override
  String get activityClearConfirmBody =>
      'Tar bort alla aktivitetshändelser från denna enhet. Kan inte ångras.';

  @override
  String get eventNukeReceivedTitle => 'Chatt raderad';

  @override
  String get eventNukeReceivedBody => 'En säker chatt raderades.';

  @override
  String get eventGroupNukedTitle => 'Grupp raderad';

  @override
  String get eventGroupNukedBody => 'En säker grupp raderades.';

  @override
  String eventContactRequestTitle(String name) {
    return '$name skickade en kontaktförfrågan till dig';
  }

  @override
  String get eventContactRequestBody =>
      'Tryck för att acceptera eller avböja i chatten';

  @override
  String eventContactRemovedTitle(String name) {
    return '$name tog bort dig';
  }

  @override
  String get eventContactRemovedBody => 'De tog bort dig från sina kontakter';

  @override
  String groupSyncingFromMember(String name) {
    return 'Synkroniserar detaljer och meddelanden från $name...';
  }

  @override
  String get groupInviteMember => 'Bjud in medlem';

  @override
  String get groupLeaveGroup => 'Lämna grupp';

  @override
  String get groupRemoveMember => 'Ta bort medlem';

  @override
  String get groupRemoveMemberTitle => 'Ta bort medlem?';

  @override
  String groupRemoveMemberBody(String name) {
    return 'Ta bort $name från gruppen? Detta raderar deras parvisa nyckel.';
  }

  @override
  String get groupLeaveGroupTitle => 'Lämna grupp?';

  @override
  String get groupLeaveGroupBody =>
      'Lämna den här gruppen? Detta raderar lokala parvisa nycklar och loggar.';

  @override
  String get groupSyncStepText => 'Synka';

  @override
  String get groupDecryptingImage => 'Avkrypterar bild...';

  @override
  String get chatFileTapToDownload => 'Tryck för att ladda ner';

  @override
  String get chatFileDownloadFailed => 'Tryck för att försöka igen';

  @override
  String get chatFileKindPhoto => 'Foto';

  @override
  String get chatFileKindVoice => 'Röstmeddelande';

  @override
  String get chatFileKindFile => 'Fil';

  @override
  String get groupTapToRevealImage => 'Tryck för att visa bild';

  @override
  String groupImageSize(String size) {
    return 'Storlek: $size';
  }

  @override
  String get groupImageFailedToLoad => 'Bilden kunde inte laddas';

  @override
  String get groupScreenshotWipeButton => 'Radera alla nycklar nu';

  @override
  String get groupRefillGranted => 'Kanalpåfyllning beviljad.';

  @override
  String groupRefillFailed(String error) {
    return 'Misslyckades att bevilja påfyllning: $error';
  }

  @override
  String get groupLaneDepleted => 'Kanalen är tom';

  @override
  String get groupLaneDepletedExplanation =>
      'Begär påfyllning av bytes från gruppens värd.';

  @override
  String get groupRefillRequestSent =>
      'Förfrågan om påfyllning skickad till värden.';

  @override
  String get groupRequestRefill => 'Begär påfyllning';

  @override
  String groupExceedsSizeLimit(int size) {
    return 'Överskrider storleksgräns ($size B)';
  }

  @override
  String get groupDetailsTitle => 'Gruppdetaljer';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return 'Delat utrymme · Värd: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => 'Grupppolicy';

  @override
  String get groupDetailsSavePoliciesButton => 'Spara policy';

  @override
  String get groupDetailsSavePoliciesSnackBar => 'Gruppens policy sparad.';

  @override
  String get groupDetailsSectionEmojis => 'Egna emojis';

  @override
  String get groupDetailsSectionMetadata => 'Metadatautrymme';

  @override
  String get groupDetailsMetadataExplanation =>
      'Kanal 0 i det delade utrymmet reserverar 1 MB för gruppmetadata – gruppikon, medlemslista och egna emojis lagras här.';

  @override
  String get groupDetailsSectionSync => 'Gruppsynk';

  @override
  String get groupDetailsSyncExplanation =>
      'Begär senaste gruppdetaljer, policyer och medlemslistor från värden.';

  @override
  String get groupDetailsSyncButton => 'Synkronisera detaljer';

  @override
  String get groupDetailsSyncSnackBar =>
      'Begärde gruppuppdatering från värden.';

  @override
  String get groupDetailsSectionDestructive => 'Farliga inställningar';

  @override
  String get groupDetailsLeaveButton => 'Lämna grupp';

  @override
  String get groupDetailsNukeButton => 'Radera grupp';

  @override
  String get groupDetailsDeleteConfirmTitle => 'Radera grupp?';

  @override
  String get groupDetailsDeleteConfirmBody =>
      'Detta kommer permanent att radera gruppen och rensa all chatthistorik och nycklar för alla medlemmar. Denna åtgärd kan inte ångras.';

  @override
  String get groupDetailsDeleteConfirmButton => 'Radera grupp';

  @override
  String get chatImageCompressionTitle => 'Komprimera bild';

  @override
  String chatImageCompressionOriginal(String size) {
    return 'Original: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return 'Uppskattad: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return 'Uppskattad: $size (sparar ~$saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return 'Kostnad: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation =>
      'Konverteras till WebP, max 2000px.';

  @override
  String get chatImageCompressionLowSize => 'Liten';

  @override
  String get chatImageCompressionHighSize => 'Stor';

  @override
  String get chatImageCompressionMaxQuality => 'Högsta kvalitet';

  @override
  String get chatImageCompressionUncompressed => 'Okomprimerad';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return '$percent% kvalitet';
  }

  @override
  String get chatImageCompressionSendHidden =>
      'Skicka dold (tryck för att visa)';

  @override
  String get chatImageCompressionSendButton => 'Skicka';

  @override
  String get groupGrantRefill => 'Bevilja påfyllning';

  @override
  String get groupLaneLocked => 'Låst · inga bytes kvar';

  @override
  String get groupMembersTitle => 'Gruppmedlemmar';

  @override
  String get groupMembersExplanation =>
      'Alla medlemmar delar på en kanaldelad chattstorlek. Meddelanden skickas via servern.';

  @override
  String get pairChatSize => 'Chattstorlek';

  @override
  String get chatSystemConnected => 'Ansluten. Chattsession säker.';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return 'Gick med i gruppen \"$groupName\". Anslutningar säkra.';
  }

  @override
  String get themeCyberpunkName => 'Neon Grid';

  @override
  String get themeCyberpunkDesc =>
      'Originalet. Obsidian, lysande cyan, terminalstil.';

  @override
  String get themeGardenName => 'Dusk Garden';

  @override
  String get themeGardenDesc =>
      'Mjuka jordtoner, varmt linne, blomblad för din budget.';

  @override
  String get themePaperinkName => 'Paper & Ink';

  @override
  String get themePaperinkDesc =>
      'Varmt washi-papper, sumi-bläck i utspädningar, cinnoberröd hanko-stämpel.';

  @override
  String get themePickerPlayExclusive =>
      'Det här temat är exklusivt för Play Store-versionen av WiltKey.';

  @override
  String get themePreviewTooltip => 'Förhandsvisning';

  @override
  String get themePreviewSectionDashboard => 'Chattlista';

  @override
  String get themePreviewSectionChat => 'Konversation';

  @override
  String get themePreviewSectionEffects => 'Specialeffekter';

  @override
  String get themePreviewPlayUnlock => 'Spela upplåsningsanimationen';

  @override
  String get themePreviewPlayNuke => 'Spela självförstörelseanimationen';

  @override
  String get themePreviewApply => 'Använd det här temat';

  @override
  String get themePreviewGetInShop => 'Skaffa i butiken';

  @override
  String get themePreviewMsgThem1 =>
      'Bara 800 byte kvar på vårt pad, ska vi ses?';

  @override
  String get themePreviewMsgMe =>
      'Absolut! Filmkväll hos mig? Vi laddar upp samtidigt';

  @override
  String get themePreviewMsgThem2 => 'deal, jag tar med snacks 🍿';

  @override
  String get themePreviewRowPhoto => 'Foto från klättergymmet 🧗';

  @override
  String get themePreviewRowLost => 'Padet är slut — träffas för att ladda om';

  @override
  String get themePreviewSectionProfile => 'Profilbakgrund';

  @override
  String get themePreviewFullscreenProfile =>
      'Förhandsvisning av profil i helskärm';

  @override
  String get linkWarningTitle => 'Extern länkvarning';

  @override
  String get linkWarningBody =>
      'Du är på väg att öppna en extern länk i webbläsaren. Detta ansluter till målservern och avslöjar din IP-adress.';

  @override
  String get linkWarningOpen => 'Öppna i webbläsare';

  @override
  String get linkWarningCopy => 'Kopiera länk';

  @override
  String get linkWarningCopied => 'Länk kopierad till urklipp';

  @override
  String get chatActionEdit => 'Redigera';

  @override
  String get chatActionDelete => 'Ta bort';

  @override
  String get chatEditingBanner => 'Redigerar meddelande';

  @override
  String get chatCancelEdit => 'Avbryt redigering';

  @override
  String get chatDeleteTitle => 'Ta bort meddelande';

  @override
  String get chatDeleteBody =>
      'Är du säker på att du vill ta bort det här meddelandet för alla?';

  @override
  String get chatDeleteConfirm => 'Ta bort';

  @override
  String get chatMessageDeleted => '[Meddelande borttaget]';

  @override
  String get chatEditedTag => 'redigerat';

  @override
  String get accessibilityWarningTitle => 'Tillgänglighetstjänst aktiv';

  @override
  String accessibilityWarningBody(String names) {
    return 'En tillgänglighetstjänst som kan läsa innehåll på skärmen är aktiv: $names. Det är normalt för verktyg som skärmläsare eller lösenordshanterare. Om du inte har aktiverat någon, granska dina tillgänglighetsinställningar.';
  }

  @override
  String get accessibilityWarningDismiss => 'Stäng';

  @override
  String get accessibilityWarningOpenSettings => 'Granska inställningar';

  @override
  String get chatImageCompressionAllowDownload =>
      'Tillåt att spara i galleriet';

  @override
  String get chatImageCompressionWilting =>
      'Vissnande bild (försvinner efter öppning)';

  @override
  String get chatImageDownload => 'Ladda ner';

  @override
  String get chatImageSaveAs => 'Spara som';

  @override
  String get chatImageSavedToGallery => 'Sparad i galleriet';

  @override
  String get chatImageSaveFailed => 'Det gick inte att spara bilden';

  @override
  String get chatImageSourceTitle => 'Skicka ett foto';

  @override
  String get chatImageSourceCamera => 'Ta foto';

  @override
  String get chatImageSourceGallery => 'Välj från galleriet';

  @override
  String get screenshotRequestTooltip => 'Begär skärmbild';

  @override
  String get screenshotWaiting => 'Väntar på godkännande…';

  @override
  String get screenshotConsentTitle => 'Begäran om skärmbild';

  @override
  String screenshotConsentBody(String name) {
    return '$name vill spara en skärmbild av den här chatten. Tillåta?';
  }

  @override
  String get screenshotDenied => 'Begäran om skärmbild avvisades.';

  @override
  String get screenshotCaptureFailed => 'Det gick inte att ta skärmbilden.';

  @override
  String get screenshotWatermark => 'WiltKey — Skärmbild med samtycke';

  @override
  String screenshotRequestInline(String name) {
    return '$name begärde en skärmbild';
  }

  @override
  String get screenshotRequestAllowed => 'Du tillät skärmbilden';

  @override
  String get screenshotRequestDeclined => 'Du nekade skärmbilden';

  @override
  String get screenshotRequestExpired => 'Skärmbildsbegäran har löpt ut';

  @override
  String get wiltingTapToReveal => 'Tryck för att se det vissnande meddelandet';

  @override
  String get wiltingMessageTag => 'Vissnande meddelande';

  @override
  String get wiltedMessage => 'Vissnat meddelande';

  @override
  String get wiltingSheetTitle => 'Vissnande meddelande';

  @override
  String get wiltingSheetBody =>
      'Meddelandet försvinner så här många sekunder efter att mottagaren öppnat det.';

  @override
  String get wiltingSheetSend => 'Skicka vissnande meddelande';

  @override
  String get wiltingHoldToSendHint =>
      'Håll in för att skicka ett vissnande meddelande';

  @override
  String get replyYou => 'Du';

  @override
  String get replySomeone => 'Någon';

  @override
  String get replyPreviewImage => '📷 Foto';

  @override
  String get replyPreviewVoice => '🎤 Röstmeddelande';

  @override
  String get replyPreviewMessage => 'Meddelande';

  @override
  String get replyUnavailable => 'Originalmeddelandet är inte tillgängligt';

  @override
  String get shopEntryTitle => 'Butik & WiltKey Plus';

  @override
  String get shopEntrySubtitle => 'Teman, upplåsningar & Plus';

  @override
  String get supportEntryTitle => 'Stöd projektet';

  @override
  String get supportEntrySubtitle => 'Hjälp till att hålla WiltKey igång';

  @override
  String get shopTitle => 'Butik';

  @override
  String get supportTitle => 'Stöd WiltKey';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => 'Upplåsningar';

  @override
  String get shopPlusTagline =>
      'Längre offline-lagring av meddelanden och större filöverföringar.';

  @override
  String get shopEmptyTitle => 'Inget här ännu';

  @override
  String get shopEmptyBody => 'Produkter är på väg — kom tillbaka snart.';

  @override
  String get shopRestoreButton => 'Återställ köp';

  @override
  String get shopRestoredSnack => 'Köp återställda';

  @override
  String get shopBuyButton => 'Köp';

  @override
  String get shopOwnedLabel => 'Ägs';

  @override
  String get shopActiveLabel => 'Aktiv';

  @override
  String get shopManageNote => 'Hantera i Google Play';

  @override
  String get shopPurchasePendingSnack => 'Köp väntar…';

  @override
  String get shopPurchaseFailedSnack => 'Köpet kunde inte slutföras';

  @override
  String get supportIntro =>
      'WiltKey är gratis och öppen källkod, och den här versionen låser upp alla kosmetiska tillägg gratis. Om du vill stödja utvecklingen och den officiella relayen, besök sidan nedan.';

  @override
  String get supportOpenButton => 'Öppna stödsidan';

  @override
  String get supportFreeNote =>
      'Alla kosmetiska tillägg är upplåsta i den här versionen.';

  @override
  String get shopTabPalettes => 'Paletter';

  @override
  String get shopTabThemes => 'Teman';

  @override
  String get shopTabBorders => 'Ramar';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'Promo';

  @override
  String get shopPalettesIntro =>
      'Extra färger för att rita din avatar och dina gruppikoner. Mottagen konst visas alltid fullständigt — ett paket låser bara upp att du själv ritar med färgerna.';

  @override
  String shopPaletteColorCount(int count) {
    return '$count extra färger';
  }

  @override
  String get shopThemesEmptyTitle => 'Inga teman ännu';

  @override
  String get shopThemesEmptyBody =>
      'Premiumteman är på väg — de tre inbyggda temana är gratis för alltid.';

  @override
  String get shopBordersSoonTitle => 'Ramar kommer snart';

  @override
  String get shopBordersSoonBody =>
      'Dekorativa ramar till din avatar som alla du chattar med kan se. Under arbete.';

  @override
  String get shopPlusBenefitsSection => 'Det här får du';

  @override
  String get shopPlusBenefitHold =>
      'Dina meddelanden väntar 72 timmar på relayen i stället för 24 medan du är offline.';

  @override
  String get shopPlusBenefitFiles =>
      'Skicka stora filer – upp till 50 MB per meddelande, bortom gränsen på 5 MB gratis.';

  @override
  String get shopPlusBenefitPads =>
      'Skapa större pads – upp till 200 MB för en chatt och 500 MB för en grupp.';

  @override
  String get shopPlusBenefitTimeWiltGroups =>
      'Skapa större Time Wilt-grupper — upp till 100 medlemmar istället för 20.';

  @override
  String get shopPlusBenefitSupport =>
      'Du håller relayen igång och WiltKey oberoende.';

  @override
  String get shopSubscribeButton => 'Prenumerera';

  @override
  String get shopPriceUnavailable => 'Inte tillgänglig';

  @override
  String get shopPromoIntro =>
      'Har du en kampanjkod? Ange den nedan så tillämpar Google Play den på ditt konto.';

  @override
  String get shopPromoHint => 'KAMPANJKOD';

  @override
  String get shopPromoRedeemButton => 'Lös in i Google Play';

  @override
  String get shopPromoNote =>
      'Koder löses in i Play Butik. När koden tillämpats visas din upplåsning här automatiskt.';

  @override
  String pairLargerPadsUpsell(String max) {
    return 'Större pads med Plus — upp till $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return 'Inte tillräckligt med ledigt utrymme — den här chatten kräver $needed och du har $free.';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return 'Genererar nyckelström… $written / $total';
  }

  @override
  String get pairKeepAppOpen =>
      'Håll appen öppen — den säkra padden skapas fortfarande.';

  @override
  String groupLargerPadsUpsell(String max) {
    return 'Större grupp-pads med Plus — upp till $max';
  }

  @override
  String get settingsBorderSection => 'Avatarram';

  @override
  String get shopBordersIntro =>
      'Ramar och tillbehör till din avatar. Alla du chattar med ser din ram — en låst hindrar bara dig från att använda den, aldrig hur den visas.';

  @override
  String get shopBorderSubtitle => 'Avatarram';

  @override
  String get shopFreeLabel => 'Gratis';

  @override
  String get notificationModePrivate => 'Privat';

  @override
  String get notificationModePrivateDesc =>
      'Kontrollerar regelbundet nya meddelanden i bakgrunden utan att använda Googles push-tjänst. Aviseringar kan fördröjas, men inga signaler går via en tredje part.';

  @override
  String get connectSectionOneOnOne => 'En-mot-en';

  @override
  String get connectSectionGroups => 'Grupper';

  @override
  String get connectByteBudgetTitle => 'Bajtebudget';

  @override
  String get connectByteBudgetDesc =>
      'Obegränsad tid, begränsad utrymmesbudget. Bäst för vänner, familj och extra säkra chattar.';

  @override
  String get connectTimeWiltTitle => 'Time Wilt';

  @override
  String get connectTimeWiltDesc =>
      'Begränsad tid, obegränsat utrymme. Perfekt för nya bekantskaper, dejter eller spontana träffar.';

  @override
  String get connectRemotePairTitle => 'Fjärrparkoppling (test)';

  @override
  String get connectRemotePairDesc =>
      'Testläge: parkoppla med en testare via servern med PIN och identitetshash.';

  @override
  String get connectByteBudgetGroupTitle => 'Bajtebudget-grupp';

  @override
  String get connectByteBudgetGroupDesc =>
      'Obegränsad tid, begränsad budget. En grupp du bygger genom att bjuda in medlemmar personligen.';

  @override
  String get connectTimeWiltGroupTitle => 'Time Wilt-grupp';

  @override
  String get connectTimeWiltGroupDesc =>
      'Begränsad tid, obegränsat utrymme. En avslappnad grupp där meddelanden löper ut efter hand.';

  @override
  String get connectJoinGroupTitle => 'Gå med i en grupp';

  @override
  String get connectJoinGroupDesc =>
      'Någon i närheten bjöds in dig — sök efter deras gruppsignal.';

  @override
  String get connectJoinRemoteGroupTitle => 'Gå med i fjärrgrupp (test)';

  @override
  String get connectJoinRemoteGroupDesc =>
      'Testläge: gå med i en testares grupp via servern.';

  @override
  String get connectBadgeSoon => 'SNART';

  @override
  String get timeWiltLifetimeLabel => 'Chattens livslängd';

  @override
  String get timeWiltPlusHint => 'Lås upp upp till 6 månader med Plus';

  @override
  String get timeWiltExplanation =>
      'Chatten blir skrivelåst när timern går ut.';

  @override
  String timeWiltPairRequestDialogBody(String peerName, String lifetime) {
    return 'Acceptera en Time Wilt-chatt från $peerName? Den blir skrivelåst om $lifetime.';
  }

  @override
  String timeWiltLifetimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar',
      one: '1 dag',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timmar',
      one: '1 timme',
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
      other: '$count månader',
      one: '1 månad',
    );
    return '$_temp0';
  }

  @override
  String get timeWiltLifetimeMoments => 'några ögonblick';

  @override
  String get navContacts => 'Kontakter';

  @override
  String get contactsTitle => 'Kontakter';

  @override
  String get contactsSectionFriends => 'Vänner';

  @override
  String get contactsEmptyTitle => 'Inga kontakter än';

  @override
  String get contactsEmptyBody =>
      'Lägg till någon från en befintlig chatt för att se dem här.';

  @override
  String get contactsOwnProfile => 'Din profil';

  @override
  String get contactsOwnProfileHint =>
      'Tryck för att ställa in status eller tidsbegränsad händelse';

  @override
  String contactRequestSent(String name) {
    return 'Kontaktförfrågan skickad till $name';
  }

  @override
  String contactRequestReceived(String name) {
    return '$name vill lägga till dig som kontakt';
  }

  @override
  String get contactRequestApproved => 'Kontaktförfrågan godkänd';

  @override
  String get contactRequestDeclined => 'Kontaktförfrågan avvisad';

  @override
  String get contactRequestApprove => 'Godkänn';

  @override
  String get contactRequestDeny => 'Avvisa';

  @override
  String get contactAddTitle => 'Add contact';

  @override
  String contactAddBody(String name) {
    return 'Add $name to your contacts?';
  }

  @override
  String get contactAddConfirm => 'Add contact';

  @override
  String get contactAddAlready => 'Already in your contacts';

  @override
  String get contactAddSent => 'Contact request sent';

  @override
  String get contactProfileOpenChat => 'Öppna chatt';

  @override
  String get contactProfileRemove => 'Ta bort kontakt';

  @override
  String get contactProfileBlock => 'Blockera användare';

  @override
  String get contactProfileStatusPlaceholder => 'Ingen status än';

  @override
  String get contactProfileEmergencyChat => 'Nödchatt';

  @override
  String get contactPin => 'Fäst högst upp';

  @override
  String get contactUnpin => 'Lossa';

  @override
  String get contactUnblock => 'Avblockera';

  @override
  String get contactsSectionPinned => 'Fästa';

  @override
  String get contactStatusLabel => 'Status';

  @override
  String get contactStatusHint => 'Dela en status med dina kontakter…';

  @override
  String get contactStatusSave => 'Spara status';

  @override
  String get contactStatusUpdated => 'Status uppdaterad';

  @override
  String contactRemoveConfirmTitle(String name) {
    return 'Ta bort $name?';
  }

  @override
  String get contactRemoveConfirmBody =>
      'Tar bort personen från din kontaktlista. Du kan lägga till dem igen senare.';

  @override
  String contactBlockConfirmTitle(String name) {
    return 'Blockera $name?';
  }

  @override
  String get contactBlockConfirmBody =>
      'De kommer inte att kunna kontakta dig eller skicka kontaktförfrågningar.';

  @override
  String get settingsBlockedContacts => 'Blockerade kontakter';

  @override
  String get settingsBlockedEmpty => 'Inga blockerade kontakter';

  @override
  String get commonRemove => 'Ta bort';

  @override
  String get commonBlock => 'Blockera';

  @override
  String get contactProfileChatNotFound =>
      'Ingen chatt hittades för denna kontakt — den kan ha raderats';

  @override
  String get emergencyChatStart => 'Starta nödchatt';

  @override
  String emergencyChatConfirmTitle(String name) {
    return 'Starta en nödchatt med $name?';
  }

  @override
  String emergencyChatConfirmBody(String name) {
    return 'Det finns ingen aktiv chatt med $name. Detta startar en 12-timmars Time Wilt-chatt som skapas på distans, utan ihopparning i person. Den befintliga vissnade chatten och dess meddelanden förstörs permanent och kan aldrig laddas om igen.';
  }

  @override
  String get emergencyChatAlreadyActive =>
      'Du har redan en aktiv chatt med den här kontakten';

  @override
  String get emergencyChatStarted => 'Nödchatt startad';

  @override
  String get chatsEmergencyPendingSubtitle => 'Ansluter nödchatt…';

  @override
  String chatsEmergencyPendingSnackBar(String name) {
    return 'Nödchatt med $name väntar på att de ansluter.';
  }

  @override
  String get emergencyChatPending => 'Nödchatt väntar…';

  @override
  String get gestureSwipeForContacts => 'Svep från vänster kant för kontakter';

  @override
  String get contactProfileSafetyNumber => 'Identitetsnyckelns fingeravtryck';

  @override
  String get contactProfileWiltedHint =>
      'Starta en tillfällig 12-timmars Time Wilt-chatt';

  @override
  String get commonCopy => 'Kopiera';

  @override
  String get commonCopied => 'Kopierat till urklipp';

  @override
  String eventMentionTitle(String name) {
    return '$name nämnde dig';
  }

  @override
  String eventReplyTitle(String name) {
    return '$name svarade dig';
  }

  @override
  String get chatNotificationModeAll => 'Alla meddelanden';

  @override
  String get chatNotificationModeMentions => 'Endast omnämnanden och svar';

  @override
  String get chatNotificationModeMuted => 'Tystad (Ljudlös)';

  @override
  String get chatNotificationSettingsTitle => 'Aviseringar';

  @override
  String get chatMuteTitle => 'Tysta chatt';

  @override
  String get chatUnmuteTitle => 'Sluta tysta chatt';

  @override
  String get settingsNotifyCategories => 'Kategorier';

  @override
  String get settingsNotifyDirectMessages => 'Direktmeddelanden';

  @override
  String get settingsNotifyDirectMessagesSubtitle =>
      'Aviseringar för 1:1-chattar';

  @override
  String get settingsNotifyGroupMessages => 'Gruppmeddelanden';

  @override
  String get settingsNotifyGroupMessagesSubtitle =>
      'Aviseringar för gruppchattar';

  @override
  String get settingsNotifyEvents => 'Säkerhets- och aktivitetshändelser';

  @override
  String get settingsNotifyEventsSubtitle =>
      'Kontaktförfrågningar, omröstningar om gruppradering, skärmdumpsvarningar';

  @override
  String get settingsMutedChatsTitle => 'Tystade chattar';

  @override
  String get settingsNoMutedChats => 'Inga tystade chattar';

  @override
  String get settingsUnmute => 'Sluta tysta';

  @override
  String get settingsCheckForUpdates => 'Sök efter uppdateringar';

  @override
  String get settingsCheckingUpdates => 'Söker efter uppdateringar...';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Uppdatering tillgänglig: v$version';
  }

  @override
  String get settingsUpToDate => 'WiltKey är uppdaterad';

  @override
  String get settingsWhatsNew => 'Nyheter';

  @override
  String get settingsStorageSection => 'Lagring och historik';

  @override
  String get settingsHistoryLimitTitle => 'Spara meddelandehistorik';

  @override
  String get settingsHistoryLimitDescription =>
      'Rensa automatiskt äldre lokala meddelanden och mediefiler för att spara lagringsutrymme. Krypteringsnycklar och kontakter bevaras alltid.';

  @override
  String get settingsHistoryLimitAll => 'Behåll alla meddelanden (Obegränsat)';

  @override
  String settingsHistoryLimitCount(int count) {
    return 'Behåll de senaste $count meddelandena';
  }

  @override
  String get chatDetailsClearHistory => 'Rensa meddelandehistorik';

  @override
  String get chatDetailsClearHistoryConfirm => 'Rensa historik';

  @override
  String get chatDetailsClearHistoryDialogBody =>
      'Radera all lokal meddelandehistorik i den här chatten permanent? Krypteringsnycklar och kontaktstatus kommer att bevaras.';

  @override
  String get chatDetailsClearHistoryPrune100 =>
      'Behåll endast de senaste 100 meddelandena';

  @override
  String get chatDetailsClearHistorySuccess => 'Chatthistorik rensad';

  @override
  String get chatDetailsSectionMedia => 'Media, röst & länkar';

  @override
  String get chatDetailsMediaPhotos => 'Foton';

  @override
  String get chatDetailsMediaVoice => 'Röstmeddelanden';

  @override
  String get chatDetailsMediaLinks => 'Länkar';

  @override
  String get chatDetailsNoMedia => 'Inga delade foton ännu';

  @override
  String get chatDetailsNoVoice => 'Inga röstmeddelanden ännu';

  @override
  String get chatDetailsNoLinks => 'Inga delade länkar ännu';

  @override
  String get qrConnectTitle => 'QR-anslutning';

  @override
  String get qrConnectScanTab => 'Skanna QR';

  @override
  String get qrConnectMyCodeTab => 'Min QR-kod';

  @override
  String get qrConnectScanPrompt =>
      'Rikta kameran mot en WiltKey QR-kod för att ansluta direkt';

  @override
  String get qrConnect7DayNotice =>
      'Fjärranslutningar startar automatiskt som en 7-dagars Time Wilt-chatt. Personlig BLE-ihopparning krävs för att ladda om engångskryptering.';

  @override
  String get qrConnectRechargeBlocked =>
      'Den här kontakten finns redan. Omladdning av pad kräver personlig BLE-ihopparning och kan inte göras på distans.';

  @override
  String get qrConnectManualPin => 'Ange PIN manuellt';

  @override
  String get qrConnectShowYourCode =>
      'Skanning klar! Visa nu din QR-kod för dem också.';

  @override
  String get qrConnectFinishPairing => 'Slutför parkoppling';

  @override
  String get qrConnectOutdatedCode =>
      'Den här QR-koden kommer från en äldre appversion. Ni behöver båda ha den senaste versionen för att ansluta på det här sättet.';

  @override
  String get qrConnectOwnCode =>
      'Det där är din egen QR-kod — rikta kameran mot deras istället.';

  @override
  String get qrConnectAlreadyPaired =>
      'Du har redan en chatt med den här personen. Att förnya en befintlig chatt kräver ihopparning på plats.';

  @override
  String get testRelayBanner => 'TESTSERVER — INTE PRODUKTION';

  @override
  String get securingTitle => 'Säkrar din anslutning';

  @override
  String get securingBody =>
      'Din enhet verifierar sig mot reläet innan den ansluter. Detta engångs proof-of-work skyddar alla mot spam och missbruk — inget telefonnummer, ingen e-post, inget konto.';

  @override
  String get securingWorking => 'VERIFIERAR ENHET — ARBETAR…';

  @override
  String get securingOnceNote =>
      'Detta händer bara vid din första anslutning. Därefter är återanslutningen omedelbar.';

  @override
  String get puzzleInstruction => 'Dra tills pixelarten är symmetrisk.';

  @override
  String get puzzleLockIn => 'Lås fast';

  @override
  String get puzzleFailedRetry =>
      'Det blev inte helt rätt — vi startar en ny kontroll…';

  @override
  String get reauthenticatingBanner => 'ÅTERAUTENTISIERAR — VÄNLIGEN VÄNTA…';

  @override
  String get connectionLostBanner =>
      'WEBSOCKET-ANSLUTNINGEN MISSLYCKADES — FÖRSÖKER IGEN…';

  @override
  String get badgePlayPlus => 'Play Butik · Plus';

  @override
  String get badgePlayPlusSubtitle =>
      'Verifierad Google Play-version + Plus-supporter';

  @override
  String get badgePlayPlusExplainer =>
      'Den här användaren kör en officiell, omodifierad version som verifierats via Google Play Integrity och stöder aktivt WiltKey med ett aktivt Plus-medlemskap.';

  @override
  String get badgePlayVerified => 'Play Butik';

  @override
  String get badgePlayVerifiedSubtitle => 'Verifierad Google Play-version';

  @override
  String get badgePlayVerifiedExplainer =>
      'Den här användaren kör en officiell, omodifierad version som verifierats kryptografiskt via Google Play Integrity.';

  @override
  String get badgeFoss => 'Öppen källkod';

  @override
  String get badgeFossSubtitle => 'Community- / FOSS-version';

  @override
  String get badgeFossExplainer =>
      'Den här klienten kör en version med öppen källkod eller en anpassad version. Eftersom den inte kör Googles proprietära tjänster behandlas den som en community-version. Alla meddelanden och kryptering förblir 100 % säkra och privata.';

  @override
  String get groupAnonymousMember => 'Medlem';

  @override
  String get groupMemberRoleHost => 'Värd';

  @override
  String get contactSelfBadge => 'Du';

  @override
  String get chatAttachContentTitle => 'Bifoga till chatt';

  @override
  String get chatAttachPhotos => 'Foton & kamera';

  @override
  String get chatAttachPhotosSubtitle =>
      'Ta ett foto eller välj från galleriet';

  @override
  String get chatAttachPixelArt => 'Pixel art & avatarer';

  @override
  String get chatAttachPixelArtSubtitle =>
      'Rita en pixelteckning eller skicka från sparade mallar';

  @override
  String get chatAttachVideo => 'Video';

  @override
  String get chatAttachVideoSubtitle =>
      'Krypterade korta videoklipp i en framtida uppdatering';

  @override
  String get chatAttachComingSoon => 'KOMMER SNART';

  @override
  String get chatPixelArtDrawNew => 'Rita ny pixel art';

  @override
  String get chatPixelArtTemplates => 'Sparade avatarmallar';

  @override
  String get chatPixelArtSend => 'Skicka till chatt';

  @override
  String get chatPixelArtNoTemplates => 'Inga sparade avatarmallar än';

  @override
  String get chatPixelArtActionTitle => 'Pixel art-alternativ';

  @override
  String get chatPixelArtActionApplyAvatar => 'Använd som min profilavatar';

  @override
  String get chatPixelArtActionSaveTemplate => 'Spara till avatarmallar';

  @override
  String get chatPixelArtActionSaveEmoji => 'Spara som egen emoji';

  @override
  String get chatPixelArtActionExportPng => 'Exportera PNG till foton';

  @override
  String get chatPixelArtActionAppliedAvatarSuccess =>
      'Profilavatar uppdaterad och synkroniserad';

  @override
  String get chatPixelArtActionSavedTemplateSuccess =>
      'Sparad i avatarmallsbiblioteket';

  @override
  String get chatPixelArtActionExportedPngSuccess => 'Sparade PNG-bild i foton';

  @override
  String get chatSearchHint => 'Sök i chatten...';

  @override
  String get chatSearchNoMatches => '0 träffar';

  @override
  String get contactPrivateNoteTitle => 'Privata anteckningar & smeknamn';

  @override
  String get contactPrivateNoteHint =>
      'Lägg till privata anteckningar om denna kontakt (lagras endast lokalt)...';

  @override
  String get contactCustomNicknameTitle => 'Anpassat smeknamn';

  @override
  String get contactCustomNicknameHint => 'Åsidosätt visningsnamn lokalt...';

  @override
  String get contactNotesSaved => 'Kontaktuppgifter sparade';

  @override
  String get onboardingSocialTitle => 'WiltKey Socialt konto';

  @override
  String get onboardingSocialExplanation =>
      'Aktiverar din WiltKey Social-profil och serverstödd upptäckt. Din offentliga identitetsnyckel registreras hos reläet (och kan när som helst återkallas/raderas permanent av dig) för att verifiera upphovsrätten för 24-timmars vissnande händelser och sändningsinlägg. Allt innehåll förblir totalsträckskrypterat med nollkunskap (zero-knowledge).';

  @override
  String get onboardingSocialEnable =>
      'Aktivera WiltKey Social (Rekommenderas)';

  @override
  String get onboardingSocialEnableDesc =>
      'Dela 24-timmars vissnande händelser med gemensamma kontakter, skicka anpassad pixel art och delta i sociala sändningar.';

  @override
  String get onboardingSocialZeroServer =>
      'Noll serverdataläge (Absolut integritet)';

  @override
  String get onboardingSocialZeroServerDesc =>
      'Maximal anonymitet. Strikt peer-to-peer och direkt 1:1/gruppmeddelanden utan någon identitetsregistrering på servern. Fjärrstyrda sociala funktioner och händelser är inaktiverade.';

  @override
  String get settingsSocialAccountTitle => 'WiltKey Socialt konto';

  @override
  String get settingsSocialAccountSubtitle =>
      'Tillåt serverstödda 24-timmars händelser och upptäckt';

  @override
  String get settingsStoriesReelTitle => 'Översiktens händelsefält';

  @override
  String get settingsStoriesReelSubtitle =>
      'Visa 24-timmars händelser högst upp på chattfliken';

  @override
  String get connectTabConnect => 'Anslut';

  @override
  String get connectTabSocial => 'Socialt';

  @override
  String get forcedUpdateTitle => 'Uppdatering krävs';

  @override
  String get forcedUpdateSubtitle =>
      'En obligatorisk uppdatering krävs för att fortsätta använda WiltKey säkert.';

  @override
  String get forcedUpdateAction => 'Uppdatera nu';

  @override
  String get forcedUpdateCheckAgain => 'Kontrollera igen';

  @override
  String get forcedUpdateSecurityNotice =>
      'Denna version innehåller kritiska protokoll- eller säkerhetsuppdateringar. Äldre versioner kan inte längre kommunicera med nätverket.';

  @override
  String get forcedUpdateWhatsNew => 'Nyheter i denna uppdatering';

  @override
  String get settingsSwipeGesturesTitle => 'Svepgester för chatt';

  @override
  String get settingsSwipeGesturesSubtitle =>
      'Anpassa åtgärder för svep åt höger och vänster i chattlistan';

  @override
  String get settingsSwipeRight => 'Svep åt höger';

  @override
  String get settingsSwipeLeft => 'Svep åt vänster';

  @override
  String get swipeActionMarkRead => 'Läst / Oläst';

  @override
  String get swipeActionMute => 'Tysta / Sluta tysta';

  @override
  String get swipeActionPin => 'Fäst / Lossa';

  @override
  String get swipeActionArchive => 'Arkivera';

  @override
  String get swipeActionNone => 'Inaktiverad';

  @override
  String get chatSwipeMarkRead => 'Läst';

  @override
  String get chatSwipeMarkUnread => 'Oläst';

  @override
  String get chatSwipePin => 'Fäst';

  @override
  String get chatSwipeUnpin => 'Lossa';

  @override
  String get chatSwipeMute => 'Tysta';

  @override
  String get chatSwipeUnmute => 'Sluta tysta';

  @override
  String get chatSwipeArchive => 'Arkivera';

  @override
  String get chatAttachVideoSubtitleEnabled =>
      'Spela in upp till 15 s eller välj från galleriet';

  @override
  String get chatVideoSelectSourceTitle => 'Skicka video';

  @override
  String get chatVideoQualityLabel => 'Kvalitet';

  @override
  String get chatVideoQualityLow => 'Låg';

  @override
  String get chatVideoQualityMedium => 'Mellan';

  @override
  String get chatVideoQualityHigh => 'Hög';

  @override
  String get chatVideoCompressionFailed =>
      'Det gick inte att komprimera klippet. Prova ett kortare klipp eller lägre kvalitet.';

  @override
  String get chatVideoRecordCamera => 'Spela in video (Kamera)';

  @override
  String get chatVideoPickGallery => 'Välj video från galleriet';

  @override
  String get chatVideoCompressing => 'Komprimerar video...';

  @override
  String chatVideoTooLarge(String size) {
    return 'Videon överskrider storleksgränsen ($size)';
  }

  @override
  String get chatVideoTooLong =>
      'Videon överskrider tidsgränsen på 15 sekunder';

  @override
  String get chatVideoSaveGallery => 'Spara video i galleriet';

  @override
  String get chatVideoSavedGallery => 'Video sparad i galleriet';

  @override
  String get chatVideoError => 'Det går inte att spela upp videoklippet';
}
