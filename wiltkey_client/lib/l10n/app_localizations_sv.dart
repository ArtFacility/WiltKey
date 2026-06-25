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
  String get navPair => 'Koppla';

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
  String get settingsProfileBrushColor => 'Penselfärg';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Rensa';

  @override
  String get settingsProfileChipRandom => 'Slumpmässig';

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
  String get settingsLanguageEnglish => 'English';

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
      'Letar efter nya meddelanden ungefär var 10:e minut. Sparar på batteriet.';

  @override
  String get notificationModeInstant => 'Direkt';

  @override
  String get notificationModeInstantDesc =>
      'Håller en säker anslutning aktiv i bakgrunden för omedelbara aviseringar. Visar en pågående avisering och drar mer batteri.';

  @override
  String get notificationNewMessageBody => 'Du har fått ett meddelande';

  @override
  String get notificationSecureLinkActive => 'Säker anslutning aktiv';

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
      'Lås upp med fingeravtryck istället för PIN. PIN krävs igen efter 4 timmars inaktivitet.';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Det gick inte att aktivera fingeravtrycksupplåsning.';

  @override
  String get pinForgotButton => 'Glömt PIN-kod? Återställ enhet';

  @override
  String get pairTitle => 'Koppla enheter';

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
  String get chatTapForDetails => 'Tryck för detaljer';

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
}
