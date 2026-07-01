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
  String get navPair => 'Parowanie';

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
  String get settingsProfileBrushColor => 'Kolor pędzla';

  @override
  String get settingsProfileChipIdenticon => 'Identikon';

  @override
  String get settingsProfileChipClear => 'Wyczyść';

  @override
  String get settingsProfileChipRandom => 'Losowo';

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
      'Sprawdza nowe wiadomości co około 10 minut. Oszczędza baterię.';

  @override
  String get notificationModeInstant => 'Natychmiastowe';

  @override
  String get notificationModeInstantDesc =>
      'Utrzymuje aktywne bezpieczne połączenie w tle dla natychmiastowych powiadomień. Pokazuje stałe powiadomienie i zużywa więcej baterii.';

  @override
  String get notificationNewMessageBody => 'Masz nową wiadomość';

  @override
  String get notificationSecureLinkActive => 'Bezpieczne połączenie aktywne';

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
      'Odblokowuj odciskiem palca zamiast PIN-em. Po 4 godzinach bezczynności PIN jest znów wymagany.';

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
}
