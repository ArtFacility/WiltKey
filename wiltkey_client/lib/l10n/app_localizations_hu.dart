// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get navChats => 'Csevegések';

  @override
  String get navPair => 'Kapcsolódás';

  @override
  String get navSettings => 'Beállítások';

  @override
  String get nukedTitle => 'Eszköz visszaállítása';

  @override
  String get nukedExplanation =>
      'Minden üzenet és kulcs törölve lett erről az eszközről. A biztonságos adatbázis kiürült.';

  @override
  String get nukedResetButton => 'Új személyazonosság létrehozása';

  @override
  String get commonCancel => 'Mégse';

  @override
  String get commonClose => 'Bezárás';

  @override
  String get commonSave => 'Mentés';

  @override
  String get commonBack => 'Vissza';

  @override
  String get commonContinue => 'Folytatás';

  @override
  String get commonFinish => 'Befejezés';

  @override
  String get onboardingWelcomeTitle => 'Üdvözöl a Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'A Wiltkey egy privát üzenetküldő, amely nem ment metaadatokat, naplókat vagy szerverelőzményeket. Az üzenetek helyileg titkosítottak, és képernyőkép készítése esetén megsemmisülnek.';

  @override
  String get onboardingWelcomeNoHistory =>
      'Nincsenek szerverelőzmények. Nincsenek helyreállító kulcsok.';

  @override
  String get onboardingIntelTitle => 'Biztonsági információk';

  @override
  String get onboardingLanguageDescription =>
      'Válassz nyelvet a folytatáshoz. Ezt később bármikor megváltoztathatod a Beállításokban.';

  @override
  String get onboardingFactLanguageTitle => 'Nyelvbeállítás';

  @override
  String get onboardingFactLanguageBody =>
      'Válaszd ki a nyelvet a folytatáshoz. Ezt később bármikor megváltoztathatod a Beállításokban. A választásod helyileg mentődik.';

  @override
  String get onboardingThemeTitle => 'Válassz témát';

  @override
  String get onboardingThemeDescription =>
      'Válassz egy témát az alábbiak közül. Ezt később módosíthatod a Beállításokban.';

  @override
  String get onboardingProfileTitle => 'Személyazonosságod';

  @override
  String get onboardingProfileUsernameLabel => 'Felhasználónév';

  @override
  String get onboardingProfileUsernameHint => 'Add meg a felhasználóneved';

  @override
  String get onboardingProfileCodenameLabel => 'Kapcsolati kód (5 betű/szám)';

  @override
  String get onboardingProfileCodenameExplanation =>
      'Ezt a kódot osztod meg párosításkor, hogy kapcsolódj a közelben lévő barátaiddal.';

  @override
  String get onboardingProfileUsernameError =>
      'Kérjük, adj meg egy felhasználónevet.';

  @override
  String get onboardingProfileCodenameError =>
      'A kapcsolati kódnak pontosan 5 karakterből kell állnia.';

  @override
  String get onboardingAvatarTitle => 'Pixel avatar';

  @override
  String get onboardingAvatarBrushColor => 'Ecset színe';

  @override
  String get onboardingAvatarRandom => 'Véletlenszerű';

  @override
  String get onboardingAvatarClear => 'Törlés';

  @override
  String get onboardingPinTitle => 'PIN kód';

  @override
  String get onboardingPinExplanation =>
      'Állíts be egy PIN-kódot (4–6 számjegy) a csevegéseid védelmében. Ezt a PIN-kódot minden alkalommal meg kell adnod, amikor megnyitod az alkalmazást. Ha elfelejted, az üzeneteid nem állíthatók helyre.';

  @override
  String get onboardingPinEnter => 'Írd be a PIN-kódot';

  @override
  String get onboardingPinConfirm => 'Megerősítés';

  @override
  String get onboardingPinLengthError =>
      'A PIN-kódnak 4 és 6 számjegy között kell lennie.';

  @override
  String get onboardingPinMatchError => 'A PIN-kódok nem egyeznek.';

  @override
  String onboardingSetupFailed(String error) {
    return 'Sikertelen beállítás: $error';
  }

  @override
  String get onboardingFactMetadataTitle => 'A METAADAT-PROBLÉMA';

  @override
  String get onboardingFactMetadataBody =>
      'A legtöbb csevegőalkalmazás titkosítja az üzenet tartalmát, de továbbra is követi, hogy kivel, mikor és milyen gyakran beszélsz. A Wiltkey nem naplóz metaadatokat, szerveroldali adatokat vagy kapcsolatokat.';

  @override
  String get onboardingFactThemeTitle => 'VÁLASSZ TÉMÁT';

  @override
  String get onboardingFactThemeBody =>
      'A témák csupán vizuálisak. Ugyanazok a biztonsági szabványok érvényesek mindegyikre. A témát bármikor megváltoztathatod a Beállításokban.';

  @override
  String get onboardingFactOtpTitle => 'TÖKÉLETES TITOKTARTÁS';

  @override
  String get onboardingFactOtpBody =>
      'A Wiltkey egyszeri kulcsokat (OTP) használ, ahol a kulcsok mérete megegyezik az üzenetével, teljesen véletlenszerűek és soha nem használhatók fel újra. Ez matematikailag tökéletes biztonságot nyújt, így az üzeneteket a kulcsok nélkül lehetetlen megfejteni.';

  @override
  String get onboardingFactLimitsTitle => 'KAPCSOLATI KORLÁTOK';

  @override
  String get onboardingFactLimitsBody =>
      'A csevegési korlátokat úgy terveztük, hogy értelmes és szándékos kapcsolatokra ösztönözzenek. A kapacitás korlátozása biztosítja, hogy a beszélgetések céltudatosak és a valós kapcsolatokon alapuljanak.';

  @override
  String get onboardingFactKdfTitle => 'BIZTONSÁGI HASH-ELÉS';

  @override
  String get onboardingFactKdfBody =>
      'Egy normál PIN-kód ezredmásodpercek alatt feltörhető. A Wiltkey egy erősítő funkción keresztül dolgozza fel a PIN-kódodat, lehetetlenné téve a helyi adatbázis elleni brute-force támadásokat.';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get settingsTabProfile => 'Profil';

  @override
  String get settingsTabSecurity => 'Biztonság';

  @override
  String get settingsSecuritySectionAccess => 'Hozzáférés és feloldás';

  @override
  String get settingsSecuritySectionDanger => 'Veszélyzóna';

  @override
  String get settingsTabNetwork => 'Hálózat';

  @override
  String get settingsTabAlerts => 'Értesítések';

  @override
  String get settingsSavedIndicator => 'Mentve';

  @override
  String get settingsProfileSectionAppearance => 'Megjelenés';

  @override
  String get settingsProfileSectionAvatar => 'Pixel Art avatar';

  @override
  String get settingsProfileSectionProfile => 'Profilbeállítások';

  @override
  String get settingsProfileSectionOtherVisuals => 'Egyéb megjelenés';

  @override
  String get settingsThemeLabel => 'Téma';

  @override
  String get settingsPixelArtEditor => 'Pixelrajz-szerkesztő';

  @override
  String get settingsProfileBrushColor => 'Ecset színe';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Törlés';

  @override
  String get settingsProfileChipRandom => 'Véletlenszerű';

  @override
  String get settingsProfileChipTemplateSave => 'Mentés sablonként';

  @override
  String get settingsProfileTemplateSaved => 'Sablonok közé mentve';

  @override
  String get settingsProfileTemplatesButton => 'Választás sablonból';

  @override
  String get settingsProfileTemplatesTitle => 'Mentett sablonok';

  @override
  String get settingsProfileNoTemplates => 'Nincsenek mentett sablonok';

  @override
  String get settingsProfileTemplateEquipped => 'Profilkép-sablon beállítva';

  @override
  String get avatarEditButton => 'Avatar szerkesztése';

  @override
  String get groupCreateEditIcon => 'Ikon szerkesztése';

  @override
  String get settingsProfileUsername => 'Felhasználónév';

  @override
  String get settingsProfileBleNick => 'Rövid becenév (5 karakter)';

  @override
  String get settingsProfileKeyhash => 'Fiókazonosító';

  @override
  String get settingsProfileKeyhashCopied =>
      'Fiókazonosító a vágólapra másolva';

  @override
  String get settingsProfileChangePinButton => 'PIN módosítása';

  @override
  String get settingsProfileResetIdentityButton => 'Fiók törlése';

  @override
  String get settingsResetConfirmTitle => 'Törlöd a személyazonosságod?';

  @override
  String get settingsResetConfirmBody =>
      'Ez véglegesen törli az összes üzenetet, kapcsolatot, és új személyazonosságot hoz létre. Ez a művelet nem vonható vissza.';

  @override
  String get settingsResetConfirmCancel => 'Mégse';

  @override
  String get settingsResetConfirmReset => 'Visszaállítás';

  @override
  String get settingsChangePinTitle => 'PIN módosítása';

  @override
  String get changePinVerifyTitle => 'Jelenlegi PIN ellenőrzése';

  @override
  String get changePinVerifyPrompt =>
      'Add meg a jelenlegi PIN-kódodat a folytatáshoz.';

  @override
  String get changePinSetTitle => 'Új PIN beállítása';

  @override
  String get settingsChangePinOldPin => 'Add meg a jelenlegi PIN-kódot';

  @override
  String get settingsChangePinNewPin =>
      'Add meg az új PIN-kódot (4–6 számjegy)';

  @override
  String get settingsChangePinConfirmPin => 'Megerősítés';

  @override
  String get settingsChangePinEmptyFieldsError =>
      'Kérjük, töltsd ki az összes mezőt.';

  @override
  String get settingsChangePinLengthError =>
      'Az új PIN-kódnak 4 és 6 számjegy között kell lennie.';

  @override
  String get settingsChangePinMatchError => 'Az új PIN-kódok nem egyeznek.';

  @override
  String get settingsChangePinUpdatedSnackBar => 'PIN-kód frissítve.';

  @override
  String get settingsChangePinIncorrectError =>
      'A jelenlegi PIN-kód helytelen.';

  @override
  String get settingsNetworkRoutingTitle => 'Hálózati beállítások';

  @override
  String get settingsNetworkDevRelayToggle =>
      'Helyi fejlesztői szerver használata';

  @override
  String get settingsNetworkDevRelayUrlLabel => 'Fejlesztői szerver URL-je';

  @override
  String get settingsNetworkDevRelayDescription =>
      'Bekapcsolásával felülírja a produkciós szervert, és a helyi szerveren keresztül továbbítja az üzeneteket.';

  @override
  String get settingsNetworkActiveGateway => 'Jelenlegi szerver URL';

  @override
  String get settingsNetworkDiagnostics => 'Diagnosztika';

  @override
  String get settingsNetworkDebugButton => 'Hibakereső konzol megnyitása';

  @override
  String get settingsDebugButtonsToggle => 'Hibakereső gombok';

  @override
  String get settingsDebugButtonsDescription =>
      'Megjeleníti a terminálkonzol gombját a csevegéslistában és a csevegésekben.';

  @override
  String get settingsDebugTitle => 'Hibakereső konzol';

  @override
  String get settingsAlertsBackgroundNotifications => 'Háttérbeli értesítések';

  @override
  String get settingsAlertsExplanation =>
      'Az értesítésekben csak az \'Új üzeneted érkezett\' szöveg fog megjelenni. Az üzeneteid titkosítva maradnak az alkalmazás feloldásáig.';

  @override
  String get settingsTextSizeLabel => 'Csevegés szövegmérete';

  @override
  String get settingsTextSizePreview => 'Így fognak kinézni az üzeneteid.';

  @override
  String get settingsLanguageLabel => 'Nyelv';

  @override
  String get settingsLanguageSystem => 'Rendszer nyelve';

  @override
  String get settingsLanguageEnglish => 'English (Angol)';

  @override
  String get settingsLanguageHungarian => 'Magyar';

  @override
  String get settingsLanguagePolish => 'Polski (Lengyel)';

  @override
  String get settingsLanguageGerman => 'Deutsch (Német)';

  @override
  String get settingsLanguageFrench => 'Français (Francia)';

  @override
  String get settingsLanguageSwedish => 'Svenska (Svéd)';

  @override
  String get settingsLanguageChinese => '中文 (Kínai)';

  @override
  String get notificationModeOff => 'Kikapcsolva';

  @override
  String get notificationModeOffDesc =>
      'Nincs háttérbeli ellenőrzés. Csak az alkalmazás megnyitásakor látod az üzeneteket.';

  @override
  String get notificationModeLowPower => 'Alacsony fogyasztás';

  @override
  String get notificationModeLowPowerDesc =>
      'Rendszeresen ellenőrzi az új üzeneteket a háttérben – gyorsan közvetlenül az alkalmazás bezárása után, majd ritkábban az akkumulátor kímélése érdekében. Nincs állandó kapcsolat, ezért az értesítések késhetnek.';

  @override
  String get notificationModeInstant => 'Azonnali';

  @override
  String get notificationModeInstantDesc =>
      'Opcionális. A háttérben nyitva tart egy végpontok közötti titkosított kapcsolatot, hogy valós időben szinkronizálja a bejövő üzeneteket, amit egy állandó értesítés jelez. A Wiltkey adatvédelmi okokból ezt használja a Google vagy az Apple push-szolgáltatásai helyett, így Google Play-szolgáltatások nélkül is működik – nagyobb akkumulátor-fogyasztás árán.';

  @override
  String get notificationNewMessageBody => 'Új üzeneted érkezett';

  @override
  String get notificationEmergencyChatBody => 'Vészhelyzeti chat kérés';

  @override
  String get notificationSecureLinkActive =>
      'Biztonságos üzenetek szinkronizálása';

  @override
  String get onboardingNotificationsTitle => 'Értesítések';

  @override
  String get onboardingNotificationsExplanation =>
      'A Wiltkey nem használ Google vagy Apple push-értesítéseket – az üzeneteidről semmi nem kerül a szervereikre. Válaszd ki, hogyan szeretnél értesítést kapni. Ezt bármikor módosíthatod a Beállításokban.';

  @override
  String get onboardingFactPushTitle => 'NINCS PUSH-SZERVER';

  @override
  String get onboardingFactPushBody =>
      'A szokásos alkalmazások a Google-ön vagy Apple-ön keresztül küldik az értesítéseket, elárulva, ki és mikor ír neked. A Wiltkey ezt soha nem teszi – alapból egyáltalán nincs háttérellenőrzés, és minden értesítés kizárólag a te eszközödön fut.';

  @override
  String get notificationModeInstantDescFcm =>
      'Választható. A Google push-szolgáltatását használja egyszerű ébresztőjelként, hogy az új üzenetek valós időben megérkezzenek. A Google-ön csak egy tartalom nélküli jelzés megy át – soha nem az üzeneteid, amelyek végponttól végpontig titkosítva maradnak a relén, amíg az eszközöd le nem tölti őket. Kevésbé terheli az akkut, mint az állandó kapcsolat.';

  @override
  String get onboardingNotificationsExplanationFcm =>
      'A valós idejű értesítésekhez ez a verzió a Google push-szolgáltatását kizárólag ébresztőjelként használja – egy tartalom nélküli jelzés, soha nem az üzeneteid, amelyek soha nem érintik a Google szervereit. Válaszd ki, hogyan szeretnél értesítést kapni; ezt bármikor módosíthatod a Beállításokban.';

  @override
  String get onboardingFactPushTitleFcm => 'TARTALOM NÉLKÜLI PUSH';

  @override
  String get onboardingFactPushBodyFcm =>
      'A szokásos alkalmazások a Google-ön keresztül küldik az értesítések tartalmát, elárulva, mit és mikor küldenek. Ez a verzió a Google-t csak tartalom nélküli ébresztőjelként használja – nincs üzenetadat, nincs olvasható metaadat –, és minden végponttól végpontig titkosítva marad.';

  @override
  String get chatsLockedSubtitle =>
      'Zárolva · párosítsd személyesen a feloldáshoz';

  @override
  String chatsMemberCount(int count) {
    return '$count tag';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: 'kapcsolat',
      one: 'kapcsolat',
    );
    return '$totalCount $_temp0 · $lockedCount zárolt';
  }

  @override
  String get chatsTitle => 'Csevegések';

  @override
  String get chatsPopupPair => 'Eszköz párosítása';

  @override
  String get chatsPopupCreateGroup => 'Csoport létrehozása';

  @override
  String get chatsPopupJoinGroup => 'Csatlakozás csoporthoz';

  @override
  String get chatsSearchHint => 'Keresés';

  @override
  String get chatsEmptyNoMatches => 'Nincs találat';

  @override
  String get chatsEmptyNoChats => 'Még nincsenek csevegések';

  @override
  String get chatsEmptyPairInstruction =>
      'Párosíts egy eszközt személyesen a csevegés indításához.';

  @override
  String get chatsEmptyPairButton => 'Eszköz párosítása';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return 'ÉN $remaining · TÁRS $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded =>
      'Túl sok helytelen kísérlet. Eszköz adatai törölve.';

  @override
  String pinAccessDenied(int attempts) {
    return 'Helytelen PIN. Még $attempts próbálkozás maradt.';
  }

  @override
  String get pinMinLengthError =>
      'A PIN-kódnak legalább 4 számjegyből kell állnia.';

  @override
  String get pinPurgeConfirmTitle => 'Visszaállítod az eszközt?';

  @override
  String get pinPurgeConfirmBody =>
      'Elfelejtetted a PIN-kódot? Véglegesen törölsz minden üzenetet és visszaállítja a fiókodat. Ez a művelet nem vonható vissza.';

  @override
  String get pinPurgeConfirmButton => 'Adatok Törlése';

  @override
  String get pinLockedTitle => 'Zárolva';

  @override
  String get pinLockedSubtitle => 'Írd be a PIN-kódot a feloldáshoz';

  @override
  String get pinUnlockButton => 'Feloldás';

  @override
  String get pinUseFingerprintButton => 'Ujjlenyomat használata';

  @override
  String get settingsBiometricToggle => 'Feloldás ujjlenyomattal';

  @override
  String get settingsBiometricDescription =>
      'Az ujjlenyomatoddal oldhatod fel a PIN helyett. Az alább beállított idő után újra a PIN szükséges.';

  @override
  String get settingsBiometricIdleTitle => 'PIN-tartalék';

  @override
  String get settingsBiometricIdleDescription =>
      'Ennyi feloldás nélküli idő után újra a PIN kell.';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours ó';
  }

  @override
  String get settingsBiometricIdleNever => 'Soha';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Nem sikerült bekapcsolni az ujjlenyomatos feloldást.';

  @override
  String get pinForgotButton => 'Elfelejtetted a PIN-kódot? Adatok Törlése';

  @override
  String get pairTitle => 'Eszközök párosítása';

  @override
  String get pairRescanTooltip => 'Keresés frissítése';

  @override
  String get pairBluetoothOffWarning =>
      'A Bluetooth ki van kapcsolva. A párosításhoz Bluetooth kell a közeli eszközök megtalálásához — kapcsold be a folytatáshoz.';

  @override
  String get pairBluetoothTurnOnButton => 'Bluetooth bekapcsolása';

  @override
  String get pairDoNotExitWarning =>
      'Hagyd nyitva a WiltKey-t – ne válts appot és ne lépj ki, amíg a párosítás MINDKÉT eszközön be nem fejeződött.';

  @override
  String get pairRequestDialogTitle => 'Párosítási kérelem';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName párosítani szeretne.\n\nCsevegés mérete: $size.\n\nElfogadod a biztonságos párosítást?';
  }

  @override
  String get pairRequestReject => 'Elutasítás';

  @override
  String get pairRequestAccept => 'Elfogadás';

  @override
  String get pairPingStatusPinging => 'Tesztelés...';

  @override
  String pairPingStatusLatency(String latency) {
    return 'Késleltetés: $latency ms';
  }

  @override
  String get pairPingStatusFailed => 'Sikertelen';

  @override
  String get pairPingStatusTest => 'Kapcsolat tesztelése';

  @override
  String get pairDeviceNameLabel => 'Eszközöd neve';

  @override
  String get pairDeviceNameHint => 'Add meg a nevet';

  @override
  String get pairDiscoverableTitle => 'Eszköz láthatóvá tétele';

  @override
  String get pairDiscoverableSubtitle =>
      'Engedélyezd a közeli barátoknak, hogy megtaláljanak';

  @override
  String get pairNearbyDevicesTitle => 'Közeli eszközök';

  @override
  String get pairNearbyDevicesInstruction =>
      'Tartsd az eszközöket egymás mellett a csatlakozáshoz.';

  @override
  String get pairDirectSyncFormRelayLabel => 'Szerver URL';

  @override
  String get pairDirectSyncFormSyncButton => 'Eszközök csatlakoztatása';

  @override
  String get pairSyncingConnecting => 'Kapcsolódás...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return 'Kulcs generálása ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return 'Kulcs: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return '$percent% kész';
  }

  @override
  String get pairSuccessConnectionSecured => 'Sikeresen csatlakoztatva';

  @override
  String pairSuccessGroupBody(String groupName) {
    return 'Csatlakoztál a(z) \"$groupName\" csoporthoz. A kulcsok helyileg generálódtak az eszközödön.';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return 'A kulcsok átadva és legenerálva az eszközödön. Kapcsolódva $title felhasználóhoz $label chat mérettel.';
  }

  @override
  String get pairSuccessReturnButton => 'Ugrás a csevegésekhez';

  @override
  String get chatDetailsTitle => 'Csevegés részletei';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return 'Becenév: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => 'Hivatalos közvetítő';

  @override
  String get chatDetailsPrivateNode => 'Privát csomópont';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return 'ÉN $remaining · TÁRS $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => 'Profil';

  @override
  String get chatDetailsProfileExplanation =>
      'Az avatarok és becenevek automatikusan szinkronizálódnak a kapcsolódáskor. Szükség esetén manuálisan is szinkronizálhatod a sajátodat.';

  @override
  String get chatDetailsProfileSyncButton => 'Profil szinkronizálása';

  @override
  String get chatDetailsProfileSnackBar => 'Profil elküldve.';

  @override
  String get chatDetailsSectionPermissions => 'Engedélyek';

  @override
  String get chatDetailsPermissionsPhotos =>
      'Fényképek megosztásának engedélyezése';

  @override
  String get chatDetailsPermissionsEmojis => 'Egyedi emojik';

  @override
  String get chatDetailsPermissionsEmojisAvailable => 'Elérhető';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize =>
      'Nagyobb csevegési méret szükséges';

  @override
  String get chatDetailsSectionMetadata => 'Metaadat-terület';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return 'Ez a csevegés $budget részt foglal le a maximális $max területből a beállításoknak, profilképeknek és egyedi emojiknak.';
  }

  @override
  String get chatDetailsSectionLanes => 'Biztonságos sávok';

  @override
  String get chatDetailsLanesMySend => 'Küldési kapacitásom';

  @override
  String get chatDetailsLanesPeerSend => 'Társ küldési kapacitása';

  @override
  String get chatDetailsLanesBorrowed => 'Kölcsönzött terület';

  @override
  String get chatDetailsLanesCapacityLeft => 'Fennmaradó kapacitásom';

  @override
  String get chatDetailsLanesExplanation =>
      'Ha elfogy a csevegési kapacitásod, kölcsönözhetsz fel nem használt területet a társadtól. Ez automatikusan is megtörténhet, hogy folytathasd a csevegést.';

  @override
  String get chatDetailsLanesBorrowButton => 'Csevegőterület kérése';

  @override
  String get chatDetailsLanesSnackBar => 'Kérés elküldve a társnak.';

  @override
  String get chatDetailsSectionEmojis => 'Egyedi emojik';

  @override
  String get chatDetailsEmojisExplanation =>
      'Használd ezeket az egyedi emojikat az üzeneteidben a :név: formátumban.';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      'Ez a csevegési kapacitás túl kicsi az egyedi emojikhoz. Csatlakozz nagyobb kapacitással az engedélyezésükhöz.';

  @override
  String get chatDetailsEmojisCreate => 'Létrehozás';

  @override
  String get chatDetailsSectionDestructive => 'Veszélyes beállítások';

  @override
  String get chatDetailsNukeButton =>
      'Csevegés megsemmisítése (mindkét oldalon)';

  @override
  String get chatDetailsDeleteEmojiTitle => 'Törlöd az emojit?';

  @override
  String get chatDetailsDeleteEmojiBody =>
      'Ez az egyedi emoji véglegesen törlődik. Szeretnéd folytatni?';

  @override
  String get chatDetailsDeleteEmojiDelete => 'Törlés';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return ':$name: hozzáadva';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return 'A kép túl nagy ($cost) a fennmaradó helyhez ($charge).';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar => 'A kép túl nagy a küldéshez.';

  @override
  String get chatImageNeedsPlusSnackBar =>
      'A kép túl nagy az ingyenes csomaghoz — a WiltKey Plus 50 MB-ra emeli a korlátot.';

  @override
  String get chatTapForDetails => 'Koppints a részletekért';

  @override
  String get chatSyncTooltip => 'Üzenetek szinkronizálása';

  @override
  String get chatStickerHint => 'Tartson nyomva egy emojit matrica küldéséhez';

  @override
  String get chatSyncStarted => 'Elmaradt üzenetek keresése…';

  @override
  String get chatSyncOffline => 'Offline nem lehet szinkronizálni.';

  @override
  String get chatEncrypting => 'Titkosítás…';

  @override
  String get chatScreenshotDetected => 'Képernyőkép észlelve';

  @override
  String get chatScreenshotExplanation =>
      'Képernyőképet észleltünk. A biztonságod érdekében most törölheted a kulcsaidat és az üzeneteidet.';

  @override
  String get chatScreenshotWipeButton => 'Üzenetek és kulcsok megsemmisítése';

  @override
  String get chatScreenshotIgnoreButton =>
      'Figyelmeztetés figyelmen kívül hagyása';

  @override
  String get chatSimulateScreenshotButton => 'Képernyőkép szimulálása';

  @override
  String chatCostIndicator(String cost) {
    return 'Költség: $cost';
  }

  @override
  String get groupCreateTitle => 'Csoport létrehozása';

  @override
  String get groupCreatePixelArtIcon => 'Csoport ikonja';

  @override
  String get groupCreateRandomIcon => 'Generálás';

  @override
  String get groupCreateClearIcon => 'Törlés';

  @override
  String get groupCreateNameLabel => 'Csoport neve';

  @override
  String get groupCreateNameEmptyValidator => 'Adj meg egy csoportnevet';

  @override
  String get groupCreateNameLengthValidator => 'Legfeljebb 24 karakter';

  @override
  String get groupCreatePoliciesSection => 'Csoportszabályzat beállításai';

  @override
  String get groupCreatePolicyPadSize => 'Csoportos csevegés mérete';

  @override
  String get groupCreatePolicyLaneSize => 'Kapacitás tagonként';

  @override
  String get groupCreatePolicyMaxMembersLabel => 'Maximális taglétszám';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return 'Legfeljebb $count tag';
  }

  @override
  String get groupCreatePolicyAllowImages =>
      'Fényképek megosztásának engedélyezése';

  @override
  String get groupCreatePolicyAllowImagesSub => 'Tagok küldhetnek fényképeket';

  @override
  String get groupCreatePolicyPayloadSize => 'Maximális üzenetméret';

  @override
  String get groupCreateButton => 'Csoport létrehozása';

  @override
  String get groupCreateProgressTitle => 'Csoport létrehozása…';

  @override
  String get groupCreateProgressSubtitle =>
      'A csoport titkosítási készletének és a tagok kapacitásának előkészítése. Ez eltarthat egy pillanatig – kis türelmet.';

  @override
  String groupCreateFailedSnackBar(String error) {
    return 'Sikertelen csoportlétrehozás: $error';
  }

  @override
  String get pairSyncingAwaitingApproval =>
      'Várakozás a barátod jóváhagyására...';

  @override
  String get pairSyncingCoordinating =>
      'Nyilvános kulcsok cseréjének előkészítése...';

  @override
  String get pairSyncingStep1 => 'Biztonságos kapcsolat kiépítése...';

  @override
  String get pairSyncingStep2 => 'Crypto fájl generálása...';

  @override
  String pairSyncingStep3(String seed) {
    return 'Nyilvános kulcsok cseréje... $seed';
  }

  @override
  String get pairSyncingStep4 => 'Biztonságos csevegőkulcsok generálása...';

  @override
  String get pairSyncingStep5 => 'Kulcs integritásának ellenőrzése...';

  @override
  String get pairSyncingStep6 =>
      'Biztonságos beállítás sikeresen befejeződött.';

  @override
  String chatRemainingLabel(String bytes) {
    return '$bytes maradt';
  }

  @override
  String get chatLockedLabel =>
      'Zárolva · párosítsd személyesen a folytatáshoz';

  @override
  String get chatMessageHint => 'Üzenet';

  @override
  String get chatVoiceComingSoon => 'A hangüzenetek hamarosan jönnek.';

  @override
  String get chatVoiceHoldHint => 'Tartsd nyomva hangüzenet rögzítéséhez.';

  @override
  String get chatVoiceReleaseCancel => 'Engedd el a megszakításhoz';

  @override
  String get chatVoiceSlideToCancel => 'Csúsztasd a megszakításhoz';

  @override
  String get chatVoiceSlideToLock => 'Csúsztasd fel a zároláshoz';

  @override
  String get chatVoiceCancel => 'Felvétel megszakítása';

  @override
  String get chatVoiceSend => 'Hangüzenet küldése';

  @override
  String get chatVoicePermissionDenied =>
      'A hangüzenetek rögzítéséhez mikrofon-engedély szükséges.';

  @override
  String get chatVoiceQualityLofi => 'Lo-fi';

  @override
  String get chatVoiceQualityVoice => 'Hang';

  @override
  String get chatVoiceQualityClear => 'Tiszta';

  @override
  String get chatVoiceUnavailable => 'A hangüzenet nem érhető el';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return 'A hangüzenet túl nagy ($cost) a fennmaradó helyhez ($charge).';
  }

  @override
  String get chatDetailsDeleteConfirmTitle => 'Törlöd a csevegést?';

  @override
  String get chatDetailsDeleteConfirmBody =>
      'Ez véglegesen törli a kapcsolathoz tartozó összes üzenetet és titkosító kulcsot. Ez a művelet nem vonható vissza.';

  @override
  String get chatDetailsDeleteConfirmButton => 'Csevegés törlése';

  @override
  String get chatsActionArchive => 'Archiválás';

  @override
  String get chatsActionNuke => 'Csevegés és kulcsok törlése';

  @override
  String get chatsActionDelete => 'Törlés';

  @override
  String get chatsArchivedBadge => 'Archiválva';

  @override
  String get chatsArchivedSubtitle => 'Archiválva · csak olvasható';

  @override
  String get chatsArchiveConfirmTitle => 'Archiválod a csevegést?';

  @override
  String get chatsArchiveConfirmBody =>
      'Ez helyet szabadít fel azáltal, hogy törli a csevegés egyszer használatos kulcsát. Az üzeneteid olvashatók maradnak, de a csevegés csak olvashatóvá válik — többé nem küldhetsz és nem fogadhatsz benne üzenetet.';

  @override
  String get chatsArchiveConfirmButton => 'Archiválás';

  @override
  String get chatsActionPin => 'Rögzítés';

  @override
  String get chatsActionUnpin => 'Rögzítés feloldása';

  @override
  String get chatsFilterAll => 'Összes';

  @override
  String get chatsFilterDirect => 'Közvetlen';

  @override
  String get chatsFilterGroups => 'Csoportok';

  @override
  String get chatsSectionArchived => 'Archiválva';

  @override
  String groupTapForDetails(String hostName) {
    return 'Koppints a részletekért · Házigazda: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    return '$count szabad sávhely elérhető';
  }

  @override
  String get groupHost => 'Házigazda';

  @override
  String get groupMember => 'Tag';

  @override
  String get groupDepleted => 'Kimerült';

  @override
  String get groupNotYetMet => 'Még nem találkoztatok';

  @override
  String get groupRechargeButton => 'Csoport újratöltése';

  @override
  String get groupRechargeTitle => 'Újratöltöd a csoportot?';

  @override
  String get groupRechargeBody =>
      'Újratölti a chatet egy új kulccsal, az üzenetelőzmények megmaradnak, de minden tagnak újra találkoznia kell veled hogy újracsatlakozzanak';

  @override
  String get groupRechargeConfirm => 'Újratöltés';

  @override
  String get groupRechargeDone =>
      'Csoport újratöltve — találkozz újra a tagokkal az újrafelvételükhöz.';

  @override
  String get groupRechargeNeededComposer =>
      'A házigazda újratöltötte a csoportot — találkozz vele újra az újracsatlakozáshoz';

  @override
  String get groupTimeWiltToggle => 'Time Wilt csoport';

  @override
  String get groupTimeWiltToggleSub =>
      'Korlátozott idő, korlátlan keret. A csoport írásvédetté válik, ha az időzítő lejár; találkozz újra a házigazdával a megújításhoz.';

  @override
  String get groupTimeWiltMembersLabel => 'Max. taglétszám';

  @override
  String get groupTimeWiltMembersUpsell => 'Akár 100 tag a Plus csomaggal';

  @override
  String get groupTimeWiltHostInfinite => 'Házigazda · ∞';

  @override
  String get groupTimeWiltRenewComposer =>
      'Lejárt — találkozz a házigazdával a hozzáférés megújításához';

  @override
  String get groupTimeWiltHostAllWilted =>
      'Minden tagnak lejárt az ideje — találkozz valakivel a csoport újraindításához';

  @override
  String get groupNukeProposeButton => 'Megsemmisítés javaslata mindenkinek';

  @override
  String get groupNukeProposeTitle => 'Csoport megsemmisítése mindenkinek?';

  @override
  String get groupNukeProposeBody =>
      'Szavazást indít a tagok között. Többségi döntés esetén a csoport és előzményei minden eszközről törlődnek. Nem vonható vissza.';

  @override
  String get groupNukeProposeConfirm => 'Javaslat';

  @override
  String get groupNukeVoteTitle => 'Csoport megsemmisítése?';

  @override
  String get groupNukeVoteBody =>
      'Egy tag javasolta a csoport törlését mindenki számára. Többség esetén minden eszközről törlődik.';

  @override
  String get groupNukeVoteAllow => 'Egyetértek';

  @override
  String get groupNukeVoteDeny => 'Megtartás';

  @override
  String get groupNukeVotePending => 'Várakozás a tagok szavazataira…';

  @override
  String get groupNukeVotePassed =>
      'A csoport többségi szavazással megsemmisült.';

  @override
  String get groupNukeVoteFailed =>
      'A csoport törlésére tett javaslat nem kapott többséget.';

  @override
  String get groupNukeVoteSent =>
      'Javaslat elküldve — várakozás a tagok szavazatára.';

  @override
  String get activityTitle => 'Aktivitás';

  @override
  String get activityEmpty =>
      'Nincs korábbi aktivitás. Az olyan események, mint a csevegés törlése, itt jelennek meg.';

  @override
  String get activityClear => 'Törlés';

  @override
  String get activityClearConfirmTitle => 'Aktivitáslista törlése?';

  @override
  String get activityClearConfirmBody =>
      'Eltávolítja az összes bejegyzést erről az eszközről. Nem vonható vissza.';

  @override
  String get eventNukeReceivedTitle => 'Csevegés megsemmisült';

  @override
  String get eventNukeReceivedBody => 'Egy biztonságos csevegés megsemmisült.';

  @override
  String get eventGroupNukedTitle => 'Csoport megsemmisült';

  @override
  String get eventGroupNukedBody => 'Egy biztonságos csoport megsemmisült.';

  @override
  String eventContactRequestTitle(String name) {
    return '$name kapcsolatkérelmet küldött neked';
  }

  @override
  String get eventContactRequestBody =>
      'Koppints az elfogadáshoz vagy az elutasításhoz a csevegésben';

  @override
  String eventContactRemovedTitle(String name) {
    return '$name eltávolított téged';
  }

  @override
  String get eventContactRemovedBody => 'Eltávolított a kapcsolatai közül';

  @override
  String groupSyncingFromMember(String name) {
    return 'Részletek és üzenetek szinkronizálása a következő tagtól: $name...';
  }

  @override
  String get groupInviteMember => 'Tag meghívása';

  @override
  String get groupLeaveGroup => 'Csoport elhagyása';

  @override
  String get groupRemoveMember => 'Tag eltávolítása';

  @override
  String get groupRemoveMemberTitle => 'Eltávolítod a tagot?';

  @override
  String groupRemoveMemberBody(String name) {
    return 'Eltávolítod $name(-t) a csoportból? Ez törli a hozzá tartozó kulcsot.';
  }

  @override
  String get groupLeaveGroupTitle => 'Elhagyod a csoportot?';

  @override
  String get groupLeaveGroupBody =>
      'Elhagyod ezt a csoportot? Ez törli a helyi kulcsokat és naplókat.';

  @override
  String get groupSyncStepText => 'Szinkronizálás';

  @override
  String get groupDecryptingImage => 'Kép visszafejtése...';

  @override
  String get chatFileTapToDownload => 'Koppints a letöltéshez';

  @override
  String get chatFileDownloadFailed => 'Koppints az újrapróbáláshoz';

  @override
  String get chatFileKindPhoto => 'Fénykép';

  @override
  String get chatFileKindVoice => 'Hangüzenet';

  @override
  String get chatFileKindFile => 'Fájl';

  @override
  String get groupTapToRevealImage => 'Koppints a kép megjelenítéséhez';

  @override
  String groupImageSize(String size) {
    return 'Méret: $size';
  }

  @override
  String get groupImageFailedToLoad => 'A kép betöltése sikertelen';

  @override
  String get groupScreenshotWipeButton => 'Összes kulcs megsemmisítése most';

  @override
  String get groupRefillGranted => 'A sáv újratöltése sikeresen engedélyezve.';

  @override
  String groupRefillFailed(String error) {
    return 'Nem sikerült az újratöltés engedélyezése: $error';
  }

  @override
  String get groupLaneDepleted => 'Sáv kimerült';

  @override
  String get groupLaneDepletedExplanation =>
      'Kérj sávújratöltést a csoport házigazdájától.';

  @override
  String get groupRefillRequestSent =>
      'Újratöltési kérés elküldve a házigazdának.';

  @override
  String get groupRequestRefill => 'Újratöltés kérése';

  @override
  String groupExceedsSizeLimit(int size) {
    return 'Meghaladja a méretkorlátot ($size B)';
  }

  @override
  String get groupDetailsTitle => 'Csoport részletei';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return 'Megosztott terület · Házigazda: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => 'Csoportszabályzatok';

  @override
  String get groupDetailsSavePoliciesButton => 'Szabályzatok mentése';

  @override
  String get groupDetailsSavePoliciesSnackBar => 'Csoportszabályzatok mentve.';

  @override
  String get groupDetailsSectionEmojis => 'Egyedi emojik';

  @override
  String get groupDetailsSectionMetadata => 'Metaadat-terület';

  @override
  String get groupDetailsMetadataExplanation =>
      'A megosztott terület 0. slotja 1 MB-ot tart fenn a csoport metaadatainak — a csoport ikonja, a taglista és az egyedi emojik itt találhatók.';

  @override
  String get groupDetailsSectionSync => 'Csoport szinkronizálása';

  @override
  String get groupDetailsSyncExplanation =>
      'Kérd le a legújabb csoportrészleteket, szabályzatokat és taglistát a házigazdától.';

  @override
  String get groupDetailsSyncButton => 'Részletek szinkronizálása';

  @override
  String get groupDetailsSyncSnackBar =>
      'Csoportfrissítés lekérve a házigazdától.';

  @override
  String get groupDetailsSectionDestructive => 'Veszélyes beállítások';

  @override
  String get groupDetailsLeaveButton => 'Csoport elhagyása';

  @override
  String get groupDetailsNukeButton => 'Csoport törlése';

  @override
  String get groupDetailsDeleteConfirmTitle => 'Törlöd a csoportot?';

  @override
  String get groupDetailsDeleteConfirmBody =>
      'Ez véglegesen törli ezt a csoportot, valamint törli az összes tag csevegési előzményét és kulcsait. Ez a művelet nem vonható vissza.';

  @override
  String get groupDetailsDeleteConfirmButton => 'Csoport törlése';

  @override
  String get chatImageCompressionTitle => 'Kép tömörítése';

  @override
  String chatImageCompressionOriginal(String size) {
    return 'Eredeti: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return 'Becsült: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return 'Becsült: $size (megtakarítás ~$saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return 'Költség levonás: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation =>
      'WebP formátumba konvertálva, max 2000px.';

  @override
  String get chatImageCompressionLowSize => 'Kis méret';

  @override
  String get chatImageCompressionHighSize => 'Nagy';

  @override
  String get chatImageCompressionMaxQuality => 'Legjobb minőség';

  @override
  String get chatImageCompressionUncompressed => 'Tömörítetlen';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return '$percent% minőség';
  }

  @override
  String get chatImageCompressionSendHidden =>
      'Rejtett küldés (koppintásra jelenik meg)';

  @override
  String get chatImageCompressionSendButton => 'Küldés';

  @override
  String get groupGrantRefill => 'Újratöltés engedélyezése';

  @override
  String get groupLaneLocked => 'Zárolva · elfogyott a bájt';

  @override
  String get groupMembersTitle => 'Csoporttagok';

  @override
  String get groupMembersExplanation =>
      'Minden tag osztozik egy sávokra osztott csevegési méreten. Az üzenetek a szerveren keresztül mennek.';

  @override
  String get pairChatSize => 'Csevegés mérete';

  @override
  String get chatSystemConnected => 'Csatlakozva. A csevegés biztonságos.';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return 'Csatlakoztál a(z) \"$groupName\" csoporthoz. A kapcsolat biztonságos.';
  }

  @override
  String get themeCyberpunkName => 'Neon Rács';

  @override
  String get themeCyberpunkDesc =>
      'A klasszikus. Obszidián, világító ciánkék, terminál stílus.';

  @override
  String get themeGardenName => 'Alkony Kert';

  @override
  String get themeGardenDesc =>
      'Lágy földszínek, meleg vászon, szirmok a csevegéshez.';

  @override
  String get themePaperinkName => 'Papír és Tinta';

  @override
  String get themePaperinkDesc =>
      'Meleg washi papír, sumi tinta árnyalatai, cinóbervörös hanko pecsét.';

  @override
  String get themePickerPlayExclusive =>
      'Ez a téma csak a WiltKey Play Áruház-verziójában érhető el.';

  @override
  String get themePreviewTooltip => 'Előnézet';

  @override
  String get themePreviewSectionDashboard => 'Csevegőlista';

  @override
  String get themePreviewSectionChat => 'Beszélgetés';

  @override
  String get themePreviewSectionEffects => 'Különleges effektek';

  @override
  String get themePreviewPlayUnlock => 'Feloldó animáció lejátszása';

  @override
  String get themePreviewPlayNuke => 'Önmegsemmisítő animáció lejátszása';

  @override
  String get themePreviewApply => 'Téma használata';

  @override
  String get themePreviewGetInShop => 'Beszerzés a boltban';

  @override
  String get themePreviewMsgThem1 =>
      'Már csak 800 bájt maradt a padunkon, találkozunk?';

  @override
  String get themePreviewMsgMe =>
      'Persze! Filmest nálam? Közben fel is töltjük';

  @override
  String get themePreviewMsgThem2 => 'oké, viszek nasit 🍿';

  @override
  String get themePreviewRowPhoto => 'Fotó a boulderteremből 🧗';

  @override
  String get themePreviewRowLost =>
      'Elfogyott a pad — találkozz a feltöltéshez';

  @override
  String get themePreviewSectionProfile => 'Profil háttér';

  @override
  String get themePreviewFullscreenProfile =>
      'Teljes képernyős profil előnézet';

  @override
  String get linkWarningTitle => 'Külső hivatkozás';

  @override
  String get linkWarningBody =>
      'Külső hivatkozást készülsz megnyitni a böngésződben. Ez kapcsolatot létesít a célszerverrel, és felfedi az IP-címedet.';

  @override
  String get linkWarningOpen => 'Megnyitás böngészőben';

  @override
  String get linkWarningCopy => 'Hivatkozás másolása';

  @override
  String get linkWarningCopied => 'Hivatkozás a vágólapra másolva';

  @override
  String get chatActionEdit => 'Szerkesztés';

  @override
  String get chatActionDelete => 'Törlés';

  @override
  String get chatEditingBanner => 'Üzenet szerkesztése';

  @override
  String get chatCancelEdit => 'Szerkesztés elvetése';

  @override
  String get chatDeleteTitle => 'Üzenet törlése';

  @override
  String get chatDeleteBody =>
      'Biztosan törlöd ezt az üzenetet mindenki számára?';

  @override
  String get chatDeleteConfirm => 'Törlés';

  @override
  String get chatMessageDeleted => '[Üzenet törölve]';

  @override
  String get chatEditedTag => 'szerkesztve';

  @override
  String get accessibilityWarningTitle => 'Kisegítő szolgáltatás aktív';

  @override
  String accessibilityWarningBody(String names) {
    return 'Egy kisegítő szolgáltatás, amely képes olvasni a képernyő tartalmát, aktív: $names. Ez normális az olyan eszközöknél, mint a képernyőolvasók vagy jelszókezelők. Ha nem te kapcsoltál be ilyet, ellenőrizd a kisegítő lehetőségek beállításait.';
  }

  @override
  String get accessibilityWarningDismiss => 'Bezárás';

  @override
  String get accessibilityWarningOpenSettings => 'Beállítások megnyitása';

  @override
  String get chatImageCompressionAllowDownload =>
      'Mentés engedélyezése a galériába';

  @override
  String get chatImageCompressionWilting =>
      'Elhervadó kép (megnyitás után eltűnik)';

  @override
  String get chatImageDownload => 'Letöltés';

  @override
  String get chatImageSaveAs => 'Mentés másként';

  @override
  String get chatImageSavedToGallery => 'Elmentve a galériába';

  @override
  String get chatImageSaveFailed => 'A kép mentése nem sikerült';

  @override
  String get chatImageSourceTitle => 'Fotó küldése';

  @override
  String get chatImageSourceCamera => 'Fotó készítése';

  @override
  String get chatImageSourceGallery => 'Választás a galériából';

  @override
  String get screenshotRequestTooltip => 'Képernyőkép kérése';

  @override
  String get screenshotWaiting => 'Várakozás jóváhagyásra…';

  @override
  String get screenshotConsentTitle => 'Képernyőkép kérése';

  @override
  String screenshotConsentBody(String name) {
    return '$name el szeretné menteni a beszélgetés képernyőképét. Engedélyezed?';
  }

  @override
  String get screenshotDenied => 'A képernyőkép kérését elutasították.';

  @override
  String get screenshotCaptureFailed =>
      'A képernyőkép elkészítése nem sikerült.';

  @override
  String get screenshotWatermark => 'WiltKey — Képernyőkép beleegyezéssel';

  @override
  String screenshotRequestInline(String name) {
    return '$name képernyőképet kért';
  }

  @override
  String get screenshotRequestAllowed => 'Engedélyezted a képernyőképet';

  @override
  String get screenshotRequestDeclined => 'Elutasítottad a képernyőképet';

  @override
  String get screenshotRequestExpired => 'A képernyőkép-kérés lejárt';

  @override
  String get wiltingTapToReveal =>
      'Koppints az elhervadó üzenet megtekintéséhez';

  @override
  String get wiltingMessageTag => 'Elhervadó üzenet';

  @override
  String get wiltedMessage => 'Elhervadt üzenet';

  @override
  String get wiltingSheetTitle => 'Elhervadó üzenet';

  @override
  String get wiltingSheetBody =>
      'Az üzenet ennyi másodperccel azután tűnik el, hogy a címzett megnyitotta.';

  @override
  String get wiltingSheetSend => 'Elhervadó üzenet küldése';

  @override
  String get wiltingHoldToSendHint =>
      'Tartsd nyomva elhervadó üzenet küldéséhez';

  @override
  String get replyYou => 'Te';

  @override
  String get replySomeone => 'Valaki';

  @override
  String get replyPreviewImage => '📷 Fotó';

  @override
  String get replyPreviewVoice => '🎤 Hangüzenet';

  @override
  String get replyPreviewMessage => 'Üzenet';

  @override
  String get replyUnavailable => 'Az eredeti üzenet nem érhető el';

  @override
  String get shopEntryTitle => 'Bolt és WiltKey Plus';

  @override
  String get shopEntrySubtitle => 'Témák, tartalmak és Plus';

  @override
  String get supportEntryTitle => 'Támogasd a projektet';

  @override
  String get supportEntrySubtitle => 'Segíts fenntartani a WiltKey-t';

  @override
  String get shopTitle => 'Bolt';

  @override
  String get supportTitle => 'WiltKey támogatása';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => 'Tartalmak';

  @override
  String get shopPlusTagline =>
      'Hosszabb offline üzenettárolás és nagyobb fájlküldés.';

  @override
  String get shopEmptyTitle => 'Itt még nincs semmi';

  @override
  String get shopEmptyBody =>
      'A termékek hamarosan érkeznek — nézz vissza később.';

  @override
  String get shopRestoreButton => 'Vásárlások visszaállítása';

  @override
  String get shopRestoredSnack => 'Vásárlások visszaállítva';

  @override
  String get shopBuyButton => 'Megvásárlás';

  @override
  String get shopOwnedLabel => 'Megvéve';

  @override
  String get shopActiveLabel => 'Aktív';

  @override
  String get shopManageNote => 'Kezelés a Google Play-ben';

  @override
  String get shopPurchasePendingSnack => 'Vásárlás folyamatban…';

  @override
  String get shopPurchaseFailedSnack => 'A vásárlás nem sikerült';

  @override
  String get supportIntro =>
      'A WiltKey ingyenes és nyílt forráskódú, és ebben a változatban minden kozmetikai elem ingyenesen elérhető. Ha szeretnéd támogatni a fejlesztést és a hivatalos relayt, látogasd meg az alábbi oldalt.';

  @override
  String get supportOpenButton => 'Támogatói oldal megnyitása';

  @override
  String get supportFreeNote =>
      'Ebben a változatban minden kozmetikai elem fel van oldva.';

  @override
  String get shopTabPalettes => 'Paletták';

  @override
  String get shopTabThemes => 'Témák';

  @override
  String get shopTabBorders => 'Keretek';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'Promó';

  @override
  String get shopPalettesIntro =>
      'Extra színek az avatarod és a csoportikonok rajzolásához. A kapott képek mindig teljesen megjelennek — a csomag csak azt oldja fel, hogy te is rajzolhass ezekkel a színekkel.';

  @override
  String shopPaletteColorCount(int count) {
    return '$count extra szín';
  }

  @override
  String get shopThemesEmptyTitle => 'Még nincsenek témák';

  @override
  String get shopThemesEmptyBody =>
      'A prémium témák hamarosan érkeznek — a három beépített téma örökre ingyenes.';

  @override
  String get shopBordersSoonTitle => 'A keretek hamarosan jönnek';

  @override
  String get shopBordersSoonBody =>
      'Dekoratív keretek az avatarodhoz, amiket mindenki lát, akivel csevegsz. Fejlesztés alatt.';

  @override
  String get shopPlusBenefitsSection => 'Amit kapsz';

  @override
  String get shopPlusBenefitHold =>
      'Az üzeneteid 72 órán át várnak a relayen 24 helyett, amíg offline vagy.';

  @override
  String get shopPlusBenefitFiles =>
      'Küldj nagy fájlokat – üzenetenként akár 50 MB, az ingyenes 5 MB-os korlát felett.';

  @override
  String get shopPlusBenefitPads =>
      'Készíts nagyobb padokat – akár 200 MB egy csevegéshez és 500 MB egy csoporthoz.';

  @override
  String get shopPlusBenefitTimeWiltGroups =>
      'Nagyobb Time Wilt csoportok indítása — 20 helyett akár 100 tagig.';

  @override
  String get shopPlusBenefitSupport =>
      'Te tartod életben a relayt és teszed függetlenné a WiltKey-t.';

  @override
  String get shopSubscribeButton => 'Előfizetés';

  @override
  String get shopPriceUnavailable => 'Nem elérhető';

  @override
  String get shopPromoIntro =>
      'Van promóciós kódod? Írd be alább, és a Google Play alkalmazza a fiókodra.';

  @override
  String get shopPromoHint => 'PROMÓCIÓS KÓD';

  @override
  String get shopPromoRedeemButton => 'Beváltás a Google Play-ben';

  @override
  String get shopPromoNote =>
      'A kódokat a Play Áruházban lehet beváltani. Az alkalmazás után a feloldás automatikusan megjelenik itt.';

  @override
  String pairLargerPadsUpsell(String max) {
    return 'Nagyobb padok Plusszal — akár $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return 'Nincs elég szabad hely — ehhez a csevegéshez $needed kell, neked pedig $free van.';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return 'Kulcsfolyam generálása… $written / $total';
  }

  @override
  String get pairKeepAppOpen =>
      'Hagyd nyitva az alkalmazást — a biztonságos pad még készül.';

  @override
  String groupLargerPadsUpsell(String max) {
    return 'Nagyobb csoportpadok Plusszal — akár $max';
  }

  @override
  String get settingsBorderSection => 'Avatar keret';

  @override
  String get shopBordersIntro =>
      'Keretek és kiegészítők az avatarodhoz. Mindenki látja a kereted, akivel csevegsz — a zárolt csak azt gátolja, hogy te felvedd, a megjelenítést soha.';

  @override
  String get shopBorderSubtitle => 'Avatar keret';

  @override
  String get shopFreeLabel => 'Ingyenes';

  @override
  String get notificationModePrivate => 'Privát';

  @override
  String get notificationModePrivateDesc =>
      'Időközönként ellenőrzi az új üzeneteket a háttérben, a Google push szolgáltatása nélkül. Az értesítések késhetnek, de semmilyen jel nem megy át harmadik féltől származó szolgáltatáson.';

  @override
  String get connectSectionOneOnOne => 'Személyes chat';

  @override
  String get connectSectionGroups => 'Csoportok';

  @override
  String get connectByteBudgetTitle => 'Bájt keret';

  @override
  String get connectByteBudgetDesc =>
      'Kötetlen idő, korlátozott tárhely. A legjobb régóta ismert barátoknak, családnak és kiemelten biztonságos beszélgetésekhez.';

  @override
  String get connectTimeWiltTitle => 'Time Wilt';

  @override
  String get connectTimeWiltDesc =>
      'Korlátozott idő, korlátlan tárhely. Tökéletes új ismerősöknek, randikhoz vagy gyors találkozókhoz.';

  @override
  String get connectRemotePairTitle => 'Távoli párosítás (teszt)';

  @override
  String get connectRemotePairDesc =>
      'Fejlesztői teszt: párosítás egy tesztelővel a szerveren keresztül PIN és azonosító hash alapján.';

  @override
  String get connectByteBudgetGroupTitle => 'Bájt keretes csoport';

  @override
  String get connectByteBudgetGroupDesc =>
      'Kötetlen idő, korlátozott tárhely. Egy csoport, amit személyes meghívásokkal építesz fel.';

  @override
  String get connectTimeWiltGroupTitle => 'Time Wilt csoport';

  @override
  String get connectTimeWiltGroupDesc =>
      'Korlátozott idő, korlátlan tárhely. Egy laza csoport, ahol az üzenetek idővel lejárnak.';

  @override
  String get connectJoinGroupTitle => 'Csatlakozás csoporthoz';

  @override
  String get connectJoinGroupDesc =>
      'Valaki a közelben meghívott — keresd meg a csoportjának jelét.';

  @override
  String get connectJoinRemoteGroupTitle =>
      'Csatlakozás távoli csoporthoz (teszt)';

  @override
  String get connectJoinRemoteGroupDesc =>
      'Fejlesztői teszt: csatlakozás egy tesztelő csoportjához a szerveren keresztül.';

  @override
  String get connectBadgeSoon => 'HAMAROSAN';

  @override
  String get timeWiltLifetimeLabel => 'Chat élettartama';

  @override
  String get timeWiltPlusHint => 'Oldj fel akár 6 hónapot a Plus-szal';

  @override
  String get timeWiltExplanation =>
      'A chat csak olvashatóvá válik, amint lejár az időzítő.';

  @override
  String timeWiltPairRequestDialogBody(String peerName, String lifetime) {
    return 'Elfogadod a Time Wilt chatet tőle: $peerName? Ennyi idő múlva lesz csak olvasható: $lifetime.';
  }

  @override
  String timeWiltLifetimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nap',
      one: '1 nap',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count óra',
      one: '1 óra',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeMinutes(int count) {
    return '$count perc';
  }

  @override
  String timeWiltLifetimeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hónap',
      one: '1 hónap',
    );
    return '$_temp0';
  }

  @override
  String get timeWiltLifetimeMoments => 'pár pillanat';

  @override
  String get navContacts => 'Névjegyek';

  @override
  String get contactsTitle => 'Névjegyek';

  @override
  String get contactsSectionFriends => 'Barátok';

  @override
  String get contactsEmptyTitle => 'Még nincsenek névjegyek';

  @override
  String get contactsEmptyBody =>
      'Adj hozzá valakit egy létező csevegésből, hogy itt lásd.';

  @override
  String get contactsOwnProfile => 'Saját profilod';

  @override
  String get contactsOwnProfileHint =>
      'Érintsd meg állapot vagy történet megadásához';

  @override
  String contactRequestSent(String name) {
    return 'Kapcsolatfelvételi kérelem elküldve neki: $name';
  }

  @override
  String contactRequestReceived(String name) {
    return '$name szeretne felvenni a névjegyei közé';
  }

  @override
  String get contactRequestApproved => 'Kapcsolatfelvételi kérelem elfogadva';

  @override
  String get contactRequestDeclined => 'Kapcsolatfelvételi kérelem elutasítva';

  @override
  String get contactRequestApprove => 'Elfogadás';

  @override
  String get contactRequestDeny => 'Elutasítás';

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
  String get contactProfileOpenChat => 'Csevegés megnyitása';

  @override
  String get contactProfileRemove => 'Névjegy eltávolítása';

  @override
  String get contactProfileBlock => 'Felhasználó letiltása';

  @override
  String get contactProfileStatusPlaceholder => 'Nincs állapot megadva';

  @override
  String get contactProfileEmergencyChat => 'Vészhelyzeti chat';

  @override
  String get contactPin => 'Rögzítés';

  @override
  String get contactUnpin => 'Rögzítés feloldása';

  @override
  String get contactUnblock => 'Feloldás';

  @override
  String get contactsSectionPinned => 'Rögzítve';

  @override
  String get contactStatusLabel => 'Státusz';

  @override
  String get contactStatusHint => 'Oszd meg a státuszodat a kapcsolataiddal…';

  @override
  String get contactStatusSave => 'Státusz mentése';

  @override
  String get contactStatusUpdated => 'Státusz frissítve';

  @override
  String contactRemoveConfirmTitle(String name) {
    return '$name eltávolítása?';
  }

  @override
  String get contactRemoveConfirmBody =>
      'Eltávolítja őt a névjegyeid közül. Később újra hozzáadhatod.';

  @override
  String contactBlockConfirmTitle(String name) {
    return '$name letiltása?';
  }

  @override
  String get contactBlockConfirmBody =>
      'Nem fog tudni üzenetet vagy kapcsolatfelvételi kérelmet küldeni neked.';

  @override
  String get settingsBlockedContacts => 'Letiltott névjegyek';

  @override
  String get settingsBlockedEmpty => 'Nincsenek letiltott névjegyek';

  @override
  String get commonRemove => 'Eltávolítás';

  @override
  String get commonBlock => 'Letiltás';

  @override
  String get contactProfileChatNotFound =>
      'Nem található csevegés ehhez a névjegyhez — lehet, hogy törölték';

  @override
  String get emergencyChatStart => 'Vészhelyzeti chat indítása';

  @override
  String emergencyChatConfirmTitle(String name) {
    return 'Vészhelyzeti chat indítása ezzel: $name?';
  }

  @override
  String emergencyChatConfirmBody(String name) {
    return 'Nincs aktív chat ezzel: $name. Ez egy 12 órás, távolról létrehozott Time Wilt chatet indít, személyes párosítás nélkül. A meglévő elhervadt chat és üzenetei véglegesen megsemmisülnek, és soha nem tölthetők újra.';
  }

  @override
  String get emergencyChatAlreadyActive =>
      'Már van aktív chated ezzel a kapcsolattal';

  @override
  String get emergencyChatStarted => 'Vészhelyzeti chat elindítva';

  @override
  String get chatsEmergencyPendingSubtitle =>
      'Vészhelyzeti csevegés kapcsolódása…';

  @override
  String chatsEmergencyPendingSnackBar(String name) {
    return 'A vészhelyzeti csevegés $name felével kapcsolódásra vár.';
  }

  @override
  String get emergencyChatPending => 'Vészhelyzeti csevegés folyamatban…';

  @override
  String get gestureSwipeForContacts => 'Húzd el a bal szélről a névjegyekhez';

  @override
  String get contactProfileSafetyNumber => 'Azonosítókulcs ujjlenyomata';

  @override
  String get contactProfileWiltedHint =>
      'Ideiglenes, 12 órás Time Wilt csevegés indítása';

  @override
  String get commonCopy => 'Másolás';

  @override
  String get commonCopied => 'Vágólapra másolva';

  @override
  String eventMentionTitle(String name) {
    return '$name megemlített téged';
  }

  @override
  String eventReplyTitle(String name) {
    return '$name válaszolt neked';
  }

  @override
  String get chatNotificationModeAll => 'Minden üzenet';

  @override
  String get chatNotificationModeMentions => 'Csak említések és válaszok';

  @override
  String get chatNotificationModeMuted => 'Némítás (Csendes)';

  @override
  String get chatNotificationSettingsTitle => 'Értesítések';

  @override
  String get chatMuteTitle => 'Csevegés némítása';

  @override
  String get chatUnmuteTitle => 'Csevegés némításának feloldása';

  @override
  String get settingsNotifyCategories => 'Kategóriák';

  @override
  String get settingsNotifyDirectMessages => 'Közvetlen üzenetek';

  @override
  String get settingsNotifyDirectMessagesSubtitle =>
      'Értesítések 1:1 csevegésekhez';

  @override
  String get settingsNotifyGroupMessages => 'Csoportos üzenetek';

  @override
  String get settingsNotifyGroupMessagesSubtitle =>
      'Értesítések csoportos csevegésekhez';

  @override
  String get settingsNotifyEvents => 'Biztonsági és aktivitási események';

  @override
  String get settingsNotifyEventsSubtitle =>
      'Kapcsolatfelvételi kérelmek, csoportmegsemmisítési szavazások, képernyőkép-riasztások';

  @override
  String get settingsMutedChatsTitle => 'Némított csevegések';

  @override
  String get settingsNoMutedChats => 'Nincsenek némított csevegések';

  @override
  String get settingsUnmute => 'Némítás feloldása';

  @override
  String get settingsCheckForUpdates => 'Frissítések keresése';

  @override
  String get settingsCheckingUpdates => 'Frissítések keresése...';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Frissítés elérhető: v$version';
  }

  @override
  String get settingsUpToDate => 'A WiltKey naprakész';

  @override
  String get settingsWhatsNew => 'Újdonságok';

  @override
  String get settingsStorageSection => 'Tárhely és előzmények';

  @override
  String get settingsHistoryLimitTitle => 'Üzenetelőzmények megőrzése';

  @override
  String get settingsHistoryLimitDescription =>
      'A régebbi helyi üzenetek és médiafájlok automatikus törlése a tárhely megtakarítása érdekében. A titkosítási kulcsok és a kapcsolatok mindig megmaradnak.';

  @override
  String get settingsHistoryLimitAll => 'Minden üzenet megtartása (Korlátlan)';

  @override
  String settingsHistoryLimitCount(int count) {
    return 'Utolsó $count üzenet megtartása';
  }

  @override
  String get chatDetailsClearHistory => 'Üzenetelőzmények törlése';

  @override
  String get chatDetailsClearHistoryConfirm => 'Előzmények törlése';

  @override
  String get chatDetailsClearHistoryDialogBody =>
      'Véglegesen törli az összes helyi üzenetelőzményt ebben a csevegésben? A titkosítási kulcsok és a kapcsolat állapota megmarad.';

  @override
  String get chatDetailsClearHistoryPrune100 =>
      'Csak az utolsó 100 üzenet megtartása';

  @override
  String get chatDetailsClearHistorySuccess => 'Csevegési előzmények törölve';

  @override
  String get chatDetailsSectionMedia => 'Média, hang és hivatkozások';

  @override
  String get chatDetailsMediaPhotos => 'Fotók';

  @override
  String get chatDetailsMediaVoice => 'Hangüzenetek';

  @override
  String get chatDetailsMediaLinks => 'Hivatkozások';

  @override
  String get chatDetailsNoMedia => 'Még nincsenek megosztott fotók';

  @override
  String get chatDetailsNoVoice => 'Még nincsenek hangüzenetek';

  @override
  String get chatDetailsNoLinks => 'Még nincsenek megosztott hivatkozások';

  @override
  String get qrConnectTitle => 'QR-csatlakozás';

  @override
  String get qrConnectScanTab => 'QR beolvasása';

  @override
  String get qrConnectMyCodeTab => 'Saját QR-kódom';

  @override
  String get qrConnectScanPrompt =>
      'Irányítsd a kamerát egy WiltKey QR-kódra az azonnali csatlakozáshoz';

  @override
  String get qrConnect7DayNotice =>
      'A távoli kapcsolatok automatikusan 7 napos Time Wilt csevegésként indulnak. Az egyszeri kulcs újratöltéséhez személyes BLE-párosítás szükséges.';

  @override
  String get qrConnectRechargeBlocked =>
      'Ez a kapcsolat már létezik. A kulcstár újratöltése személyes BLE-párosítást igényel, és nem végezhető el távolról.';

  @override
  String get qrConnectManualPin => 'PIN megadása manuálisan';

  @override
  String get qrConnectShowYourCode =>
      'Beolvasás kész! Most mutasd meg te is a QR-kódodat.';

  @override
  String get qrConnectFinishPairing => 'Párosítás befejezése';

  @override
  String get qrConnectOutdatedCode =>
      'Ez a QR-kód egy régebbi appverzióból van. Mindkettőtöknek a legújabb verzió kell az ilyen kapcsolódáshoz.';

  @override
  String get qrConnectOwnCode =>
      'Ez a saját QR-kódod — inkább az övékére irányítsd a kamerát.';

  @override
  String get qrConnectAlreadyPaired =>
      'Már van csevegésed ezzel a személlyel. Egy meglévő csevegés frissítéséhez személyes párosítás szükséges.';

  @override
  String get testRelayBanner => 'TESZTSZERVER — NEM ÉLES RENDSZER';

  @override
  String get securingTitle => 'Kapcsolat biztosítása';

  @override
  String get securingBody =>
      'Az eszközöd a csatlakozás előtt hitelesíti magát a relénél. Ez az egyszeri proof-of-work mindenkit véd a spamtől és a visszaélésektől — telefonszám, e-mail és fiók nélkül.';

  @override
  String get securingWorking => 'ESZKÖZ HITELESÍTÉSE — FOLYAMATBAN…';

  @override
  String get securingOnceNote =>
      'Ez csak az első csatlakozáskor történik. Az újracsatlakozás utána azonnali.';

  @override
  String get puzzleInstruction =>
      'Csúsztasd, amíg a pixel art szimmetrikus nem lesz.';

  @override
  String get puzzleLockIn => 'Rögzítés';

  @override
  String get puzzleFailedRetry =>
      'Ez nem illeszkedett — új ellenőrzést indítunk…';

  @override
  String get reauthenticatingBanner => 'ÚJRAHITELESÍTÉS — KÉRJÜK, VÁRJ…';

  @override
  String get badgePlayPlus => 'Play Áruház · Plus';

  @override
  String get badgePlayPlusSubtitle =>
      'Ellenőrzött Google Play build + Plus támogató';

  @override
  String get badgePlayPlusExplainer =>
      'Ez a felhasználó hivatalos, módosítatlan buildet használ, amelyet a Google Play Integrity ellenőrzött, és aktív Plus tagsággal támogatja a WiltKeyt.';

  @override
  String get badgePlayVerified => 'Play Áruház';

  @override
  String get badgePlayVerifiedSubtitle => 'Ellenőrzött Google Play build';

  @override
  String get badgePlayVerifiedExplainer =>
      'Ez a felhasználó hivatalos, módosítatlan buildet használ, amelyet a Google Play Integrity kriptográfiailag ellenőrzött.';

  @override
  String get badgeFoss => 'Nyílt forráskód';

  @override
  String get badgeFossSubtitle => 'Közösségi / FOSS build';

  @override
  String get badgeFossExplainer =>
      'Ez a kliens nyílt forráskódú vagy egyéni buildet futtat. Mivel nem futtat zárt forrású Google-szolgáltatásokat, közösségi buildként van kezelve. Minden üzenet és titkosítás 100%-ban biztonságos és privát marad.';

  @override
  String get groupAnonymousMember => 'Tag';

  @override
  String get groupMemberRoleHost => 'Házigazda';

  @override
  String get contactSelfBadge => 'Te';

  @override
  String get chatAttachContentTitle => 'Csatolás a csevegéshez';

  @override
  String get chatAttachPhotos => 'Fotók és kamera';

  @override
  String get chatAttachPhotosSubtitle =>
      'Fotó készítése vagy választás a galériából';

  @override
  String get chatAttachPixelArt => 'Pixel art és avatarok';

  @override
  String get chatAttachPixelArtSubtitle =>
      'Rajzolj pixelrajzot vagy küldj mentett sablonokból';

  @override
  String get chatAttachVideo => 'Videó';

  @override
  String get chatAttachVideoSubtitle =>
      'Titkosított rövid videoklipek egy jövőbeli frissítésben';

  @override
  String get chatAttachComingSoon => 'HAMAROSAN';

  @override
  String get chatPixelArtDrawNew => 'Új pixelrajz készítése';

  @override
  String get chatPixelArtTemplates => 'Mentett avatarsablonok';

  @override
  String get chatPixelArtSend => 'Küldés a csevegésbe';

  @override
  String get chatPixelArtNoTemplates => 'Még nincsenek mentett avatarsablonok';

  @override
  String get chatPixelArtActionTitle => 'Pixel art beállítások';

  @override
  String get chatPixelArtActionApplyAvatar =>
      'Beállítás saját profilavatarként';

  @override
  String get chatPixelArtActionSaveTemplate => 'Mentés az avatarsablonok közé';

  @override
  String get chatPixelArtActionSaveEmoji => 'Mentés egyedi emojiként';

  @override
  String get chatPixelArtActionExportPng => 'PNG exportálása a fotók közé';

  @override
  String get chatPixelArtActionAppliedAvatarSuccess =>
      'Profilavatar frissítve és szinkronizálva';

  @override
  String get chatPixelArtActionSavedTemplateSuccess =>
      'Elmentve az avatarsablonok könyvtárába';

  @override
  String get chatPixelArtActionExportedPngSuccess =>
      'PNG-kép elmentve a fotók közé';

  @override
  String get chatSearchHint => 'Keresés a csevegésben...';

  @override
  String get chatSearchNoMatches => '0 találat';

  @override
  String get contactPrivateNoteTitle => 'Privát jegyzetek és becenév';

  @override
  String get contactPrivateNoteHint =>
      'Privát jegyzetek hozzáadása erről a kapcsolatról (csak helyileg tárolva)...';

  @override
  String get contactCustomNicknameTitle => 'Egyéni becenév';

  @override
  String get contactCustomNicknameHint =>
      'Megjelenített név felülírása helyileg...';

  @override
  String get contactNotesSaved => 'Kapcsolat adatai elmentve';

  @override
  String get onboardingSocialTitle => 'WiltKey közösségi fiók';

  @override
  String get onboardingSocialExplanation =>
      'Engedélyezi a WiltKey közösségi profilodat és a szerver által támogatott felderítést. A nyilvános azonosító kulcsod regisztrálva lesz a relayen (és bármikor véglegesen visszavonható/törölhető általad) a 24 órás elhervadó történetek és a broadcast bejegyzések szerzőségének ellenőrzéséhez. Minden tartalom zero-knowledge végpontok közötti titkosítással védett marad.';

  @override
  String get onboardingSocialEnable =>
      'WiltKey közösségi fiók engedélyezése (Ajánlott)';

  @override
  String get onboardingSocialEnableDesc =>
      'Ossz meg 24 órás elhervadó történeteket közös kapcsolataiddal, küldj egyedi pixelrajzokat és vegyél részt a közösségi broadcastokban.';

  @override
  String get onboardingSocialZeroServer =>
      'Zéró szerveradat mód (Abszolút adatvédelem)';

  @override
  String get onboardingSocialZeroServerDesc =>
      'Maximális anonimitás. Szigorúan közvetlen peer-to-peer és 1:1/csoportos üzenetküldés szerveroldali identitásregisztráció nélkül. A távoli közösségi funkciók és történetek le vannak tiltva.';

  @override
  String get settingsSocialAccountTitle => 'WiltKey közösségi fiók';

  @override
  String get settingsSocialAccountSubtitle =>
      'Szerver által támogatott 24 órás történetek és felderítés engedélyezése';

  @override
  String get settingsStoriesReelTitle => 'Vezérlőpult történetek sáv';

  @override
  String get settingsStoriesReelSubtitle =>
      '24 órás történetek megjelenítése a csevegések fül tetején';

  @override
  String get connectTabConnect => 'Kapcsolódás';

  @override
  String get connectTabSocial => 'Közösség';

  @override
  String get forcedUpdateTitle => 'Frissítés szükséges';

  @override
  String get forcedUpdateSubtitle =>
      'A WiltKey biztonságos használatának folytatásához kötelező frissítés szükséges.';

  @override
  String get forcedUpdateAction => 'Frissítés most';

  @override
  String get forcedUpdateCheckAgain => 'Újraellenőrzés';

  @override
  String get forcedUpdateSecurityNotice =>
      'Ez a verzió kritikus protokoll- vagy biztonsági frissítéseket tartalmaz. A régebbi verziók már nem tudnak kommunikálni a hálózattal.';

  @override
  String get forcedUpdateWhatsNew => 'Újdonságok ebben a frissítésben';

  @override
  String get settingsSwipeGesturesTitle => 'Csevegési húzási gesztusok';

  @override
  String get settingsSwipeGesturesSubtitle =>
      'A jobbra és balra húzási műveletek testreszabása a csevegéslistában';

  @override
  String get settingsSwipeRight => 'Húzás jobbra';

  @override
  String get settingsSwipeLeft => 'Húzás balra';

  @override
  String get swipeActionMarkRead => 'Olvasott / Olvasatlan';

  @override
  String get swipeActionMute => 'Némítás / Feloldás';

  @override
  String get swipeActionPin => 'Rögzítés / Feloldás';

  @override
  String get swipeActionArchive => 'Archiválás';

  @override
  String get swipeActionNone => 'Letiltva';

  @override
  String get chatSwipeMarkRead => 'Olvasott';

  @override
  String get chatSwipeMarkUnread => 'Olvasatlan';

  @override
  String get chatSwipePin => 'Rögzítés';

  @override
  String get chatSwipeUnpin => 'Rögzítés feloldása';

  @override
  String get chatSwipeMute => 'Némítás';

  @override
  String get chatSwipeUnmute => 'Némítás feloldása';

  @override
  String get chatSwipeArchive => 'Archiválás';

  @override
  String get chatAttachVideoSubtitleEnabled =>
      'Legfeljebb 15 mp rögzítése vagy választás a galériából';

  @override
  String get chatVideoSelectSourceTitle => 'Videó küldése';

  @override
  String get chatVideoQualityLabel => 'Minőség';

  @override
  String get chatVideoQualityLow => 'Alacsony';

  @override
  String get chatVideoQualityMedium => 'Közepes';

  @override
  String get chatVideoQualityHigh => 'Magas';

  @override
  String get chatVideoCompressionFailed =>
      'Nem sikerült tömöríteni a klipet. Próbálj rövidebb klipet vagy alacsonyabb minőséget választani.';

  @override
  String get chatVideoRecordCamera => 'Videó rögzítése (Kamera)';

  @override
  String get chatVideoPickGallery => 'Videó választása a galériából';

  @override
  String get chatVideoCompressing => 'Videó tömörítése...';

  @override
  String chatVideoTooLarge(String size) {
    return 'A videó meghaladja a méretkorlátot ($size)';
  }

  @override
  String get chatVideoTooLong =>
      'A videó meghaladja a 15 másodperces időkorlátot';

  @override
  String get chatVideoSaveGallery => 'Videó mentése a galériába';

  @override
  String get chatVideoSavedGallery => 'Videó elmentve a galériába';

  @override
  String get chatVideoError => 'A videoklip nem játszható le';
}
