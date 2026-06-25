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
  String get navPair => 'Párosítás';

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
  String get settingsProfileBrushColor => 'Ecset színe';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Törlés';

  @override
  String get settingsProfileChipRandom => 'Véletlenszerű';

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
      'Körülbelül 10 percenként ellenőrzi az új üzeneteket. Kíméli az akkumulátort.';

  @override
  String get notificationModeInstant => 'Azonnali';

  @override
  String get notificationModeInstantDesc =>
      'Aktívan tart egy biztonságos kapcsolatot a háttérben az azonnali riasztásokért. Állandó értesítést mutat, és több akkumulátort fogyaszt.';

  @override
  String get notificationNewMessageBody => 'Új üzeneted érkezett';

  @override
  String get notificationSecureLinkActive => 'Értesítési kapcsolat aktív';

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
      'Az ujjlenyomatoddal oldhatod fel a PIN helyett. 4 óra inaktivitás után újra a PIN szükséges.';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Nem sikerült bekapcsolni az ujjlenyomatos feloldást.';

  @override
  String get pinForgotButton => 'Elfelejtetted a PIN-kódot? Adatok Törlése';

  @override
  String get pairTitle => 'Eszközök párosítása';

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
  String get chatTapForDetails => 'Koppints a részletekért';

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
}
