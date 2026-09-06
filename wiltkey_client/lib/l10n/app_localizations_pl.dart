// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get navChats => 'Czaty';

  @override
  String get navPair => 'Połącz';

  @override
  String get navSettings => 'Ustawienia';

  @override
  String get nukedTitle => 'Reset urządzenia';

  @override
  String get nukedExplanation =>
      'Wszystkie wiadomości i klucze zostały usunięte z tego urządzenia. Bezpieczna baza danych została wyczyszczona.';

  @override
  String get nukedResetButton => 'Utwórz nową tożsamość';

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get commonClose => 'Zamknij';

  @override
  String get commonSave => 'Zapisz';

  @override
  String get commonBack => 'Wstecz';

  @override
  String get commonContinue => 'Dalej';

  @override
  String get commonFinish => 'Zakończ';

  @override
  String get onboardingWelcomeTitle => 'Witaj w Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'Witaj w Wiltkey to prywatny komunikator, który nie zapisuje metadanych, logów ani historii serwera. Wiadomości są szyfrowane lokalnie i ulegają samozniszczeniu po zrobieniu zrzutu ekranu.';

  @override
  String get onboardingWelcomeNoHistory =>
      'Brak historii serwera. Brak kluczy odzyskiwania.';

  @override
  String get onboardingIntelTitle => 'Informacje o bezpieczeństwie';

  @override
  String get onboardingLanguageDescription =>
      'Wybierz język, aby kontynuować. Możesz go zmienić w dowolnym momencie w Ustawieniach.';

  @override
  String get onboardingFactLanguageTitle => 'Wybór języka';

  @override
  String get onboardingFactLanguageBody =>
      'Wybierz język, aby kontynuować. Możesz go zmienić w dowolnym momencie w Ustawieniach. Twój wybór jest zapisywany lokalnie.';

  @override
  String get onboardingThemeTitle => 'Wybierz motyw';

  @override
  String get onboardingThemeDescription =>
      'Wybierz motyw poniżej. Możesz go zmienić później w Ustawieniach.';

  @override
  String get onboardingProfileTitle => 'Twoja tożsamość';

  @override
  String get onboardingProfileUsernameLabel => 'Nazwa użytkownika';

  @override
  String get onboardingProfileUsernameHint => 'Wpisz nazwę użytkownika';

  @override
  String get onboardingProfileCodenameLabel => 'Kod połączenia (5 liter/cyfr)';

  @override
  String get onboardingProfileCodenameExplanation =>
      'Ten kod jest udostępniany podczas parowania, aby połączyć się ze znajomymi w pobliżu.';

  @override
  String get onboardingProfileUsernameError =>
      'Proszę ustawić nazwę użytkownika.';

  @override
  String get onboardingProfileCodenameError =>
      'Kod połączenia musi mieć dokładnie 5 znaków.';

  @override
  String get onboardingAvatarTitle => 'Avatar pikselowy';

  @override
  String get onboardingAvatarBrushColor => 'Kolor pędzla';

  @override
  String get onboardingAvatarRandom => 'Losowo';

  @override
  String get onboardingAvatarClear => 'Wyczyść';

  @override
  String get onboardingPinTitle => 'Kod PIN';

  @override
  String get onboardingPinExplanation =>
      'Ustaw kod PIN (4–6 cyfr), aby chronić swoje czaty. Będziesz musiał wpisać ten PIN przy każdym otwarciu aplikacji. Jeśli go zapomnisz, wiadomości nie będzie można odzyskać.';

  @override
  String get onboardingPinEnter => 'Wpisz PIN';

  @override
  String get onboardingPinConfirm => 'Potwierdź PIN';

  @override
  String get onboardingPinLengthError => 'PIN musi mieć od 4 do 6 cyfr.';

  @override
  String get onboardingPinMatchError => 'Kody PIN nie są zgodne.';

  @override
  String onboardingSetupFailed(String error) {
    return 'Błąd konfiguracji: $error';
  }

  @override
  String get onboardingFactMetadataTitle => 'PROBLEM Z METADANYMI';

  @override
  String get onboardingFactMetadataBody =>
      'Większość komunikatorów szyfruje treść wiadomości, ale nadal śledzi, z kim, kiedy i jak często rozmawiasz. Wiltkey nie zapisuje żadnych metadanych, danych serwera ani połączeń.';

  @override
  String get onboardingFactThemeTitle => 'WYBIERZ MOTYW';

  @override
  String get onboardingFactThemeBody =>
      'Motywy mają charakter kosmetyczny. Te same standardy bezpieczeństwa dotyczą każdego motywu. Możesz go zmienić w dowolnym momencie w Ustawieniach.';

  @override
  String get onboardingFactOtpTitle => 'IDEALNA TAJEMNICA';

  @override
  String get onboardingFactOtpBody =>
      'Wiltkey używa szyfrów jednorazowych (OTP), w których klucze odpowiadają wielkości wiadomości, są całkowicie losowe i nigdy nie są ponownie używane. Zapewnia to matematycznie idealne bezpieczeństwo, uniemożliwiając odszyfrowanie wiadomości bez kluczy.';

  @override
  String get onboardingFactLimitsTitle => 'LIMIT POŁĄCZEŃ';

  @override
  String get onboardingFactLimitsBody =>
      'Limity pojemności czatu zostały zaprojektowane, aby zachęcać do budowania wartościowych relacji. Ograniczenie pojemności sprawia, że rozmowy są celowe i zakorzenione w kontaktach z realnego świata.';

  @override
  String get onboardingFactKdfTitle => 'HASZOWANIE BEZPIECZEŃSTWA';

  @override
  String get onboardingFactKdfBody =>
      'Zwykły PIN można złamać metodą brute-force w milisekundach. Wiltkey przetwarza twój PIN przez funkcję utwardzającą, uniemożliwiając ataki brute-force na lokalną bazę danych.';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsTabProfile => 'Profil';

  @override
  String get settingsTabSecurity => 'Bezpieczeństwo';

  @override
  String get settingsSecuritySectionAccess => 'Dostęp i odblokowanie';

  @override
  String get settingsSecuritySectionDanger => 'Strefa zagrożenia';

  @override
  String get settingsTabNetwork => 'Sieć';

  @override
  String get settingsTabAlerts => 'Powiadomienia';

  @override
  String get settingsSavedIndicator => 'Zapisano';

  @override
  String get settingsProfileSectionAppearance => 'Wygląd';

  @override
  String get settingsProfileSectionAvatar => 'Avatar Pixel Art';

  @override
  String get settingsProfileSectionProfile => 'Ustawienia profilu';

  @override
  String get settingsProfileSectionOtherVisuals => 'Inne wizualne';

  @override
  String get settingsThemeLabel => 'Motyw';

  @override
  String get settingsPixelArtEditor => 'Edytor pixel art';

  @override
  String get settingsProfileBrushColor => 'Kolor pędzla';

  @override
  String get settingsProfileChipIdenticon => 'Identikon';

  @override
  String get settingsProfileChipClear => 'Wyczyść';

  @override
  String get settingsProfileChipRandom => 'Losowo';

  @override
  String get settingsProfileChipTemplateSave => 'Zapisz jako szablon';

  @override
  String get settingsProfileTemplateSaved => 'Zapisano w szablonach';

  @override
  String get settingsProfileTemplatesButton => 'Wybierz z szablonu';

  @override
  String get settingsProfileTemplatesTitle => 'Zapisane szablony';

  @override
  String get settingsProfileNoTemplates => 'Brak zapisanych szablonów';

  @override
  String get settingsProfileTemplateEquipped => 'Zastosowano szablon awatara';

  @override
  String get avatarEditButton => 'Edytuj awatar';

  @override
  String get groupCreateEditIcon => 'Edytuj ikonę';

  @override
  String get settingsProfileUsername => 'Nazwa użytkownika';

  @override
  String get settingsProfileBleNick => 'Krótka nazwa (5 znaków)';

  @override
  String get settingsProfileKeyhash => 'ID konta';

  @override
  String get settingsProfileKeyhashCopied => 'ID konta skopiowane do schowka';

  @override
  String get settingsProfileChangePinButton => 'Zmień PIN';

  @override
  String get settingsProfileResetIdentityButton => 'Resetuj konto';

  @override
  String get settingsResetConfirmTitle => 'Resetować tożsamość?';

  @override
  String get settingsResetConfirmBody =>
      'To trwale usunie wszystkie wiadomości, kontakty i wygeneruje nową tożsamość. Tej operacji nie można cofnąć.';

  @override
  String get settingsResetConfirmCancel => 'Anuluj';

  @override
  String get settingsResetConfirmReset => 'Resetuj';

  @override
  String get settingsChangePinTitle => 'Zmień PIN';

  @override
  String get changePinVerifyTitle => 'Potwierdź obecny PIN';

  @override
  String get changePinVerifyPrompt => 'Wprowadź obecny PIN, aby kontynuować.';

  @override
  String get changePinSetTitle => 'Ustaw nowy PIN';

  @override
  String get settingsChangePinOldPin => 'Wpisz obecny PIN';

  @override
  String get settingsChangePinNewPin => 'Wpisz nowy PIN (4–6 cyfr)';

  @override
  String get settingsChangePinConfirmPin => 'Potwierdź nowy PIN';

  @override
  String get settingsChangePinEmptyFieldsError =>
      'Proszę wypełnić wszystkie pola.';

  @override
  String get settingsChangePinLengthError =>
      'Nowy PIN musi mieć od 4 do 6 cyfr.';

  @override
  String get settingsChangePinMatchError => 'Nowe kody PIN nie są zgodne.';

  @override
  String get settingsChangePinUpdatedSnackBar => 'PIN został zaktualizowany.';

  @override
  String get settingsChangePinIncorrectError =>
      'Obecny PIN jest nieprawidłowy.';

  @override
  String get settingsNetworkRoutingTitle => 'Ustawienia sieci';

  @override
  String get settingsNetworkDevRelayToggle =>
      'Użyj lokalnego serwera deweloperskiego';

  @override
  String get settingsNetworkDevRelayUrlLabel => 'URL serwera deweloperskiego';

  @override
  String get settingsNetworkDevRelayDescription =>
      'Włączenie tej opcji zastępuje serwer produkcyjny i kieruje wiadomości przez serwer lokalny.';

  @override
  String get settingsNetworkActiveGateway => 'Bieżący URL serwera';

  @override
  String get settingsNetworkDiagnostics => 'Diagnostyka';

  @override
  String get settingsNetworkDebugButton => 'Otwórz konsolę debugowania';

  @override
  String get settingsDebugButtonsToggle => 'Przyciski debugowania';

  @override
  String get settingsDebugButtonsDescription =>
      'Pokazuje przycisk konsoli terminala na liście czatów i w czatach.';

  @override
  String get settingsDebugTitle => 'Konsola debugowania';

  @override
  String get settingsAlertsBackgroundNotifications => 'Powiadomienia w tle';

  @override
  String get settingsAlertsExplanation =>
      'Powiadomienia pokażą tylko \'Masz wiadomość\'. Twoje wiadomości pozostają zaszyfrowane, dopóki nie odblokujesz aplikacji.';

  @override
  String get settingsTextSizeLabel => 'Rozmiar tekstu czatu';

  @override
  String get settingsTextSizePreview => 'Tak będą wyglądać twoje wiadomości.';

  @override
  String get settingsLanguageLabel => 'Język';

  @override
  String get settingsLanguageSystem => 'Język systemowy';

  @override
  String get settingsLanguageEnglish => 'English (Angielski)';

  @override
  String get settingsLanguageHungarian => 'Magyar (Węgierski)';

  @override
  String get settingsLanguagePolish => 'Polski';

  @override
  String get settingsLanguageGerman => 'Deutsch (Niemiecki)';

  @override
  String get settingsLanguageFrench => 'Français (Francuski)';

  @override
  String get settingsLanguageSwedish => 'Svenska (Szwedzki)';

  @override
  String get settingsLanguageChinese => '中文 (Chiński)';

  @override
  String get notificationModeOff => 'Wyłączone';

  @override
  String get notificationModeOffDesc =>
      'Brak sprawdzania w tle. Wiadomości zobaczysz dopiero po otwarciu aplikacji.';

  @override
  String get notificationModeLowPower => 'Oszczędzanie energii';

  @override
  String get notificationModeLowPowerDesc =>
      'Okresowo sprawdza nowe wiadomości w tle – szybko zaraz po zamknięciu aplikacji, a potem rzadziej, aby oszczędzać baterię. Brak stałego połączenia, więc powiadomienia mogą być opóźnione.';

  @override
  String get notificationModeInstant => 'Natychmiastowe';

  @override
  String get notificationModeInstantDesc =>
      'Opcjonalne. Utrzymuje w tle otwarte połączenie szyfrowane end-to-end, aby synchronizować przychodzące wiadomości w czasie rzeczywistym, co sygnalizuje stałe powiadomienie. Wiltkey używa tego zamiast usług push Google lub Apple ze względu na prywatność, dzięki czemu działa nawet bez Usług Google Play – kosztem większego zużycia baterii.';

  @override
  String get notificationNewMessageBody => 'Masz nową wiadomość';

  @override
  String get notificationEmergencyChatBody => 'Prośba o czat awaryjny';

  @override
  String get notificationSecureLinkActive =>
      'Synchronizowanie bezpiecznych wiadomości';

  @override
  String get onboardingNotificationsTitle => 'Powiadomienia';

  @override
  String get onboardingNotificationsExplanation =>
      'Wiltkey nie korzysta z powiadomień push Google ani Apple — nic o Twoich wiadomościach nie trafia na ich serwery. Wybierz, jak chcesz otrzymywać powiadomienia. Możesz to zmienić w każdej chwili w Ustawieniach.';

  @override
  String get onboardingFactPushTitle => 'BRAK SERWERÓW PUSH';

  @override
  String get onboardingFactPushBody =>
      'Zwykłe aplikacje przesyłają Twoje powiadomienia przez Google lub Apple, ujawniając, kto i kiedy do Ciebie pisze. Wiltkey nigdy tego nie robi — domyślnie nie ma żadnych sprawdzeń w tle, a każde powiadomienie działa wyłącznie na Twoim urządzeniu.';

  @override
  String get notificationModeInstantDescFcm =>
      'Opcjonalne. Wykorzystuje usługę push Google jako lekki sygnał wybudzający, aby nowe wiadomości docierały w czasie rzeczywistym. Przez Google przechodzi tylko pusty sygnał — nigdy Twoje wiadomości, które pozostają szyfrowane end-to-end na przekaźniku, dopóki Twoje urządzenie ich nie pobierze. Mniej obciąża baterię niż stałe połączenie.';

  @override
  String get onboardingNotificationsExplanationFcm =>
      'Aby otrzymywać alerty w czasie rzeczywistym, ta wersja używa usługi push Google wyłącznie jako sygnału wybudzającego — pustego sygnału, nigdy Twoich wiadomości, które nigdy nie trafiają na serwery Google. Wybierz, jak chcesz być powiadamiany; możesz to zmienić w każdej chwili w Ustawieniach.';

  @override
  String get onboardingFactPushTitleFcm => 'PUSH BEZ TREŚCI';

  @override
  String get onboardingFactPushBodyFcm =>
      'Zwykłe aplikacje przesyłają treść powiadomień przez Google, ujawniając, co i kiedy jest wysyłane. Ta wersja używa Google tylko jako pustego sygnału wybudzającego — bez danych wiadomości, bez czytelnych metadanych — a wszystko pozostaje szyfrowane end-to-end.';

  @override
  String get chatsLockedSubtitle =>
      'Zablokowane · sparuj osobiście, aby odblokować';

  @override
  String chatsMemberCount(int count) {
    return '$count członków';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: 'kontaktów',
      few: 'kontakty',
      one: 'kontakt',
    );
    return '$totalCount $_temp0 · $lockedCount zablokowanych';
  }

  @override
  String get chatsTitle => 'Czaty';

  @override
  String get chatsPopupPair => 'Sparuj urządzenie';

  @override
  String get chatsPopupCreateGroup => 'Utwórz grupę';

  @override
  String get chatsPopupJoinGroup => 'Dołącz do grupy';

  @override
  String get chatsSearchHint => 'Szukaj';

  @override
  String get chatsEmptyNoMatches => 'Brak wyników';

  @override
  String get chatsEmptyNoChats => 'Brak czatów';

  @override
  String get chatsEmptyPairInstruction =>
      'Sparuj urządzenie osobiście, aby zacząć rozmawiać.';

  @override
  String get chatsEmptyPairButton => 'Sparuj urządzenie';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return 'JA $remaining · ROZMÓWCA $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded =>
      'Zbyt wiele nieudanych prób. Urządzenie wyczyszczone.';

  @override
  String pinAccessDenied(int attempts) {
    return 'Nieprawidłowy PIN. Zostało $attempts prób.';
  }

  @override
  String get pinMinLengthError => 'PIN musi składać się z co najmniej 4 cyfr.';

  @override
  String get pinPurgeConfirmTitle => 'Zresetować urządzenie?';

  @override
  String get pinPurgeConfirmBody =>
      'Nie pamiętasz PIN-u? To trwale usunie wszystkie wiadomości i zresetuje konto. Tej czynności nie można cofnąć.';

  @override
  String get pinPurgeConfirmButton => 'Resetuj urządzenie';

  @override
  String get pinLockedTitle => 'Zablokowane';

  @override
  String get pinLockedSubtitle => 'Wpisz PIN, aby odblokować';

  @override
  String get pinUnlockButton => 'Odblokuj';

  @override
  String get pinUseFingerprintButton => 'Użyj odcisku palca';

  @override
  String get settingsBiometricToggle => 'Odblokowanie odciskiem palca';

  @override
  String get settingsBiometricDescription =>
      'Odblokowuj odciskiem palca zamiast PIN-em. Po okresie ustawionym poniżej PIN jest znów wymagany.';

  @override
  String get settingsBiometricIdleTitle => 'Powrót do PIN-u';

  @override
  String get settingsBiometricIdleDescription =>
      'Wymagaj PIN-u ponownie po tym czasie bez odblokowania.';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours godz.';
  }

  @override
  String get settingsBiometricIdleNever => 'Nigdy';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Nie udało się włączyć odblokowania odciskiem palca.';

  @override
  String get pinForgotButton => 'Nie pamiętasz PIN-u? Resetuj urządzenie';

  @override
  String get pairTitle => 'Parowanie urządzeń';

  @override
  String get pairRescanTooltip => 'Odśwież skanowanie';

  @override
  String get pairBluetoothOffWarning =>
      'Bluetooth jest wyłączony. Parowanie wymaga Bluetootha do wykrycia pobliskich urządzeń — włącz go, aby kontynuować.';

  @override
  String get pairBluetoothTurnOnButton => 'Włącz Bluetooth';

  @override
  String get pairDoNotExitWarning =>
      'Nie zamykaj WiltKey — nie przełączaj aplikacji ani nie wychodź, dopóki parowanie nie zakończy się na OBU urządzeniach.';

  @override
  String get pairRequestDialogTitle => 'Zaproszenie do parowania';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName chce się sparować.\n\nRozmiar czatu: $size.\n\nAkceptujesz bezpieczne parowanie?';
  }

  @override
  String get pairRequestReject => 'Odrzuć';

  @override
  String get pairRequestAccept => 'Akceptuj';

  @override
  String get pairPingStatusPinging => 'Testowanie...';

  @override
  String pairPingStatusLatency(String latency) {
    return 'Opóźnienie: $latency ms';
  }

  @override
  String get pairPingStatusFailed => 'Niepowodzenie';

  @override
  String get pairPingStatusTest => 'Testuj połączenie';

  @override
  String get pairDeviceNameLabel => 'Nazwa twojego urządzenia';

  @override
  String get pairDeviceNameHint => 'Wpisz nazwę';

  @override
  String get pairDiscoverableTitle => 'Ustaw urządzenie jako widoczne';

  @override
  String get pairDiscoverableSubtitle =>
      'Pozwól znajomym w pobliżu cię znaleźć';

  @override
  String get pairNearbyDevicesTitle => 'Urządzenia w pobliżu';

  @override
  String get pairNearbyDevicesInstruction =>
      'Trzymaj urządzenia blisko siebie, aby się połączyć.';

  @override
  String get pairDirectSyncFormRelayLabel => 'URL serwera';

  @override
  String get pairDirectSyncFormSyncButton => 'Połącz urządzenia';

  @override
  String get pairSyncingConnecting => 'Łączenie...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return 'Generowanie bezpiecznego klucza ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return 'Klucz: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return 'Ukończono $percent%';
  }

  @override
  String get pairSuccessConnectionSecured => 'Połączono pomyślnie';

  @override
  String pairSuccessGroupBody(String groupName) {
    return 'Dołączono do grupy \"$groupName\". Bezpieczne klucze wygenerowano lokalnie na twoim urządzeniu.';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return 'Bezpieczne klucze zostały wymienione i wygenerowane na twoim urządzeniu. Połączono z $title z pojemnością czatu $label.';
  }

  @override
  String get pairSuccessReturnButton => 'Przejdź do czatów';

  @override
  String get chatDetailsTitle => 'Szczegóły czatu';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return 'Pseudonim: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => 'Oficjalny przekaźnik';

  @override
  String get chatDetailsPrivateNode => 'Prywatny węzeł';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return 'JA $remaining · ROZMÓWCA $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => 'Profil';

  @override
  String get chatDetailsProfileExplanation =>
      'Avatary i pseudonimy synchronizują się automatycznie po połączeniu. W razie potrzeby możesz teraz ręcznie zsynchronizować swój profil.';

  @override
  String get chatDetailsProfileSyncButton => 'Synchronizuj profil';

  @override
  String get chatDetailsProfileSnackBar => 'Profil wysłany.';

  @override
  String get chatDetailsSectionPermissions => 'Uprawnienia';

  @override
  String get chatDetailsPermissionsPhotos => 'Zezwalaj na udostępnianie zdjęć';

  @override
  String get chatDetailsPermissionsEmojis => 'Własne emotikony';

  @override
  String get chatDetailsPermissionsEmojisAvailable => 'Dostępne';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize => 'Wymaga większego czatu';

  @override
  String get chatDetailsSectionMetadata => 'Miejsce na metadane';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return 'Ten czat przydziela $budget z maksymalnie $max miejsca na ustawienia, zdjęcia profilowe i własne emotikony.';
  }

  @override
  String get chatDetailsSectionLanes => 'Bezpieczne kanały';

  @override
  String get chatDetailsLanesMySend => 'Moja pojemność wysyłania';

  @override
  String get chatDetailsLanesPeerSend => 'Pojemność wysyłania rozmówcy';

  @override
  String get chatDetailsLanesBorrowed => 'Pożyczone miejsce';

  @override
  String get chatDetailsLanesCapacityLeft => 'Moja pozostała pojemność';

  @override
  String get chatDetailsLanesExplanation =>
      'Jeśli skończy Ci się pojemność czatu, możesz pożyczyć niewykorzystane miejsce od swojego rozmówcy. Może to również nastąpić automatycznie, abyście mogli dalej rozmawiać.';

  @override
  String get chatDetailsLanesBorrowButton => 'Poproś o miejsce na czacie';

  @override
  String get chatDetailsLanesSnackBar => 'Prośba wysłana do rozmówcy.';

  @override
  String get chatDetailsSectionEmojis => 'Własne emotikony';

  @override
  String get chatDetailsEmojisExplanation =>
      'Używaj tych własnych emotikonów w wiadomościach w formacie :nazwa:.';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      'Ta pojemność czatu jest zbyt mała na własne emotikony. Połącz się z większą pojemnością, aby je włączyć.';

  @override
  String get chatDetailsEmojisCreate => 'Utwórz';

  @override
  String get chatDetailsSectionDestructive => 'Niebezpieczne ustawienia';

  @override
  String get chatDetailsNukeButton => 'Zniszcz czat (po obu stronach)';

  @override
  String get chatDetailsDeleteEmojiTitle => 'Usunąć emotikonę?';

  @override
  String get chatDetailsDeleteEmojiBody =>
      'Ta emotikona zostanie trwale usunięta. Czy chcesz kontynuować?';

  @override
  String get chatDetailsDeleteEmojiDelete => 'Usuń';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return 'Dodano :$name:';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return 'Obraz jest za duży ($cost) na pozostałe miejsce ($charge).';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar =>
      'Obraz jest zbyt duży, aby go wysłać.';

  @override
  String get chatImageNeedsPlusSnackBar =>
      'Obraz zbyt duży dla darmowego planu — WiltKey Plus zwiększa limit do 50 MB.';

  @override
  String get chatTapForDetails => 'Stuknij, aby zobaczyć szczegóły';

  @override
  String get chatSyncTooltip => 'Synchronizuj wiadomości';

  @override
  String get chatStickerHint => 'Przytrzymaj emoji, aby wysłać naklejkę';

  @override
  String get chatSyncStarted => 'Szukanie pominiętych wiadomości…';

  @override
  String get chatSyncOffline => 'Nie można synchronizować w trybie offline.';

  @override
  String get chatEncrypting => 'Szyfrowanie…';

  @override
  String get chatScreenshotDetected => 'Wykryto zrzut ekranu';

  @override
  String get chatScreenshotExplanation =>
      'Wykryto zrzut ekranu. Dla bezpieczeństwa możesz teraz wyczyścić swoje klucze i wiadomości.';

  @override
  String get chatScreenshotWipeButton => 'Wyczyść wiadomości i klucze';

  @override
  String get chatScreenshotIgnoreButton => 'Ignoruj ostrzeżenie';

  @override
  String get chatSimulateScreenshotButton => 'Symuluj zrzut ekranu';

  @override
  String chatCostIndicator(String cost) {
    return 'Koszt: $cost';
  }

  @override
  String get groupCreateTitle => 'Utwórz grupę';

  @override
  String get groupCreatePixelArtIcon => 'Ikona grupy';

  @override
  String get groupCreateRandomIcon => 'Generuj';

  @override
  String get groupCreateClearIcon => 'Wyczyść';

  @override
  String get groupCreateNameLabel => 'Nazwa grupy';

  @override
  String get groupCreateNameEmptyValidator => 'Wpisz nazwę grupy';

  @override
  String get groupCreateNameLengthValidator => 'Maksymalnie 24 znaki';

  @override
  String get groupCreatePoliciesSection => 'Ustawienia zasad grupy';

  @override
  String get groupCreatePolicyPadSize => 'Rozmiar czatu grupowego';

  @override
  String get groupCreatePolicyLaneSize => 'Pojemność na członka';

  @override
  String get groupCreatePolicyMaxMembersLabel => 'Maksymalna liczba członków';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return 'Maksymalnie $count członków';
  }

  @override
  String get groupCreatePolicyAllowImages => 'Zezwalaj na udostępnianie zdjęć';

  @override
  String get groupCreatePolicyAllowImagesSub =>
      'Zezwalaj członkom na wysyłanie zdjęć';

  @override
  String get groupCreatePolicyPayloadSize => 'Maksymalny rozmiar wiadomości';

  @override
  String get groupCreateButton => 'Utwórz grupę';

  @override
  String get groupCreateProgressTitle => 'Tworzenie grupy…';

  @override
  String get groupCreateProgressSubtitle =>
      'Przygotowywanie zapasu szyfrującego grupy i pojemności członków. To może chwilę potrwać — cierpliwości.';

  @override
  String groupCreateFailedSnackBar(String error) {
    return 'Nie udało się utworzyć grupy: $error';
  }

  @override
  String get pairSyncingAwaitingApproval =>
      'Oczekiwanie na akceptację znajomego...';

  @override
  String get pairSyncingCoordinating => 'Przygotowywanie wymiany kluczy...';

  @override
  String get pairSyncingStep1 => 'Nawiązywanie bezpiecznego połączenia...';

  @override
  String get pairSyncingStep2 => 'Generowanie ziarna bezpieczeństwa...';

  @override
  String pairSyncingStep3(String seed) {
    return 'Wymiana kluczy publicznych... $seed';
  }

  @override
  String get pairSyncingStep4 => 'Generowanie bezpiecznych kluczy czatu...';

  @override
  String get pairSyncingStep5 => 'Weryfikacja integralności kluczy...';

  @override
  String get pairSyncingStep6 => 'Bezpieczna konfiguracja zakończona sukcesem.';

  @override
  String chatRemainingLabel(String bytes) {
    return 'Pozostało $bytes';
  }

  @override
  String get chatLockedLabel =>
      'Zablokowane · sparuj osobiście, aby kontynuować';

  @override
  String get chatMessageHint => 'Wiadomość';

  @override
  String get chatVoiceComingSoon => 'Wiadomości głosowe już wkrótce.';

  @override
  String get chatVoiceHoldHint => 'Przytrzymaj, aby nagrać wiadomość głosową.';

  @override
  String get chatVoiceReleaseCancel => 'Puść, aby anulować';

  @override
  String get chatVoiceSlideToCancel => 'Przesuń, aby anulować';

  @override
  String get chatVoiceSlideToLock => 'Przesuń w górę, aby zablokować';

  @override
  String get chatVoiceCancel => 'Anuluj nagrywanie';

  @override
  String get chatVoiceSend => 'Wyślij wiadomość głosową';

  @override
  String get chatVoicePermissionDenied =>
      'Do nagrywania wiadomości głosowych potrzebne jest uprawnienie do mikrofonu.';

  @override
  String get chatVoiceQualityLofi => 'Lo-fi';

  @override
  String get chatVoiceQualityVoice => 'Głos';

  @override
  String get chatVoiceQualityClear => 'Wyraźnie';

  @override
  String get chatVoiceUnavailable => 'Wiadomość głosowa niedostępna';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return 'Wiadomość głosowa za duża ($cost) na pozostałe miejsce ($charge).';
  }

  @override
  String get chatDetailsDeleteConfirmTitle => 'Usunąć czat?';

  @override
  String get chatDetailsDeleteConfirmBody =>
      'To trwale usunie wszystkie wiadomości i klucze szyfrujące dla tego kontaktu. Tej czynności nie można cofnąć.';

  @override
  String get chatDetailsDeleteConfirmButton => 'Usuń czat';

  @override
  String get chatsActionArchive => 'Archiwizuj';

  @override
  String get chatsActionNuke => 'Usuń czat i klucze';

  @override
  String get chatsActionDelete => 'Usuń';

  @override
  String get chatsArchivedBadge => 'Zarchiwizowano';

  @override
  String get chatsArchivedSubtitle => 'Zarchiwizowano · tylko do odczytu';

  @override
  String get chatsArchiveConfirmTitle => 'Zarchiwizować czat?';

  @override
  String get chatsArchiveConfirmBody =>
      'Zwalnia to miejsce, usuwając klucz jednorazowy tego czatu. Twoje wiadomości pozostaną czytelne, ale czat stanie się tylko do odczytu — nie wyślesz ani nie odbierzesz w nim już wiadomości.';

  @override
  String get chatsArchiveConfirmButton => 'Archiwizuj';

  @override
  String get chatsActionPin => 'Przypnij';

  @override
  String get chatsActionUnpin => 'Odepnij';

  @override
  String get chatsFilterAll => 'Wszystkie';

  @override
  String get chatsFilterDirect => 'Bezpośrednie';

  @override
  String get chatsFilterGroups => 'Grupy';

  @override
  String get chatsSectionArchived => 'Zarchiwizowane';

  @override
  String groupTapForDetails(String hostName) {
    return 'Stuknij, aby zobaczyć szczegóły · Host: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wolnych kanałów dostępnych',
      few: 'wolne kanały dostępne',
      one: 'wolny kanał dostępny',
    );
    return '$count $_temp0';
  }

  @override
  String get groupHost => 'Host';

  @override
  String get groupMember => 'Członek';

  @override
  String get groupDepleted => 'Wyczerpany';

  @override
  String get groupNotYetMet => 'Jeszcze nie spotkano';

  @override
  String get groupRechargeButton => 'Odśwież grupę';

  @override
  String get groupRechargeTitle => 'Odświeżyć grupę?';

  @override
  String get groupRechargeBody =>
      'Odświeża czat nowym kluczem. Historia wiadomości zostaje, ale każdy członek musi znowu spotkać się z Tobą osobiście, żeby dołączyć.';

  @override
  String get groupRechargeConfirm => 'Odśwież';

  @override
  String get groupRechargeDone =>
      'Grupa odświeżona — spotkaj się z członkami ponownie, aby dodać ich z powrotem.';

  @override
  String get groupRechargeNeededComposer =>
      'Host odświeżył tę grupę — spotkaj się z nim znowu, aby dołączyć';

  @override
  String get groupTimeWiltToggle => 'Grupa Time Wilt';

  @override
  String get groupTimeWiltToggleSub =>
      'Ograniczony czas, nieograniczony transfer. Grupa przechodzi w tryb tylko do odczytu po wygaśnięciu licznika; spotkaj się ponownie z gospodarzem, aby ją odnowić.';

  @override
  String get groupTimeWiltMembersLabel => 'Maks. liczba członków';

  @override
  String get groupTimeWiltMembersUpsell => 'Odblokuj do 100 członków z Plus';

  @override
  String get groupTimeWiltHostInfinite => 'Gospodarz · ∞';

  @override
  String get groupTimeWiltRenewComposer =>
      'Wygasło — spotkaj się z gospodarzem, aby odnowić dostęp';

  @override
  String get groupTimeWiltHostAllWilted =>
      'Wszyscy członkowie wygasli — spotkaj się z kimś, aby ożywić grupę';

  @override
  String get groupNukeProposeButton => 'Zaproponuj zniszczenie dla wszystkich';

  @override
  String get groupNukeProposeTitle => 'Zniszczyć tę grupę dla wszystkich?';

  @override
  String get groupNukeProposeBody =>
      'Rozpoczyna głosowanie wśród członków. W przypadku większości grupa i historia zostaną usunięte na każdym urządzeniu. Nie można cofnąć.';

  @override
  String get groupNukeProposeConfirm => 'Zaproponuj';

  @override
  String get groupNukeVoteTitle => 'Zniszczyć grupę?';

  @override
  String get groupNukeVoteBody =>
      'Członek zaproponował zniszczenie tej grupy dla wszystkich. Jeśli większość się zgodzi, zostanie wyczyszczona na każdym urządzeniu.';

  @override
  String get groupNukeVoteAllow => 'Zgoda';

  @override
  String get groupNukeVoteDeny => 'Zachowaj';

  @override
  String get groupNukeVotePending => 'Oczekiwanie na głosy członków…';

  @override
  String get groupNukeVotePassed =>
      'Grupa została zniszczona większością głosów.';

  @override
  String get groupNukeVoteFailed =>
      'Wniosek o zniszczenie grupy został odrzucony.';

  @override
  String get groupNukeVoteSent =>
      'Wniosek wysłany — oczekiwanie na głosowanie.';

  @override
  String get activityTitle => 'Aktywność';

  @override
  String get activityEmpty =>
      'Brak aktywności. Zdarzenia takie jak zniszczenie czatu pojawią się tutaj.';

  @override
  String get activityClear => 'Wyczyść';

  @override
  String get activityClearConfirmTitle => 'Wyczyścić aktywność?';

  @override
  String get activityClearConfirmBody =>
      'Usuwa wszystkie wpisy aktywności z tego urządzenia. Nie można cofnąć.';

  @override
  String get eventNukeReceivedTitle => 'Czat zniszczony';

  @override
  String get eventNukeReceivedBody => 'Bezpieczny czat został zniszczony.';

  @override
  String get eventGroupNukedTitle => 'Grupa zniszczona';

  @override
  String get eventGroupNukedBody => 'Bezpieczna grupa została zniszczona.';

  @override
  String eventContactRequestTitle(String name) {
    return 'Prośba o kontakt od $name';
  }

  @override
  String get eventContactRequestBody =>
      'Stuknij, aby zaakceptować lub odrzucić w czacie';

  @override
  String eventContactRemovedTitle(String name) {
    return '$name usunął cię';
  }

  @override
  String get eventContactRemovedBody => 'Usunął cię ze swoich kontaktów';

  @override
  String groupSyncingFromMember(String name) {
    return 'Synchronizowanie szczegółów i wiadomości od $name...';
  }

  @override
  String get groupInviteMember => 'Zaproś członka';

  @override
  String get groupLeaveGroup => 'Opuść grupę';

  @override
  String get groupRemoveMember => 'Usuń członka';

  @override
  String get groupRemoveMemberTitle => 'Usunąć członka?';

  @override
  String groupRemoveMemberBody(String name) {
    return 'Usunąć $name z grupy? To wyczyści ich klucz.';
  }

  @override
  String get groupLeaveGroupTitle => 'Opuścić grupę?';

  @override
  String get groupLeaveGroupBody =>
      'Opuścić tę grupę? To wyczyści lokalne klucze i logi.';

  @override
  String get groupSyncStepText => 'Synchronizuj';

  @override
  String get groupDecryptingImage => 'Deszyfrowanie obrazu...';

  @override
  String get chatFileTapToDownload => 'Stuknij, aby pobrać';

  @override
  String get chatFileDownloadFailed => 'Stuknij, aby ponowić';

  @override
  String get chatFileKindPhoto => 'Zdjęcie';

  @override
  String get chatFileKindVoice => 'Wiadomość głosowa';

  @override
  String get chatFileKindFile => 'Plik';

  @override
  String get groupTapToRevealImage => 'Stuknij, aby pokazać obraz';

  @override
  String groupImageSize(String size) {
    return 'Rozmiar: $size';
  }

  @override
  String get groupImageFailedToLoad => 'Nie udało się załadować obrazu';

  @override
  String get groupScreenshotWipeButton => 'Wyczyść wszystkie klucze teraz';

  @override
  String get groupRefillGranted =>
      'Doładowanie kanału zostało przyznane pomyślnie.';

  @override
  String groupRefillFailed(String error) {
    return 'Nie udało się przyznać doładowania: $error';
  }

  @override
  String get groupLaneDepleted => 'Kanał wyczerpany';

  @override
  String get groupLaneDepletedExplanation =>
      'Poproś hosta grupy o doładowanie bajtów.';

  @override
  String get groupRefillRequestSent => 'Prośba o doładowanie wysłana do hosta.';

  @override
  String get groupRequestRefill => 'Poproś o doładowanie';

  @override
  String groupExceedsSizeLimit(int size) {
    return 'Przekracza limit rozmiaru ($size B)';
  }

  @override
  String get groupDetailsTitle => 'Szczegóły grupy';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return 'Wspólny notes · Host: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => 'Zasady grupy';

  @override
  String get groupDetailsSavePoliciesButton => 'Zapisz zasady';

  @override
  String get groupDetailsSavePoliciesSnackBar => 'Zapisano zasady grupy.';

  @override
  String get groupDetailsSectionEmojis => 'Własne emotikony';

  @override
  String get groupDetailsSectionMetadata => 'Miejsce na metadane';

  @override
  String get groupDetailsMetadataExplanation =>
      'Gniazdo 0 wspólnego notesu rezerwuje 1 MB na metadane grupy — ikona grupy, lista członków i własne emotikony znajdują się tutaj.';

  @override
  String get groupDetailsSectionSync => 'Synchronizacja grupy';

  @override
  String get groupDetailsSyncExplanation =>
      'Pobierz najnowsze szczegóły grupy, zasady i listy członków od hosta.';

  @override
  String get groupDetailsSyncButton => 'Synchronizuj szczegóły';

  @override
  String get groupDetailsSyncSnackBar =>
      'Zażądano aktualizacji grupy od hosta.';

  @override
  String get groupDetailsSectionDestructive => 'Niebezpieczne ustawienia';

  @override
  String get groupDetailsLeaveButton => 'Opuść grupę';

  @override
  String get groupDetailsNukeButton => 'Usuń grupę';

  @override
  String get groupDetailsDeleteConfirmTitle => 'Usunąć grupę?';

  @override
  String get groupDetailsDeleteConfirmBody =>
      'To trwale usunie tę grupę oraz wyczyści historię czatów i klucze wszystkich członków. Tej czynności nie można cofnąć.';

  @override
  String get groupDetailsDeleteConfirmButton => 'Usuń grupę';

  @override
  String get chatImageCompressionTitle => 'Kompresuj obraz';

  @override
  String chatImageCompressionOriginal(String size) {
    return 'Oryginał: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return 'Szacowany: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return 'Szacowany: $size (oszczędność ~$saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return 'Koszt: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation =>
      'Konwertowane do WebP, maks. 2000px.';

  @override
  String get chatImageCompressionLowSize => 'Mały rozmiar';

  @override
  String get chatImageCompressionHighSize => 'Duży';

  @override
  String get chatImageCompressionMaxQuality => 'Maks. jakość';

  @override
  String get chatImageCompressionUncompressed => 'Bez kompresji';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return 'Jakość $percent%';
  }

  @override
  String get chatImageCompressionSendHidden =>
      'Wyślij ukryte (stuknij, aby pokazać)';

  @override
  String get chatImageCompressionSendButton => 'Wyślij';

  @override
  String get groupGrantRefill => 'Przyznaj doładowanie';

  @override
  String get groupLaneLocked => 'Zablokowane · brak bajtów';

  @override
  String get groupMembersTitle => 'Członkowie grupy';

  @override
  String get groupMembersExplanation =>
      'Wszyscy członkowie dzielą jeden rozmiar czatu podzielony na kanały. Wiadomości są wysyłane przez serwer.';

  @override
  String get pairChatSize => 'Rozmiar czatu';

  @override
  String get chatSystemConnected => 'Połączono. Sesja czatu jest bezpieczna.';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return 'Dołączono do grupy \"$groupName\". Połączenia są bezpieczne.';
  }

  @override
  String get themeCyberpunkName => 'Neonowa Siatka';

  @override
  String get themeCyberpunkDesc =>
      'Oryginalny. Obsydian, świecący cyjan, styl terminala.';

  @override
  String get themeGardenName => 'Ogród o Zmierzchu';

  @override
  String get themeGardenDesc =>
      'Miękkie odcienie gleby, ciepły len, płatki na twój budżet.';

  @override
  String get themePaperinkName => 'Papier i Tusz';

  @override
  String get themePaperinkDesc =>
      'Ciepły papier washi, rozcieńczenia tuszu sumi, cynobrowa pieczęć hanko.';

  @override
  String get themePickerPlayExclusive =>
      'Ten motyw jest dostępny wyłącznie w wersji WiltKey ze Sklepu Play.';

  @override
  String get themePreviewTooltip => 'Podgląd';

  @override
  String get themePreviewSectionDashboard => 'Lista czatów';

  @override
  String get themePreviewSectionChat => 'Rozmowa';

  @override
  String get themePreviewSectionEffects => 'Efekty specjalne';

  @override
  String get themePreviewPlayUnlock => 'Odtwórz animację odblokowania';

  @override
  String get themePreviewPlayNuke => 'Odtwórz animację autodestrukcji';

  @override
  String get themePreviewApply => 'Użyj tego motywu';

  @override
  String get themePreviewGetInShop => 'Zdobądź w sklepie';

  @override
  String get themePreviewMsgThem1 =>
      'Zostało tylko 800 bajtów na naszym padzie, spotkamy się?';

  @override
  String get themePreviewMsgMe =>
      'Jasne! Wieczór filmowy u mnie? Przy okazji doładujemy';

  @override
  String get themePreviewMsgThem2 => 'deal, przyniosę przekąski 🍿';

  @override
  String get themePreviewRowPhoto => 'Zdjęcie ze ścianki wspinaczkowej 🧗';

  @override
  String get themePreviewRowLost =>
      'Pad wyczerpany — spotkajcie się, by doładować';

  @override
  String get themePreviewSectionProfile => 'Tło profilu';

  @override
  String get themePreviewFullscreenProfile => 'Podgląd pełnoekranowy profilu';

  @override
  String get linkWarningTitle => 'Ostrzeżenie o linku zewnętrznym';

  @override
  String get linkWarningBody =>
      'Zamierzasz otworzyć link zewnętrzny w przeglądarce. Spowoduje to połączenie z serwerem docelowym i ujawnienie Twojego adresu IP.';

  @override
  String get linkWarningOpen => 'Otwórz w przeglądarce';

  @override
  String get linkWarningCopy => 'Kopiuj link';

  @override
  String get linkWarningCopied => 'Link skopiowany do schowka';

  @override
  String get chatActionEdit => 'Edytuj';

  @override
  String get chatActionDelete => 'Usuń';

  @override
  String get chatEditingBanner => 'Edytowanie wiadomości';

  @override
  String get chatCancelEdit => 'Anuluj edycję';

  @override
  String get chatDeleteTitle => 'Usuń wiadomość';

  @override
  String get chatDeleteBody =>
      'Czy na pewno chcesz usunąć tę wiadomość dla wszystkich?';

  @override
  String get chatDeleteConfirm => 'Usuń';

  @override
  String get chatMessageDeleted => '[Wiadomość usunięta]';

  @override
  String get chatEditedTag => 'edytowano';

  @override
  String get accessibilityWarningTitle => 'Usługa ułatwień dostępu aktywna';

  @override
  String accessibilityWarningBody(String names) {
    return 'Aktywna jest usługa ułatwień dostępu, która może odczytywać zawartość ekranu: $names. To normalne w przypadku narzędzi takich jak czytniki ekranu lub menedżery haseł. Jeśli nie włączyłeś żadnej, sprawdź ustawienia ułatwień dostępu.';
  }

  @override
  String get accessibilityWarningDismiss => 'Zamknij';

  @override
  String get accessibilityWarningOpenSettings => 'Sprawdź ustawienia';

  @override
  String get chatImageCompressionAllowDownload => 'Zezwól na zapis w galerii';

  @override
  String get chatImageCompressionWilting =>
      'Znikający obraz (znika po otwarciu)';

  @override
  String get chatImageDownload => 'Pobierz';

  @override
  String get chatImageSaveAs => 'Zapisz jako';

  @override
  String get chatImageSavedToGallery => 'Zapisano w galerii';

  @override
  String get chatImageSaveFailed => 'Nie udało się zapisać obrazu';

  @override
  String get chatImageSourceTitle => 'Wyślij zdjęcie';

  @override
  String get chatImageSourceCamera => 'Zrób zdjęcie';

  @override
  String get chatImageSourceGallery => 'Wybierz z galerii';

  @override
  String get screenshotRequestTooltip => 'Poproś o zrzut ekranu';

  @override
  String get screenshotWaiting => 'Oczekiwanie na zgodę…';

  @override
  String get screenshotConsentTitle => 'Prośba o zrzut ekranu';

  @override
  String screenshotConsentBody(String name) {
    return '$name chce zapisać zrzut ekranu tego czatu. Zezwolić?';
  }

  @override
  String get screenshotDenied => 'Prośba o zrzut ekranu została odrzucona.';

  @override
  String get screenshotCaptureFailed => 'Nie udało się wykonać zrzutu ekranu.';

  @override
  String get screenshotWatermark => 'WiltKey — Zrzut ekranu za zgodą';

  @override
  String screenshotRequestInline(String name) {
    return '$name poprosił(a) o zrzut ekranu';
  }

  @override
  String get screenshotRequestAllowed => 'Zezwolono na zrzut ekranu';

  @override
  String get screenshotRequestDeclined => 'Odrzucono zrzut ekranu';

  @override
  String get screenshotRequestExpired => 'Prośba o zrzut ekranu wygasła';

  @override
  String get wiltingTapToReveal => 'Dotknij, aby zobaczyć znikającą wiadomość';

  @override
  String get wiltingMessageTag => 'Znikająca wiadomość';

  @override
  String get wiltedMessage => 'Zwiędła wiadomość';

  @override
  String get wiltingSheetTitle => 'Znikająca wiadomość';

  @override
  String get wiltingSheetBody =>
      'Wiadomość znika tyle sekund po otwarciu jej przez odbiorcę.';

  @override
  String get wiltingSheetSend => 'Wyślij znikającą wiadomość';

  @override
  String get wiltingHoldToSendHint =>
      'Przytrzymaj, aby wysłać znikającą wiadomość';

  @override
  String get replyYou => 'Ty';

  @override
  String get replySomeone => 'Ktoś';

  @override
  String get replyPreviewImage => '📷 Zdjęcie';

  @override
  String get replyPreviewVoice => '🎤 Wiadomość głosowa';

  @override
  String get replyPreviewMessage => 'Wiadomość';

  @override
  String get replyUnavailable => 'Oryginalna wiadomość niedostępna';

  @override
  String get shopEntryTitle => 'Sklep i WiltKey Plus';

  @override
  String get shopEntrySubtitle => 'Motywy, dodatki i Plus';

  @override
  String get supportEntryTitle => 'Wesprzyj projekt';

  @override
  String get supportEntrySubtitle => 'Pomóż utrzymać WiltKey';

  @override
  String get shopTitle => 'Sklep';

  @override
  String get supportTitle => 'Wesprzyj WiltKey';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => 'Odblokowania';

  @override
  String get shopPlusTagline =>
      'Dłuższe przechowywanie wiadomości offline i większe transfery plików.';

  @override
  String get shopEmptyTitle => 'Jeszcze nic tu nie ma';

  @override
  String get shopEmptyBody => 'Produkty są w drodze — zajrzyj wkrótce.';

  @override
  String get shopRestoreButton => 'Przywróć zakupy';

  @override
  String get shopRestoredSnack => 'Zakupy przywrócone';

  @override
  String get shopBuyButton => 'Kup';

  @override
  String get shopOwnedLabel => 'Posiadane';

  @override
  String get shopActiveLabel => 'Aktywne';

  @override
  String get shopManageNote => 'Zarządzaj w Google Play';

  @override
  String get shopPurchasePendingSnack => 'Zakup w toku…';

  @override
  String get shopPurchaseFailedSnack => 'Nie udało się dokończyć zakupu';

  @override
  String get supportIntro =>
      'WiltKey jest darmowy i open source, a ta wersja odblokowuje wszystkie elementy kosmetyczne za darmo. Jeśli chcesz wesprzeć rozwój i oficjalny serwer relay, odwiedź stronę poniżej.';

  @override
  String get supportOpenButton => 'Otwórz stronę wsparcia';

  @override
  String get supportFreeNote =>
      'W tej wersji wszystkie elementy kosmetyczne są odblokowane.';

  @override
  String get shopTabPalettes => 'Palety';

  @override
  String get shopTabThemes => 'Motywy';

  @override
  String get shopTabBorders => 'Ramki';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'Promo';

  @override
  String get shopPalettesIntro =>
      'Dodatkowe kolory do rysowania awatara i ikon grup. Otrzymane prace zawsze wyświetlają się w pełni — pakiet odblokowuje tylko rysowanie tymi kolorami przez Ciebie.';

  @override
  String shopPaletteColorCount(int count) {
    return '$count dodatkowych kolorów';
  }

  @override
  String get shopThemesEmptyTitle => 'Jeszcze brak motywów';

  @override
  String get shopThemesEmptyBody =>
      'Motywy premium są w drodze — trzy wbudowane motywy pozostaną darmowe na zawsze.';

  @override
  String get shopBordersSoonTitle => 'Ramki są w drodze';

  @override
  String get shopBordersSoonBody =>
      'Ozdobne ramki do awatara, widoczne dla wszystkich, z którymi rozmawiasz. W przygotowaniu.';

  @override
  String get shopPlusBenefitsSection => 'Co otrzymujesz';

  @override
  String get shopPlusBenefitHold =>
      'Twoje wiadomości czekają na serwerze 72 godziny zamiast 24, gdy jesteś offline.';

  @override
  String get shopPlusBenefitFiles =>
      'Wysyłaj duże pliki — do 50 MB na wiadomość, ponad darmowy limit 5 MB.';

  @override
  String get shopPlusBenefitPads =>
      'Twórz większe pady — do 200 MB dla czatu i 500 MB dla grupy.';

  @override
  String get shopPlusBenefitTimeWiltGroups =>
      'Twórz większe grupy Time Wilt — do 100 członków zamiast 20.';

  @override
  String get shopPlusBenefitSupport =>
      'Utrzymujesz serwer i niezależność WiltKey.';

  @override
  String get shopSubscribeButton => 'Subskrybuj';

  @override
  String get shopPriceUnavailable => 'Niedostępne';

  @override
  String get shopPromoIntro =>
      'Masz kod promocyjny? Wpisz go poniżej, a Google Play zastosuje go na Twoim koncie.';

  @override
  String get shopPromoHint => 'KOD PROMOCYJNY';

  @override
  String get shopPromoRedeemButton => 'Zrealizuj w Google Play';

  @override
  String get shopPromoNote =>
      'Kody realizuje się w Sklepie Play. Po zastosowaniu odblokowanie pojawi się tutaj automatycznie.';

  @override
  String pairLargerPadsUpsell(String max) {
    return 'Większe pady z Plus — do $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return 'Za mało wolnego miejsca — ten czat wymaga $needed, a masz $free.';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return 'Generowanie strumienia klucza… $written / $total';
  }

  @override
  String get pairKeepAppOpen =>
      'Nie zamykaj aplikacji — bezpieczny pad wciąż jest tworzony.';

  @override
  String groupLargerPadsUpsell(String max) {
    return 'Większe pady grupowe z Plus — do $max';
  }

  @override
  String get settingsBorderSection => 'Ramka awatara';

  @override
  String get shopBordersIntro =>
      'Ramki i akcesoria do awatara. Wszyscy, z którymi rozmawiasz, widzą Twoją ramkę — zablokowana uniemożliwia tylko jej założenie, nigdy wyświetlanie.';

  @override
  String get shopBorderSubtitle => 'Ramka awatara';

  @override
  String get shopFreeLabel => 'Za darmo';

  @override
  String get notificationModePrivate => 'Prywatne';

  @override
  String get notificationModePrivateDesc =>
      'Okresowo sprawdza nowe wiadomości w tle bez używania usług push Google. Powiadomienia mogą być opóźnione, ale żaden sygnał nie przechodzi przez usługi firm trzecich.';

  @override
  String get connectSectionOneOnOne => 'Czat jeden na jeden';

  @override
  String get connectSectionGroups => 'Grupy';

  @override
  String get connectByteBudgetTitle => 'Budżet bajtów';

  @override
  String get connectByteBudgetDesc =>
      'Nieograniczony czas, ograniczony budżet. Najlepsze dla bliskich znajomych, rodziny i rozmów o wysokim bezpieczeństwie.';

  @override
  String get connectTimeWiltTitle => 'Time Wilt';

  @override
  String get connectTimeWiltDesc =>
      'Ograniczony czas, nieograniczony budżet. Idealne do poznawania nowych osób, randek i szybkich spotkań.';

  @override
  String get connectRemotePairTitle => 'Zdalne parowanie (test)';

  @override
  String get connectRemotePairDesc =>
      'Tylko do testów: sparuj się z testerem przez serwer za pomocą PIN-u i hasha tożsamości.';

  @override
  String get connectByteBudgetGroupTitle => 'Grupa z budżetem bajtów';

  @override
  String get connectByteBudgetGroupDesc =>
      'Nieograniczony czas, ograniczony budżet. Grupa tworzona przez osobiste zapraszanie członków.';

  @override
  String get connectTimeWiltGroupTitle => 'Grupa Time Wilt';

  @override
  String get connectTimeWiltGroupDesc =>
      'Ograniczony czas, nieograniczony budżet. Swobodna grupa, w której wiadomości wygasają z czasem.';

  @override
  String get connectJoinGroupTitle => 'Dołącz do grupy';

  @override
  String get connectJoinGroupDesc =>
      'Ktoś w pobliżu Cię zaprosił — znajdź sygnał grupy.';

  @override
  String get connectJoinRemoteGroupTitle => 'Dołącz do grupy zdalnej (test)';

  @override
  String get connectJoinRemoteGroupDesc =>
      'Tylko do testów: dołącz do grupy testera przez serwer.';

  @override
  String get connectBadgeSoon => 'WKRÓTCE';

  @override
  String get timeWiltLifetimeLabel => 'Czas trwania czatu';

  @override
  String get timeWiltPlusHint => 'Odblokuj do 6 miesięcy z Plus';

  @override
  String get timeWiltExplanation =>
      'Czat przejdzie w tryb tylko do odczytu, gdy skończy się czas.';

  @override
  String timeWiltPairRequestDialogBody(String peerName, String lifetime) {
    return 'Zaakceptować czat Time Wilt od $peerName? Przejdzie w tryb tylko do odczytu za $lifetime.';
  }

  @override
  String timeWiltLifetimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count godzin',
      many: '$count godzin',
      few: '$count godziny',
      one: '1 godzina',
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
      other: '$count miesięcy',
      many: '$count miesięcy',
      few: '$count miesiące',
      one: '1 miesiąc',
    );
    return '$_temp0';
  }

  @override
  String get timeWiltLifetimeMoments => 'chwilę';

  @override
  String get navContacts => 'Kontakty';

  @override
  String get contactsTitle => 'Kontakty';

  @override
  String get contactsSectionFriends => 'Znajomi';

  @override
  String get contactsEmptyTitle => 'Brak kontaktów';

  @override
  String get contactsEmptyBody =>
      'Dodaj kogoś z istniejącego czatu, aby zobaczyć go tutaj.';

  @override
  String get contactsOwnProfile => 'Twój profil';

  @override
  String get contactsOwnProfileHint =>
      'Dotknij, aby ustawić status lub znikającą relację';

  @override
  String contactRequestSent(String name) {
    return 'Wysłano prośbę o kontakt do $name';
  }

  @override
  String contactRequestReceived(String name) {
    return '$name chce dodać Cię do kontaktów';
  }

  @override
  String get contactRequestApproved => 'Prośba o kontakt zaakceptowana';

  @override
  String get contactRequestDeclined => 'Prośba o kontakt odrzucona';

  @override
  String get contactRequestApprove => 'Zaakceptuj';

  @override
  String get contactRequestDeny => 'Odrzuć';

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
  String get contactProfileOpenChat => 'Otwórz czat';

  @override
  String get contactProfileRemove => 'Usuń kontakt';

  @override
  String get contactProfileBlock => 'Zablokuj użytkownika';

  @override
  String get contactProfileStatusPlaceholder => 'Brak statusu';

  @override
  String get contactProfileEmergencyChat => 'Czat awaryjny';

  @override
  String get contactPin => 'Przypnij na górze';

  @override
  String get contactUnpin => 'Odepnij';

  @override
  String get contactUnblock => 'Odblokuj';

  @override
  String get contactsSectionPinned => 'Przypięte';

  @override
  String get contactStatusLabel => 'Status';

  @override
  String get contactStatusHint => 'Podziel się statusem ze swoimi kontaktami…';

  @override
  String get contactStatusSave => 'Zapisz status';

  @override
  String get contactStatusUpdated => 'Status zaktualizowany';

  @override
  String contactRemoveConfirmTitle(String name) {
    return 'Usunąć $name?';
  }

  @override
  String get contactRemoveConfirmBody =>
      'Usuwa tę osobę z listy kontaktów. Możesz dodać ją ponownie później.';

  @override
  String contactBlockConfirmTitle(String name) {
    return 'Zablokować $name?';
  }

  @override
  String get contactBlockConfirmBody =>
      'Ta osoba nie będzie mogła się z Tobą kontaktować ani wysyłać próśb o kontakt.';

  @override
  String get settingsBlockedContacts => 'Zablokowane kontakty';

  @override
  String get settingsBlockedEmpty => 'Brak zablokowanych kontaktów';

  @override
  String get commonRemove => 'Usuń';

  @override
  String get commonBlock => 'Zablokuj';

  @override
  String get contactProfileChatNotFound =>
      'Nie znaleziono czatu dla tego kontaktu — mógł zostać usunięty';

  @override
  String get emergencyChatStart => 'Rozpocznij czat awaryjny';

  @override
  String emergencyChatConfirmTitle(String name) {
    return 'Rozpocząć czat awaryjny z $name?';
  }

  @override
  String emergencyChatConfirmBody(String name) {
    return 'Nie istnieje aktywny czat z $name. Spowoduje to rozpoczęcie 12-godzinnego czatu Time Wilt utworzonego zdalnie, bez parowania osobiście. Istniejący zwiędły czat i jego wiadomości zostaną trwale zniszczone i nigdy nie będzie można go naładować.';
  }

  @override
  String get emergencyChatAlreadyActive =>
      'Masz już aktywny czat z tym kontaktem';

  @override
  String get emergencyChatStarted => 'Czat awaryjny rozpoczęty';

  @override
  String get chatsEmergencyPendingSubtitle => 'Łączenie czatu awaryjnego…';

  @override
  String chatsEmergencyPendingSnackBar(String name) {
    return 'Czat awaryjny z $name oczekuje na połączenie.';
  }

  @override
  String get emergencyChatPending => 'Czat awaryjny w toku…';

  @override
  String get gestureSwipeForContacts =>
      'Przesuń od lewej krawędzi, aby otworzyć kontakty';

  @override
  String get contactProfileSafetyNumber => 'Odcisk klucza tożsamości';

  @override
  String get contactProfileWiltedHint =>
      'Rozpocznij tymczasowy 12-godzinny czat Time Wilt';

  @override
  String get commonCopy => 'Kopiuj';

  @override
  String get commonCopied => 'Skopiowano do schowka';

  @override
  String eventMentionTitle(String name) {
    return '$name wspomniał o Tobie';
  }

  @override
  String eventReplyTitle(String name) {
    return '$name odpowiedział Ci';
  }

  @override
  String get chatNotificationModeAll => 'Wszystkie wiadomości';

  @override
  String get chatNotificationModeMentions => 'Tylko wzmianki i odpowiedzi';

  @override
  String get chatNotificationModeMuted => 'Wycisz (Bez dźwięku)';

  @override
  String get chatNotificationSettingsTitle => 'Powiadomienia';

  @override
  String get chatMuteTitle => 'Wycisz czat';

  @override
  String get chatUnmuteTitle => 'Wyłącz wyciszenie czatu';

  @override
  String get settingsNotifyCategories => 'Kategorie';

  @override
  String get settingsNotifyDirectMessages => 'Wiadomości bezpośrednie';

  @override
  String get settingsNotifyDirectMessagesSubtitle =>
      'Powiadomienia dla czatów 1:1';

  @override
  String get settingsNotifyGroupMessages => 'Wiadomości grupowe';

  @override
  String get settingsNotifyGroupMessagesSubtitle =>
      'Powiadomienia dla czatów grupowych';

  @override
  String get settingsNotifyEvents => 'Zdarzenia bezpieczeństwa i aktywności';

  @override
  String get settingsNotifyEventsSubtitle =>
      'Prośby o kontakt, głosowania nad zniszczeniem grupy, alerty o zrzutach ekranu';

  @override
  String get settingsMutedChatsTitle => 'Wyciszone czaty';

  @override
  String get settingsNoMutedChats => 'Brak wyciszonych czatów';

  @override
  String get settingsUnmute => 'Wyłącz wyciszenie';

  @override
  String get settingsCheckForUpdates => 'Sprawdź aktualizacje';

  @override
  String get settingsCheckingUpdates => 'Sprawdzanie aktualizacji...';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Dostępna aktualizacja: v$version';
  }

  @override
  String get settingsUpToDate => 'WiltKey jest aktualny';

  @override
  String get settingsWhatsNew => 'Co nowego';

  @override
  String get settingsStorageSection => 'Pamięć i historia';

  @override
  String get settingsHistoryLimitTitle => 'Przechowywanie historii wiadomości';

  @override
  String get settingsHistoryLimitDescription =>
      'Automatycznie usuwaj starsze lokalne wiadomości i pliki multimedialne, aby zaoszczędzić miejsce. Klucze szyfrowania i kontakty są zawsze zachowywane.';

  @override
  String get settingsHistoryLimitAll =>
      'Zachowaj wszystkie wiadomości (Bez limitu)';

  @override
  String settingsHistoryLimitCount(int count) {
    return 'Zachowaj ostatnie $count wiadomości';
  }

  @override
  String get chatDetailsClearHistory => 'Wyczyść historię wiadomości';

  @override
  String get chatDetailsClearHistoryConfirm => 'Wyczyść historię';

  @override
  String get chatDetailsClearHistoryDialogBody =>
      'Trwale usunąć całą lokalną historię wiadomości w tym czacie? Klucze szyfrowania i status kontaktu zostaną zachowane.';

  @override
  String get chatDetailsClearHistoryPrune100 =>
      'Zachowaj tylko ostatnie 100 wiadomości';

  @override
  String get chatDetailsClearHistorySuccess =>
      'Historia czatu została wyczyszczona';

  @override
  String get chatDetailsSectionMedia =>
      'Multimedia, wiadomości głosowe i linki';

  @override
  String get chatDetailsMediaPhotos => 'Zdjęcia';

  @override
  String get chatDetailsMediaVoice => 'Wiadomości głosowe';

  @override
  String get chatDetailsMediaLinks => 'Linki';

  @override
  String get chatDetailsNoMedia => 'Brak udostępnionych zdjęć';

  @override
  String get chatDetailsNoVoice => 'Brak wiadomości głosowych';

  @override
  String get chatDetailsNoLinks => 'Brak udostępnionych linków';

  @override
  String get qrConnectTitle => 'Połączenie QR';

  @override
  String get qrConnectScanTab => 'Skanuj QR';

  @override
  String get qrConnectMyCodeTab => 'Mój kod QR';

  @override
  String get qrConnectScanPrompt =>
      'Skieruj aparat na kod QR WiltKey, aby połączyć się natychmiast';

  @override
  String get qrConnect7DayNotice =>
      'Połączenia zdalne rozpoczynają się automatycznie jako 7-dniowy czat Time Wilt. Do doładowania szyfru jednorazowego wymagane jest osobiste parowanie BLE.';

  @override
  String get qrConnectRechargeBlocked =>
      'Ten kontakt już istnieje. Doładowanie notesu wymaga osobistego parowania BLE i nie może być wykonane zdalnie.';

  @override
  String get qrConnectManualPin => 'Wpisz PIN ręcznie';

  @override
  String get qrConnectShowYourCode =>
      'Skanowanie zakończone! Teraz pokaż im swój kod QR.';

  @override
  String get qrConnectFinishPairing => 'Zakończ parowanie';

  @override
  String get qrConnectOutdatedCode =>
      'Ten kod QR pochodzi ze starszej wersji aplikacji. Oboje musicie mieć najnowszą aktualizację, aby połączyć się w ten sposób.';

  @override
  String get qrConnectOwnCode =>
      'To twój własny kod QR — skieruj aparat na ich kod.';

  @override
  String get qrConnectAlreadyPaired =>
      'Masz już czat z tą osobą. Odświeżenie istniejącego czatu wymaga osobistego parowania.';

  @override
  String get testRelayBanner => 'SERWER TESTOWY — NIEPRODUKCYJNY';

  @override
  String get securingTitle => 'Zabezpieczanie połączenia';

  @override
  String get securingBody =>
      'Twoje urządzenie weryfikuje się na przekaźniku przed połączeniem. Ten jednorazowy proof-of-work chroni wszystkich przed spamem i nadużyciami — bez numeru telefonu, bez e-maila, bez konta.';

  @override
  String get securingWorking => 'WERYFIKACJA URZĄDZENIA — TRWA…';

  @override
  String get securingOnceNote =>
      'Dzieje się to tylko przy pierwszym połączeniu. Późniejsze ponowne połączenia są natychmiastowe.';

  @override
  String get puzzleInstruction =>
      'Fragment twojej weryfikacji połączenia jest przesunięty. Przesuń pasek, aż obraz wskoczy na miejsce, a następnie potwierdź.';

  @override
  String get puzzleLockIn => 'Zatwierdź';

  @override
  String get puzzleFailedRetry =>
      'Nie udało się dopasować — zaczynamy nową weryfikację…';

  @override
  String get reauthenticatingBanner =>
      'PONOWNE UWIERZYTELNIANIE — PROSZĘ CZEKAĆ…';

  @override
  String get badgePlayPlus => 'Sklep Play · Plus';

  @override
  String get badgePlayPlusSubtitle =>
      'Zweryfikowana kompilacja Google Play + Wspierający Plus';

  @override
  String get badgePlayPlusExplainer =>
      'Ten użytkownik korzysta z oficjalnej, niezmodyfikowanej kompilacji zweryfikowanej przez Google Play Integrity i aktywnie wspiera WiltKey z aktywnym członkostwem Plus.';

  @override
  String get badgePlayVerified => 'Sklep Play';

  @override
  String get badgePlayVerifiedSubtitle =>
      'Zweryfikowana kompilacja Google Play';

  @override
  String get badgePlayVerifiedExplainer =>
      'Ten użytkownik korzysta z oficjalnej, niezmodyfikowanej kompilacji zweryfikowanej kryptograficznie przez Google Play Integrity.';

  @override
  String get badgeFoss => 'Open Source';

  @override
  String get badgeFossSubtitle => 'Kompilacja społecznościowa / FOSS';

  @override
  String get badgeFossExplainer =>
      'Ten klient działa na kompilacji otwartoźródłowej lub niestandardowej. Ponieważ nie uruchamia własnościowych usług Google, jest traktowany jako kompilacja społecznościowa. Wszystkie wiadomości i szyfrowanie pozostają w 100% bezpieczne i prywatne.';

  @override
  String get groupAnonymousMember => 'Członek';

  @override
  String get groupMemberRoleHost => 'Host';

  @override
  String get contactSelfBadge => 'Ty';

  @override
  String get chatAttachContentTitle => 'Dołącz do czatu';

  @override
  String get chatAttachPhotos => 'Zdjęcia i aparat';

  @override
  String get chatAttachPhotosSubtitle => 'Zrób zdjęcie lub wybierz z galerii';

  @override
  String get chatAttachPixelArt => 'Pixel art i awatary';

  @override
  String get chatAttachPixelArtSubtitle =>
      'Narysuj pixel art lub wyślij z zapisanych szablonów';

  @override
  String get chatAttachVideo => 'Wideo';

  @override
  String get chatAttachVideoSubtitle =>
      'Szyfrowane krótkie klipy wideo w przyszłej aktualizacji';

  @override
  String get chatAttachComingSoon => 'WKRÓTCE';

  @override
  String get chatPixelArtDrawNew => 'Narysuj nowy pixel art';

  @override
  String get chatPixelArtTemplates => 'Zapisane szablony awatarów';

  @override
  String get chatPixelArtSend => 'Wyślij do czatu';

  @override
  String get chatPixelArtNoTemplates => 'Brak zapisanych szablonów awatarów';

  @override
  String get chatPixelArtActionTitle => 'Opcje pixel art';

  @override
  String get chatPixelArtActionApplyAvatar => 'Ustaw jako mój awatar profilu';

  @override
  String get chatPixelArtActionSaveTemplate => 'Zapisz w szablonach awatarów';

  @override
  String get chatPixelArtActionSaveEmoji => 'Zapisz jako własną emotikonę';

  @override
  String get chatPixelArtActionExportPng => 'Eksportuj PNG do zdjęć';

  @override
  String get chatPixelArtActionAppliedAvatarSuccess =>
      'Awatar profilu zaktualizowany i zsynchronizowany';

  @override
  String get chatPixelArtActionSavedTemplateSuccess =>
      'Zapisano w bibliotece szablonów awatarów';

  @override
  String get chatPixelArtActionExportedPngSuccess =>
      'Zapisano obraz PNG w zdjęciach';

  @override
  String get chatSearchHint => 'Szukaj w czacie...';

  @override
  String get chatSearchNoMatches => '0 wyników';

  @override
  String get contactPrivateNoteTitle => 'Prywatne notatki i pseudonim';

  @override
  String get contactPrivateNoteHint =>
      'Dodaj prywatne notatki o tym kontakcie (przechowywane tylko lokalnie)...';

  @override
  String get contactCustomNicknameTitle => 'Własny pseudonim';

  @override
  String get contactCustomNicknameHint =>
      'Zastąp nazwę wyświetlaną lokalnie...';

  @override
  String get contactNotesSaved => 'Szczegóły kontaktu zostały zapisane';

  @override
  String get onboardingSocialTitle => 'Konto społecznościowe WiltKey';

  @override
  String get onboardingSocialExplanation =>
      'Włącza Twój profil społecznościowy WiltKey i wykrywanie z pomocą serwera. Twój publiczny klucz tożsamości jest rejestrowany na serwerze przekaźnikowym (i może zostać w każdej chwili trwale odwołany/wyczyszczony przez Ciebie), aby weryfikować autorstwo 24-godzinnych znikających relacji i postów transmisyjnych. Cała zawartość pozostaje szyfrowana end-to-end w modelu zero-knowledge.';

  @override
  String get onboardingSocialEnable => 'Włącz WiltKey Social (Zalecane)';

  @override
  String get onboardingSocialEnableDesc =>
      'Udostępniaj 24-godzinne znikające relacje wspólnym kontaktom, wysyłaj własny pixel art i bierz udział w transmisjach społecznościowych.';

  @override
  String get onboardingSocialZeroServer =>
      'Tryb zerowej ilości danych na serwerze (Całkowita prywatność)';

  @override
  String get onboardingSocialZeroServerDesc =>
      'Maksymalna anonimowość. Ściśle peer-to-peer i bezpośrednie wiadomości 1:1/grupowe bez rejestracji tożsamości na serwerze. Zdalne funkcje społecznościowe i relacje są wyłączone.';

  @override
  String get settingsSocialAccountTitle => 'Konto społecznościowe WiltKey';

  @override
  String get settingsSocialAccountSubtitle =>
      'Zezwalaj na 24-godzinne relacje i odkrywanie wspomagane przez serwer';

  @override
  String get settingsStoriesReelTitle => 'Pasek relacji na pulpicie';

  @override
  String get settingsStoriesReelSubtitle =>
      'Pokazuj 24-godzinne relacje na górze karty czatów';

  @override
  String get connectTabConnect => 'Połącz';

  @override
  String get connectTabSocial => 'Społeczność';

  @override
  String get forcedUpdateTitle => 'Wymagana aktualizacja';

  @override
  String get forcedUpdateSubtitle =>
      'Wymagana jest obowiązkowa aktualizacja, aby nadal bezpiecznie korzystać z WiltKey.';

  @override
  String get forcedUpdateAction => 'Zaktualizuj teraz';

  @override
  String get forcedUpdateCheckAgain => 'Sprawdź ponownie';

  @override
  String get forcedUpdateSecurityNotice =>
      'Ta wersja zawiera krytyczne aktualizacje protokołu lub bezpieczeństwa. Starsze wersje nie mogą już komunikować się z siecią.';

  @override
  String get forcedUpdateWhatsNew => 'Co nowego w tej aktualizacji';

  @override
  String get settingsSwipeGesturesTitle => 'Gesty przesuwania czatu';

  @override
  String get settingsSwipeGesturesSubtitle =>
      'Dostosuj akcje przesuwania w prawo i w lewo na liście czatów';

  @override
  String get settingsSwipeRight => 'Przesunięcie w prawo';

  @override
  String get settingsSwipeLeft => 'Przesunięcie w lewo';

  @override
  String get swipeActionMarkRead => 'Przeczytane / Nieprzeczytane';

  @override
  String get swipeActionMute => 'Wycisz / Wyłącz wyciszenie';

  @override
  String get swipeActionPin => 'Przypnij / Odepnij';

  @override
  String get swipeActionArchive => 'Archiwizuj';

  @override
  String get swipeActionNone => 'Wyłączone';

  @override
  String get chatSwipeMarkRead => 'Przeczytane';

  @override
  String get chatSwipeMarkUnread => 'Nieprzeczytane';

  @override
  String get chatSwipePin => 'Przypnij';

  @override
  String get chatSwipeUnpin => 'Odepnij';

  @override
  String get chatSwipeMute => 'Wycisz';

  @override
  String get chatSwipeUnmute => 'Wyłącz wyciszenie';

  @override
  String get chatSwipeArchive => 'Archiwizuj';

  @override
  String get chatAttachVideoSubtitleEnabled =>
      'Nagraj do 15 s lub wybierz z galerii';

  @override
  String get chatVideoSelectSourceTitle => 'Wyślij wideo';

  @override
  String get chatVideoQualityLabel => 'Jakość';

  @override
  String get chatVideoQualityLow => 'Niska';

  @override
  String get chatVideoQualityMedium => 'Średnia';

  @override
  String get chatVideoQualityHigh => 'Wysoka';

  @override
  String get chatVideoCompressionFailed =>
      'Nie udało się skompresować tego klipu. Spróbuj wybrać krótszy klip lub niższą jakość.';

  @override
  String get chatVideoRecordCamera => 'Nagraj wideo (Aparat)';

  @override
  String get chatVideoPickGallery => 'Wybierz wideo z galerii';

  @override
  String get chatVideoCompressing => 'Kompresowanie wideo...';

  @override
  String chatVideoTooLarge(String size) {
    return 'Wideo przekracza limit rozmiaru ($size)';
  }

  @override
  String get chatVideoTooLong => 'Wideo przekracza limit długości 15 sekund';

  @override
  String get chatVideoSaveGallery => 'Zapisz wideo w galerii';

  @override
  String get chatVideoSavedGallery => 'Wideo zapisano w galerii';

  @override
  String get chatVideoError => 'Nie można odtworzyć klipu wideo';
}
