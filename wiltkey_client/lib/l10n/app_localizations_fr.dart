// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navChats => 'Chats';

  @override
  String get navPair => 'Connecter';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get nukedTitle => 'Appareil réinitialisé';

  @override
  String get nukedExplanation =>
      'Tous les messages et clés ont été supprimés de cet appareil. La base de données sécurisée a été vidée.';

  @override
  String get nukedResetButton => 'Créer une nouvelle identité';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonSave => 'Sauvegarder';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonFinish => 'Terminer';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue sur Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'Wiltkey est une messagerie privée qui n\'enregistre aucune métadonnée, aucun log ni historique de serveur. Les messages sont chiffrés localement et s\'autodétruisent si une capture d\'écran est détectée.';

  @override
  String get onboardingWelcomeNoHistory =>
      'Pas d\'historique de serveur. Pas de clés de récupération.';

  @override
  String get onboardingIntelTitle => 'Sécurité';

  @override
  String get onboardingLanguageDescription =>
      'Choisis ta langue préférée pour continuer. Tu peux la changer à tout moment dans les Réglages.';

  @override
  String get onboardingFactLanguageTitle => 'Choix de la langue';

  @override
  String get onboardingFactLanguageBody =>
      'Choisis ta langue préférée pour continuer. Tu peux la changer à tout moment dans les Réglages. Ton choix est enregistré localement.';

  @override
  String get onboardingThemeTitle => 'Choisis ton thème';

  @override
  String get onboardingThemeDescription =>
      'Choisis un thème ci-dessous. Tu pourras le modifier plus tard dans les Paramètres.';

  @override
  String get onboardingProfileTitle => 'Ton identité';

  @override
  String get onboardingProfileUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get onboardingProfileUsernameHint => 'Saisis un nom d\'utilisateur';

  @override
  String get onboardingProfileCodenameLabel =>
      'Code de connexion (5 lettres/chiffres)';

  @override
  String get onboardingProfileCodenameExplanation =>
      'Ce code est partagé lors du jumelage pour te connecter avec tes amis à proximité.';

  @override
  String get onboardingProfileUsernameError =>
      'S\'il te plaît, choisis un nom d\'utilisateur.';

  @override
  String get onboardingProfileCodenameError =>
      'Le code doit comporter exactement 5 caractères.';

  @override
  String get onboardingAvatarTitle => 'Avatar Pixel';

  @override
  String get onboardingAvatarBrushColor => 'Couleur du pinceau';

  @override
  String get onboardingAvatarRandom => 'Aléatoire';

  @override
  String get onboardingAvatarClear => 'Effacer';

  @override
  String get onboardingPinTitle => 'Code PIN';

  @override
  String get onboardingPinExplanation =>
      'Configure un code PIN (4 à 6 chiffres) pour protéger tes discussions. Tu devras le saisir à chaque ouverture de l\'application. Si tu l\'oublies, tes messages seront définitivement perdus.';

  @override
  String get onboardingPinEnter => 'Saisis le code PIN';

  @override
  String get onboardingPinConfirm => 'Confirme le code PIN';

  @override
  String get onboardingPinLengthError =>
      'Le code PIN doit comporter entre 4 et 6 chiffres.';

  @override
  String get onboardingPinMatchError => 'Les codes PIN ne correspondent pas.';

  @override
  String onboardingSetupFailed(String error) {
    return 'La configuration a échoué: $error';
  }

  @override
  String get onboardingFactMetadataTitle => 'LE PROBLÈME DES MÉTADONNÉES';

  @override
  String get onboardingFactMetadataBody =>
      'La plupart des applications chiffrent le contenu des messages mais tracent avec qui tu parles, quand et à quelle fréquence. Wiltkey n\'enregistre aucune métadonnée, aucun log ni aucune connexion.';

  @override
  String get onboardingFactThemeTitle => 'CHOISIS TON THÈME';

  @override
  String get onboardingFactThemeBody =>
      'Les thèmes sont purement visuels. Les mêmes standards de sécurité s\'appliquent à tous. Tu peux changer de thème quand tu veux dans les Paramètres.';

  @override
  String get onboardingFactOtpTitle => 'SECRET ABSOLU';

  @override
  String get onboardingFactOtpBody =>
      'Wiltkey utilise des masques jetables (OTP) où les clés font la taille du message, sont aléatoires et ne sont jamais réutilisées. Cela offre une sécurité parfaite, rendant les messages impossibles à déchiffrer sans les clés.';

  @override
  String get onboardingFactLimitsTitle => 'LIMITES DE CONNEXION';

  @override
  String get onboardingFactLimitsBody =>
      'Les limites de capacité encouragent les relations authentiques et réfléchies. Restreindre l\'espace garantit que les conversations restent intentionnelles et ancrées dans le monde réel.';

  @override
  String get onboardingFactKdfTitle => 'DURCISSEMENT DU PIN';

  @override
  String get onboardingFactKdfBody =>
      'Un code PIN standard peut être forcé en quelques millisecondes. Wiltkey le fait passer par une fonction de durcissement, rendant les attaques de force brute sur la base locale impossibles.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsTabProfile => 'Profil';

  @override
  String get settingsTabSecurity => 'Sécurité';

  @override
  String get settingsSecuritySectionAccess => 'Accès et déverrouillage';

  @override
  String get settingsSecuritySectionDanger => 'Zone de danger';

  @override
  String get settingsTabNetwork => 'Réseau';

  @override
  String get settingsTabAlerts => 'Notifications';

  @override
  String get settingsSavedIndicator => 'Enregistré';

  @override
  String get settingsProfileSectionAppearance => 'Apparence';

  @override
  String get settingsProfileSectionAvatar => 'Avatar Pixel Art';

  @override
  String get settingsProfileSectionProfile => 'Profil';

  @override
  String get settingsProfileSectionOtherVisuals => 'Autres visuels';

  @override
  String get settingsThemeLabel => 'Thème';

  @override
  String get settingsPixelArtEditor => 'Éditeur pixel art';

  @override
  String get settingsProfileBrushColor => 'Couleur du pinceau';

  @override
  String get settingsProfileChipIdenticon => 'Identicon';

  @override
  String get settingsProfileChipClear => 'Effacer';

  @override
  String get settingsProfileChipRandom => 'Aléatoire';

  @override
  String get avatarEditButton => 'Modifier l\'avatar';

  @override
  String get groupCreateEditIcon => 'Modifier l\'icône';

  @override
  String get settingsProfileUsername => 'Nom d\'utilisateur';

  @override
  String get settingsProfileBleNick => 'Pseudo (5 caractères)';

  @override
  String get settingsProfileKeyhash => 'Identifiant du compte';

  @override
  String get settingsProfileKeyhashCopied =>
      'Identifiant copié dans le presse-papiers';

  @override
  String get settingsProfileChangePinButton => 'Modifier le code PIN';

  @override
  String get settingsProfileResetIdentityButton => 'Réinitialiser le compte';

  @override
  String get settingsResetConfirmTitle => 'Réinitialiser l\'identité ?';

  @override
  String get settingsResetConfirmBody =>
      'Cela supprimera définitivement tous les messages, contacts et générera une nouvelle identité. Cette action est irréversible.';

  @override
  String get settingsResetConfirmCancel => 'Annuler';

  @override
  String get settingsResetConfirmReset => 'Réinitialiser';

  @override
  String get settingsChangePinTitle => 'Modifier le code PIN';

  @override
  String get changePinVerifyTitle => 'Vérifier le code PIN actuel';

  @override
  String get changePinVerifyPrompt =>
      'Saisis ton code PIN actuel pour continuer.';

  @override
  String get changePinSetTitle => 'Définir le nouveau code PIN';

  @override
  String get settingsChangePinOldPin => 'Saisis le code PIN actuel';

  @override
  String get settingsChangePinNewPin =>
      'Saisis le nouveau code PIN (4-6 chiffres)';

  @override
  String get settingsChangePinConfirmPin => 'Confirme le nouveau code PIN';

  @override
  String get settingsChangePinEmptyFieldsError =>
      'S\'il te plaît, remplis tous les champs.';

  @override
  String get settingsChangePinLengthError =>
      'Le nouveau PIN doit comporter 4 à 6 chiffres.';

  @override
  String get settingsChangePinMatchError =>
      'Les nouveaux codes PIN ne correspondent pas.';

  @override
  String get settingsChangePinUpdatedSnackBar => 'Code PIN mis à jour.';

  @override
  String get settingsChangePinIncorrectError =>
      'Le code PIN actuel est incorrect.';

  @override
  String get settingsNetworkRoutingTitle => 'Réseau';

  @override
  String get settingsNetworkDevRelayToggle =>
      'Utiliser le serveur de développement';

  @override
  String get settingsNetworkDevRelayUrlLabel => 'Adresse URL du serveur de dev';

  @override
  String get settingsNetworkDevRelayDescription =>
      'Activer cette option remplace le serveur de production par un serveur local.';

  @override
  String get settingsNetworkActiveGateway => 'Adresse URL du serveur actuel';

  @override
  String get settingsNetworkDiagnostics => 'Diagnostics';

  @override
  String get settingsNetworkDebugButton => 'Console de debug';

  @override
  String get settingsDebugButtonsToggle => 'Boutons de débogage';

  @override
  String get settingsDebugButtonsDescription =>
      'Affiche le bouton de la console terminal dans la liste des discussions et dans les discussions.';

  @override
  String get settingsDebugTitle => 'Console de debug';

  @override
  String get settingsAlertsBackgroundNotifications =>
      'Notifications en arrière-plan';

  @override
  String get settingsAlertsExplanation =>
      'Les notifications afficheront seulement \'Tu as reçu un message\'. Tes messages restent chiffrés jusqu\'à ce que tu déverrouilles l\'application.';

  @override
  String get settingsTextSizeLabel => 'Taille du texte';

  @override
  String get settingsTextSizePreview =>
      'Voilà à quoi ressembleront tes messages.';

  @override
  String get settingsLanguageLabel => 'Langue';

  @override
  String get settingsLanguageSystem => 'Langue système';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageHungarian => 'Magyar (Hongrois)';

  @override
  String get settingsLanguagePolish => 'Polski (Polnisch)';

  @override
  String get settingsLanguageGerman => 'Deutsch (Allemand)';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageSwedish => 'Svenska (Suédois)';

  @override
  String get settingsLanguageChinese => '中文 (Chinois)';

  @override
  String get notificationModeOff => 'Désactivé';

  @override
  String get notificationModeOffDesc =>
      'Pas de vérification en arrière-plan. Tu ne verras les messages qu\'à l\'ouverture de l\'application.';

  @override
  String get notificationModeLowPower => 'Économie d\'énergie';

  @override
  String get notificationModeLowPowerDesc =>
      'Vérifie régulièrement les nouveaux messages en arrière-plan – rapidement juste après la fermeture de l\'application, puis moins souvent pour économiser la batterie. Pas de connexion permanente, les alertes peuvent donc être retardées.';

  @override
  String get notificationModeInstant => 'Instantané';

  @override
  String get notificationModeInstantDesc =>
      'Optionnel. Maintient une connexion chiffrée de bout en bout en arrière-plan pour synchroniser tes messages entrants en temps réel, signalée par une notification permanente. Wiltkey utilise ceci au lieu des services de notifications push de Google ou Apple pour la confidentialité, ce qui lui permet de fonctionner même sans les services Google Play – au prix d\'une consommation de batterie plus élevée.';

  @override
  String get notificationNewMessageBody => 'Tu as un message';

  @override
  String get notificationSecureLinkActive =>
      'Synchronisation des messages sécurisés';

  @override
  String get onboardingNotificationsTitle => 'Alertes';

  @override
  String get onboardingNotificationsExplanation =>
      'Wiltkey n\'utilise pas les notifications push de Google ou d\'Apple — rien concernant vos messages ne transite par leurs serveurs. Choisissez comment vous souhaitez être alerté. Vous pourrez modifier ce choix à tout moment dans les Paramètres.';

  @override
  String get onboardingFactPushTitle => 'AUCUN SERVEUR PUSH';

  @override
  String get onboardingFactPushBody =>
      'Les applications classiques acheminent vos notifications via Google ou Apple, révélant qui vous écrit et quand. Wiltkey ne le fait jamais — par défaut, aucune vérification en arrière-plan, et toute alerte s\'exécute entièrement sur votre appareil.';

  @override
  String get notificationModeInstantDescFcm =>
      'Facultatif. Utilise le service push de Google comme un simple signal de réveil pour recevoir les nouveaux messages en temps réel. Seul un ping sans contenu passe par Google — jamais vos messages, qui restent chiffrés de bout en bout sur le relais jusqu\'à ce que votre appareil les récupère. Plus léger pour la batterie qu\'une connexion permanente.';

  @override
  String get onboardingNotificationsExplanationFcm =>
      'Pour les alertes en temps réel, cette version utilise le service push de Google uniquement comme signal de réveil — un ping sans contenu, jamais vos messages, qui ne touchent jamais les serveurs de Google. Choisissez comment être averti ; vous pourrez changer cela à tout moment dans les Réglages.';

  @override
  String get onboardingFactPushTitleFcm => 'PUSH SANS CONTENU';

  @override
  String get onboardingFactPushBodyFcm =>
      'Les applications classiques acheminent le contenu de vos notifications via Google, révélant ce qui est envoyé et quand. Cette version utilise Google uniquement comme un ping de réveil sans contenu — aucune donnée de message, aucune métadonnée lisible — et tout reste chiffré de bout en bout.';

  @override
  String get chatsLockedSubtitle =>
      'Verrouillé · jumelle en personne pour déverrouiller';

  @override
  String chatsMemberCount(int count) {
    return '$count membres';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: 'contacts',
      one: 'contact',
    );
    return '$totalCount $_temp0 · $lockedCount verrouillés';
  }

  @override
  String get chatsTitle => 'Chats';

  @override
  String get chatsPopupPair => 'Jumeler un appareil';

  @override
  String get chatsPopupCreateGroup => 'Créer un groupe';

  @override
  String get chatsPopupJoinGroup => 'Rejoindre un groupe';

  @override
  String get chatsSearchHint => 'Rechercher';

  @override
  String get chatsEmptyNoMatches => 'Aucun résultat';

  @override
  String get chatsEmptyNoChats => 'Pas encore de discussion';

  @override
  String get chatsEmptyPairInstruction =>
      'Jumelle ton appareil en personne avec quelqu\'un pour commencer.';

  @override
  String get chatsEmptyPairButton => 'Jumeler un appareil';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return 'MOI $remaining · PEER $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded =>
      'Trop de tentatives incorrectes. Appareil effacé.';

  @override
  String pinAccessDenied(int attempts) {
    return 'Code PIN incorrect. Il te reste $attempts tentatives.';
  }

  @override
  String get pinMinLengthError => 'Le code PIN doit faire au moins 4 chiffres.';

  @override
  String get pinPurgeConfirmTitle => 'Réinitialiser l\'appareil ?';

  @override
  String get pinPurgeConfirmBody =>
      'Code PIN oublié ? Cela supprimera définitivement tous tes messages et réinitialisera ton compte. Cette action est irréversible.';

  @override
  String get pinPurgeConfirmButton => 'Réinitialiser l\'appareil';

  @override
  String get pinLockedTitle => 'Verrouillé';

  @override
  String get pinLockedSubtitle => 'Saisis ton PIN pour déverrouiller';

  @override
  String get pinUnlockButton => 'Déverrouiller';

  @override
  String get pinUseFingerprintButton => 'Utiliser l\'empreinte';

  @override
  String get settingsBiometricToggle => 'Déverrouillage par empreinte';

  @override
  String get settingsBiometricDescription =>
      'Déverrouille avec ton empreinte au lieu du code PIN. Le PIN reste requis après la période définie ci-dessous.';

  @override
  String get settingsBiometricIdleTitle => 'Repli sur le PIN';

  @override
  String get settingsBiometricIdleDescription =>
      'Redemander le PIN après ce délai sans déverrouillage.';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours h';
  }

  @override
  String get settingsBiometricIdleNever => 'Jamais';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Impossible d\'activer le déverrouillage par empreinte.';

  @override
  String get pinForgotButton => 'PIN oublié ? Réinitialiser l\'appareil';

  @override
  String get pairTitle => 'Jumeler les appareils';

  @override
  String get pairRescanTooltip => 'Actualiser la recherche';

  @override
  String get pairBluetoothOffWarning =>
      'Le Bluetooth est désactivé. L\'association a besoin du Bluetooth pour détecter les appareils à proximité — activez-le pour continuer.';

  @override
  String get pairBluetoothTurnOnButton => 'Activer le Bluetooth';

  @override
  String get pairDoNotExitWarning =>
      'Garde WiltKey ouvert — ne change pas d\'application et ne quitte pas avant que le jumelage soit terminé sur les DEUX appareils.';

  @override
  String get pairRequestDialogTitle => 'Demande de jumelage';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName veut se jumeler.\n\nTaille du chat: $size.\n\nAccepter le jumelage sécurisé ?';
  }

  @override
  String get pairRequestReject => 'Refuser';

  @override
  String get pairRequestAccept => 'Accepter';

  @override
  String get pairPingStatusPinging => 'Test...';

  @override
  String pairPingStatusLatency(String latency) {
    return 'Latence: ${latency}ms';
  }

  @override
  String get pairPingStatusFailed => 'Échoué';

  @override
  String get pairPingStatusTest => 'Tester la connexion';

  @override
  String get pairDeviceNameLabel => 'Nom de ton appareil';

  @override
  String get pairDeviceNameHint => 'Saisis un nom';

  @override
  String get pairDiscoverableTitle => 'Rendre l\'appareil visible';

  @override
  String get pairDiscoverableSubtitle =>
      'Permettre aux amis à proximité de te trouver';

  @override
  String get pairNearbyDevicesTitle => 'Appareils à proximité';

  @override
  String get pairNearbyDevicesInstruction =>
      'Rapproche les deux appareils pour les connecter.';

  @override
  String get pairDirectSyncFormRelayLabel => 'URL du serveur';

  @override
  String get pairDirectSyncFormSyncButton => 'Connecter les appareils';

  @override
  String get pairSyncingConnecting => 'Connexion...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return 'Génération de la clé sécurisée ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return 'Clé: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return '$percent% complété';
  }

  @override
  String get pairSuccessConnectionSecured => 'Connecté avec succès';

  @override
  String pairSuccessGroupBody(String groupName) {
    return 'Tu as rejoint le groupe \"$groupName\". Les clés sécurisées ont été générées localement sur ton appareil.';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return 'Clés sécurisées échangées et générées sur ton appareil. Connecté à $title avec une capacité de discussion de $label.';
  }

  @override
  String get pairSuccessReturnButton => 'Aller aux chats';

  @override
  String get chatDetailsTitle => 'Détails';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return 'Nom: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => 'Relais officiel';

  @override
  String get chatDetailsPrivateNode => 'Nœud privé';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return 'MOI $remaining · PEER $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => 'Profil';

  @override
  String get chatDetailsProfileExplanation =>
      'Les avatars et les pseudos se synchronisent automatiquement lors de la connexion. Tu peux aussi lancer une synchronisation manuelle si nécessaire.';

  @override
  String get chatDetailsProfileSyncButton => 'Synchroniser le profil';

  @override
  String get chatDetailsProfileSnackBar => 'Profil envoyé.';

  @override
  String get chatDetailsSectionPermissions => 'Autorisations';

  @override
  String get chatDetailsPermissionsPhotos => 'Autoriser le partage de photos';

  @override
  String get chatDetailsPermissionsEmojis => 'Emojis personnalisés';

  @override
  String get chatDetailsPermissionsEmojisAvailable => 'Disponibles';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize =>
      'Nécessite un chat plus grand';

  @override
  String get chatDetailsSectionMetadata => 'Espace de métadonnées';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return 'Cette discussion alloue $budget sur les $max réservés aux réglages, photos de profil et emojis personnalisés.';
  }

  @override
  String get chatDetailsSectionLanes => 'Canaux sécurisés';

  @override
  String get chatDetailsLanesMySend => 'Ma capacité d\'envoi';

  @override
  String get chatDetailsLanesPeerSend => 'Sa capacité d\'envoi';

  @override
  String get chatDetailsLanesBorrowed => 'Espace emprunté';

  @override
  String get chatDetailsLanesCapacityLeft => 'Ma capacité restante';

  @override
  String get chatDetailsLanesExplanation =>
      'Si tu es à court de capacité, tu peux emprunter de l\'espace non utilisé à ton correspondant. Cela peut aussi se faire automatiquement pour ne pas couper la conversation.';

  @override
  String get chatDetailsLanesBorrowButton => 'Demander de l\'espace';

  @override
  String get chatDetailsLanesSnackBar => 'Demande envoyée.';

  @override
  String get chatDetailsSectionEmojis => 'Emojis personnalisés';

  @override
  String get chatDetailsEmojisExplanation =>
      'Utilise ces emojis personnalisés dans tes messages avec le format :nom:.';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      'Cette capacité est trop petite pour les emojis personnalisés. Connecte-toi avec plus d\'espace pour les activer.';

  @override
  String get chatDetailsEmojisCreate => 'Créer';

  @override
  String get chatDetailsSectionDestructive => 'Danger Zone';

  @override
  String get chatDetailsNukeButton => 'Détruire la discussion (des deux côtés)';

  @override
  String get chatDetailsDeleteEmojiTitle => 'Supprimer l\'emoji ?';

  @override
  String get chatDetailsDeleteEmojiBody =>
      'Cet emoji personnalisé sera définitivement supprimé. Es-tu sûr ?';

  @override
  String get chatDetailsDeleteEmojiDelete => 'Supprimer';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return 'Ajouté :$name:';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return 'Image trop grande ($cost) pour l\'espace restant ($charge).';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar =>
      'Image trop grande pour être envoyée.';

  @override
  String get chatImageNeedsPlusSnackBar =>
      'Image trop grande pour l\'offre gratuite — WiltKey Plus porte la limite à 50 Mo.';

  @override
  String get chatTapForDetails => 'Appuie pour les détails';

  @override
  String get chatSyncTooltip => 'Synchroniser les messages';

  @override
  String get chatStickerHint => 'Maintenez un emoji pour envoyer un sticker';

  @override
  String get chatSyncStarted => 'Recherche de messages manqués…';

  @override
  String get chatSyncOffline => 'Synchronisation impossible hors ligne.';

  @override
  String get chatEncrypting => 'Chiffrement…';

  @override
  String get chatScreenshotDetected => 'Capture d\'écran détectée';

  @override
  String get chatScreenshotExplanation =>
      'Une capture d\'écran a été détectée. Pour ta sécurité, tu peux effacer tes clés et tes messages dès maintenant.';

  @override
  String get chatScreenshotWipeButton => 'Effacer messages et clés';

  @override
  String get chatScreenshotIgnoreButton => 'Ignorer l\'avertissement';

  @override
  String get chatSimulateScreenshotButton => 'Simuler une capture d\'écran';

  @override
  String chatCostIndicator(String cost) {
    return 'Coût: $cost';
  }

  @override
  String get groupCreateTitle => 'Créer un groupe';

  @override
  String get groupCreatePixelArtIcon => 'Icône du groupe';

  @override
  String get groupCreateRandomIcon => 'Générer';

  @override
  String get groupCreateClearIcon => 'Effacer';

  @override
  String get groupCreateNameLabel => 'Nom du groupe';

  @override
  String get groupCreateNameEmptyValidator => 'Saisis un nom de groupe';

  @override
  String get groupCreateNameLengthValidator => 'Maximum 24 caractères';

  @override
  String get groupCreatePoliciesSection => 'Règles du groupe';

  @override
  String get groupCreatePolicyPadSize => 'Taille globale du groupe';

  @override
  String get groupCreatePolicyLaneSize => 'Capacité par membre';

  @override
  String get groupCreatePolicyMaxMembersLabel => 'Capacité maximale de membres';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return '$count membres max';
  }

  @override
  String get groupCreatePolicyAllowImages => 'Autoriser le partage de photos';

  @override
  String get groupCreatePolicyAllowImagesSub =>
      'Permettre aux membres d\'envoyer des photos';

  @override
  String get groupCreatePolicyPayloadSize => 'Taille max d\'un message';

  @override
  String get groupCreateButton => 'Créer le groupe';

  @override
  String get groupCreateProgressTitle => 'Création du groupe…';

  @override
  String get groupCreateProgressSubtitle =>
      'Préparation de la réserve de chiffrement du groupe et de la capacité des membres. Cela peut prendre un moment — un peu de patience.';

  @override
  String groupCreateFailedSnackBar(String error) {
    return 'Échec de création du groupe: $error';
  }

  @override
  String get pairSyncingAwaitingApproval => 'En attente de son acceptation...';

  @override
  String get pairSyncingCoordinating =>
      'Configuration de l\'échange de clés...';

  @override
  String get pairSyncingStep1 => 'Établissement du lien sécurisé...';

  @override
  String get pairSyncingStep2 => 'Génération de la graine de sécurité...';

  @override
  String pairSyncingStep3(String seed) {
    return 'Échange des clés publiques... $seed';
  }

  @override
  String get pairSyncingStep4 =>
      'Génération des clés de discussion sécurisées...';

  @override
  String get pairSyncingStep5 => 'Vérification de l\'intégrité...';

  @override
  String get pairSyncingStep6 =>
      'Configuration sécurisée terminée avec succès.';

  @override
  String chatRemainingLabel(String bytes) {
    return '$bytes restants';
  }

  @override
  String get chatLockedLabel =>
      'Verrouillé · jumelle en personne pour continuer';

  @override
  String get chatMessageHint => 'Message';

  @override
  String get chatVoiceComingSoon => 'Les messages vocaux arrivent bientôt.';

  @override
  String get chatVoiceHoldHint =>
      'Maintenez pour enregistrer un message vocal.';

  @override
  String get chatVoiceReleaseCancel => 'Relâchez pour annuler';

  @override
  String get chatVoicePermissionDenied =>
      'L\'autorisation du microphone est nécessaire pour enregistrer des messages vocaux.';

  @override
  String get chatVoiceQualityLofi => 'Lo-fi';

  @override
  String get chatVoiceQualityVoice => 'Voix';

  @override
  String get chatVoiceQualityClear => 'Clair';

  @override
  String get chatVoiceUnavailable => 'Message vocal indisponible';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return 'Message vocal trop volumineux ($cost) pour l\'espace restant ($charge).';
  }

  @override
  String get chatDetailsDeleteConfirmTitle => 'Supprimer la discussion ?';

  @override
  String get chatDetailsDeleteConfirmBody =>
      'Cela effacera définitivement tous les messages et clés de chiffrement de ce contact. Cette action est irréversible.';

  @override
  String get chatDetailsDeleteConfirmButton => 'Supprimer la discussion';

  @override
  String get chatsActionArchive => 'Archiver';

  @override
  String get chatsActionNuke => 'Supprimer la discussion et les clés';

  @override
  String get chatsActionDelete => 'Supprimer';

  @override
  String get chatsArchivedBadge => 'Archivé';

  @override
  String get chatsArchivedSubtitle => 'Archivé · lecture seule';

  @override
  String get chatsArchiveConfirmTitle => 'Archiver la discussion ?';

  @override
  String get chatsArchiveConfirmBody =>
      'Cela libère de l\'espace en supprimant la clé à usage unique de cette discussion. Tes messages restent lisibles, mais la discussion passe en lecture seule — tu ne pourras plus y envoyer ni recevoir de messages.';

  @override
  String get chatsArchiveConfirmButton => 'Archiver';

  @override
  String get chatsActionPin => 'Épingler';

  @override
  String get chatsActionUnpin => 'Détacher';

  @override
  String get chatsFilterAll => 'Tout';

  @override
  String get chatsFilterDirect => 'Directs';

  @override
  String get chatsFilterGroups => 'Groupes';

  @override
  String get chatsSectionArchived => 'Archivés';

  @override
  String groupTapForDetails(String hostName) {
    return 'Appuie pour les détails · Hôte: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    return '$count canaux libres disponibles';
  }

  @override
  String get groupHost => 'Hôte';

  @override
  String get groupMember => 'Membre';

  @override
  String get groupDepleted => 'Épuisé';

  @override
  String get groupNotYetMet => 'Pas encore rencontré';

  @override
  String get groupRechargeButton => 'Recharger le groupe';

  @override
  String get groupRechargeTitle => 'Recharger le groupe ?';

  @override
  String get groupRechargeBody =>
      'Recharge le chat avec une nouvelle clé. Tout le monde garde son historique, mais chaque membre doit te recroiser en personne pour revenir dans le groupe.';

  @override
  String get groupRechargeConfirm => 'Recharger';

  @override
  String get groupRechargeDone =>
      'Groupe rechargé — recroise les membres pour les rajouter.';

  @override
  String get groupRechargeNeededComposer =>
      'L\'hôte a rechargé le groupe — recroise-le pour revenir';

  @override
  String get groupTimeWiltToggle => 'Time Wilt group';

  @override
  String get groupTimeWiltToggleSub =>
      'Limited time, unlimited budget. The group wilts to read-only when your timer runs out; meet the host again to renew it.';

  @override
  String get groupTimeWiltMembersLabel => 'Max members';

  @override
  String get groupTimeWiltMembersUpsell => 'Unlock up to 100 members with Plus';

  @override
  String get groupTimeWiltHostInfinite => 'Host · ∞';

  @override
  String get groupTimeWiltRenewComposer =>
      'Wilted — meet the host again to renew your access';

  @override
  String get groupTimeWiltHostAllWilted =>
      'All members have wilted — meet someone again to revive the group';

  @override
  String get groupNukeProposeButton => 'Propose destroying for everyone';

  @override
  String get groupNukeProposeTitle => 'Destroy this group for everyone?';

  @override
  String get groupNukeProposeBody =>
      'Asks the other members to vote. If a majority agree, the group and its history are destroyed on every device. This can\'t be undone.';

  @override
  String get groupNukeProposeConfirm => 'Propose';

  @override
  String get groupNukeVoteTitle => 'Destroy group?';

  @override
  String get groupNukeVoteBody =>
      'A member proposed destroying this group for everyone. If a majority agree, it\'s wiped on every device.';

  @override
  String get groupNukeVoteAllow => 'Agree';

  @override
  String get groupNukeVoteDeny => 'Keep';

  @override
  String get groupNukeVotePending => 'Waiting for members to vote…';

  @override
  String get groupNukeVotePassed => 'The group was destroyed by majority vote.';

  @override
  String get groupNukeVoteFailed =>
      'The proposal to destroy the group did not pass.';

  @override
  String get groupNukeVoteSent =>
      'Proposal sent — waiting for members to vote.';

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
    return 'Synchronisation des détails et messages depuis $name...';
  }

  @override
  String get groupInviteMember => 'Inviter un membre';

  @override
  String get groupLeaveGroup => 'Quitter le groupe';

  @override
  String get groupRemoveMember => 'Retirer le membre';

  @override
  String get groupRemoveMemberTitle => 'Retirer le membre ?';

  @override
  String groupRemoveMemberBody(String name) {
    return 'Retirer $name du groupe ? Cela désactivera sa clé d\'accès.';
  }

  @override
  String get groupLeaveGroupTitle => 'Quitter the groupe ?';

  @override
  String get groupLeaveGroupBody =>
      'Quitter ce groupe ? Cela effacera tes clés locales et l\'historique.';

  @override
  String get groupSyncStepText => 'Synchroniser';

  @override
  String get groupDecryptingImage => 'Déchiffrement de l\'image...';

  @override
  String get chatFileTapToDownload => 'Appuie pour télécharger';

  @override
  String get chatFileDownloadFailed => 'Appuie pour réessayer';

  @override
  String get chatFileKindPhoto => 'Photo';

  @override
  String get chatFileKindVoice => 'Message vocal';

  @override
  String get chatFileKindFile => 'Fichier';

  @override
  String get groupTapToRevealImage => 'Appuie pour révéler l\'image';

  @override
  String groupImageSize(String size) {
    return 'Taille: $size';
  }

  @override
  String get groupImageFailedToLoad => 'Échec du chargement de l\'image';

  @override
  String get groupScreenshotWipeButton => 'Effacer toutes les clés maintenant';

  @override
  String get groupRefillGranted => 'Recharge accordée avec succès.';

  @override
  String groupRefillFailed(String error) {
    return 'Impossible d\'accorder la recharge: $error';
  }

  @override
  String get groupLaneDepleted => 'Canal épuisé';

  @override
  String get groupLaneDepletedExplanation =>
      'Demande une recharge de bytes à l\'hôte du groupe.';

  @override
  String get groupRefillRequestSent => 'Demande de recharge envoyée à l\'hôte.';

  @override
  String get groupRequestRefill => 'Demander une recharge';

  @override
  String groupExceedsSizeLimit(int size) {
    return 'Dépasse la taille limite ($size octets)';
  }

  @override
  String get groupDetailsTitle => 'Détails du groupe';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return 'Espace partagé · Hôte: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => 'Règles du groupe';

  @override
  String get groupDetailsSavePoliciesButton => 'Enregistrer les règles';

  @override
  String get groupDetailsSavePoliciesSnackBar => 'Règles enregistrées.';

  @override
  String get groupDetailsSectionEmojis => 'Emojis personnalisés';

  @override
  String get groupDetailsSectionMetadata => 'Espace de métadonnées';

  @override
  String get groupDetailsMetadataExplanation =>
      'Le canal 0 de l\'espace partagé réserve 1 Mo pour les métadonnées de groupe — l\'icône de groupe, la liste des membres et les emojis personnalisés sont stockés ici.';

  @override
  String get groupDetailsSectionSync => 'Synchronisation';

  @override
  String get groupDetailsSyncExplanation =>
      'Récupère les détails, règles et membres mis à jour auprès de l\'hôte.';

  @override
  String get groupDetailsSyncButton => 'Synchroniser les détails';

  @override
  String get groupDetailsSyncSnackBar => 'Mise à jour demandée à l\'hôte.';

  @override
  String get groupDetailsSectionDestructive => 'Danger Zone';

  @override
  String get groupDetailsLeaveButton => 'Quitter le groupe';

  @override
  String get groupDetailsNukeButton => 'Supprimer le groupe';

  @override
  String get groupDetailsDeleteConfirmTitle => 'Supprimer le groupe ?';

  @override
  String get groupDetailsDeleteConfirmBody =>
      'Cela détruira définitivement ce groupe ainsi que l\'historique et les clés de chiffrement de tous les membres. Cette action est irréversible.';

  @override
  String get groupDetailsDeleteConfirmButton => 'Supprimer le groupe';

  @override
  String get chatImageCompressionTitle => 'Compresser l\'image';

  @override
  String chatImageCompressionOriginal(String size) {
    return 'Original: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return 'Estimé: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return 'Estimé: $size (gain de ~$saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return 'Coût d\'envoi: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation => 'Converti en WebP, max 2000px.';

  @override
  String get chatImageCompressionLowSize => 'Petit';

  @override
  String get chatImageCompressionHighSize => 'Grand';

  @override
  String get chatImageCompressionMaxQuality => 'Qualité max';

  @override
  String get chatImageCompressionUncompressed => 'Non compressé';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return 'Qualité $percent%';
  }

  @override
  String get chatImageCompressionSendHidden =>
      'Envoyer caché (appuyer pour révéler)';

  @override
  String get chatImageCompressionSendButton => 'Envoyer';

  @override
  String get groupGrantRefill => 'Accorder la recharge';

  @override
  String get groupLaneLocked => 'Verrouillé · à court d\'octets';

  @override
  String get groupMembersTitle => 'Membres du groupe';

  @override
  String get groupMembersExplanation =>
      'Tous les membres partagent une capacité commune divisée en canaux. Les messages passent par le serveur.';

  @override
  String get pairChatSize => 'Taille du chat';

  @override
  String get chatSystemConnected => 'Connecté. Discussion sécurisée.';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return 'Tu as rejoint le groupe \"$groupName\". Connexions sécurisées.';
  }

  @override
  String get themeCyberpunkName => 'Neon Grid';

  @override
  String get themeCyberpunkDesc =>
      'L\'original. Obsidienne, cyan éclatant, style terminal.';

  @override
  String get themeGardenName => 'Dusk Garden';

  @override
  String get themeGardenDesc =>
      'Tons de terre douce, lin chaleureux, pétales pour ton budget.';

  @override
  String get themePaperinkName => 'Paper & Ink';

  @override
  String get themePaperinkDesc =>
      'Papier washi chaleureux, encre sumi en dilutions, sceau hanko vermillon.';

  @override
  String get themePickerPlayExclusive =>
      'Ce thème est exclusif à la version Play Store de WiltKey.';

  @override
  String get themePreviewTooltip => 'Aperçu';

  @override
  String get themePreviewSectionDashboard => 'Liste des discussions';

  @override
  String get themePreviewSectionChat => 'Conversation';

  @override
  String get themePreviewSectionEffects => 'Effets spéciaux';

  @override
  String get themePreviewPlayUnlock => 'Jouer l\'animation de déverrouillage';

  @override
  String get themePreviewPlayNuke => 'Jouer l\'animation d\'autodestruction';

  @override
  String get themePreviewApply => 'Utiliser ce thème';

  @override
  String get themePreviewGetInShop => 'L\'obtenir dans la boutique';

  @override
  String get themePreviewMsgThem1 =>
      'Plus que 800 octets sur notre pad, on se voit ?';

  @override
  String get themePreviewMsgMe =>
      'Oui ! Soirée film chez moi ? On rechargera au passage';

  @override
  String get themePreviewMsgThem2 => 'ça marche, j\'apporte à grignoter 🍿';

  @override
  String get themePreviewRowPhoto => 'Photo de la salle d\'escalade 🧗';

  @override
  String get themePreviewRowLost => 'Pad épuisé — se voir pour recharger';

  @override
  String get accessibilityWarningTitle => 'Service d\'accessibilité actif';

  @override
  String accessibilityWarningBody(String names) {
    return 'Un service d\'accessibilité pouvant lire le contenu de l\'écran est actif : $names. C\'est normal pour des outils comme les lecteurs d\'écran ou les gestionnaires de mots de passe. Si vous n\'en avez pas activé, vérifiez vos paramètres d\'accessibilité.';
  }

  @override
  String get accessibilityWarningDismiss => 'Ignorer';

  @override
  String get accessibilityWarningOpenSettings => 'Vérifier les paramètres';

  @override
  String get chatImageCompressionAllowDownload =>
      'Autoriser l\'enregistrement dans la galerie';

  @override
  String get chatImageCompressionWilting =>
      'Image éphémère (disparaît après ouverture)';

  @override
  String get chatImageDownload => 'Télécharger';

  @override
  String get chatImageSaveAs => 'Enregistrer sous';

  @override
  String get chatImageSavedToGallery => 'Enregistré dans la galerie';

  @override
  String get chatImageSaveFailed => 'Impossible d\'enregistrer l\'image';

  @override
  String get chatImageSourceTitle => 'Envoyer une photo';

  @override
  String get chatImageSourceCamera => 'Prendre une photo';

  @override
  String get chatImageSourceGallery => 'Choisir dans la galerie';

  @override
  String get screenshotRequestTooltip => 'Demander une capture';

  @override
  String get screenshotWaiting => 'En attente d\'approbation…';

  @override
  String get screenshotConsentTitle => 'Demande de capture d\'écran';

  @override
  String screenshotConsentBody(String name) {
    return '$name veut enregistrer une capture de cette discussion. Autoriser ?';
  }

  @override
  String get screenshotDenied => 'La demande de capture a été refusée.';

  @override
  String get screenshotCaptureFailed => 'Impossible de réaliser la capture.';

  @override
  String get screenshotWatermark => 'WiltKey — Capture avec consentement';

  @override
  String screenshotRequestInline(String name) {
    return '$name a demandé une capture d\'écran';
  }

  @override
  String get screenshotRequestAllowed =>
      'Vous avez autorisé la capture d\'écran';

  @override
  String get screenshotRequestDeclined =>
      'Vous avez refusé la capture d\'écran';

  @override
  String get screenshotRequestExpired => 'Demande de capture expirée';

  @override
  String get wiltingTapToReveal => 'Appuyez pour voir le message éphémère';

  @override
  String get wiltingMessageTag => 'Message éphémère';

  @override
  String get wiltedMessage => 'Message fané';

  @override
  String get wiltingSheetTitle => 'Message éphémère';

  @override
  String get wiltingSheetBody =>
      'Le message disparaît ce nombre de secondes après que le destinataire l\'a ouvert.';

  @override
  String get wiltingSheetSend => 'Envoyer un message éphémère';

  @override
  String get wiltingHoldToSendHint =>
      'Maintenez pour envoyer un message éphémère';

  @override
  String get replyYou => 'Vous';

  @override
  String get replySomeone => 'Quelqu\'un';

  @override
  String get replyPreviewImage => '📷 Photo';

  @override
  String get replyPreviewVoice => '🎤 Message vocal';

  @override
  String get replyPreviewMessage => 'Message';

  @override
  String get replyUnavailable => 'Message d\'origine indisponible';

  @override
  String get shopEntryTitle => 'Boutique & WiltKey Plus';

  @override
  String get shopEntrySubtitle => 'Thèmes, contenus & Plus';

  @override
  String get supportEntryTitle => 'Soutenir le projet';

  @override
  String get supportEntrySubtitle => 'Aidez à faire vivre WiltKey';

  @override
  String get shopTitle => 'Boutique';

  @override
  String get supportTitle => 'Soutenir WiltKey';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => 'Déblocages';

  @override
  String get shopPlusTagline =>
      'Conservation hors ligne prolongée des messages et transferts de fichiers plus volumineux.';

  @override
  String get shopEmptyTitle => 'Rien pour l\'instant';

  @override
  String get shopEmptyBody => 'Des produits arrivent — revenez bientôt.';

  @override
  String get shopRestoreButton => 'Restaurer les achats';

  @override
  String get shopRestoredSnack => 'Achats restaurés';

  @override
  String get shopBuyButton => 'Acheter';

  @override
  String get shopOwnedLabel => 'Acquis';

  @override
  String get shopActiveLabel => 'Actif';

  @override
  String get shopManageNote => 'Gérer dans Google Play';

  @override
  String get shopPurchasePendingSnack => 'Achat en attente…';

  @override
  String get shopPurchaseFailedSnack => 'L\'achat n\'a pas pu être finalisé';

  @override
  String get supportIntro =>
      'WiltKey est gratuit et open source, et cette version débloque tous les éléments cosmétiques gratuitement. Si vous souhaitez soutenir le développement et le relais officiel, visitez la page ci-dessous.';

  @override
  String get supportOpenButton => 'Ouvrir la page de soutien';

  @override
  String get supportFreeNote =>
      'Tous les éléments cosmétiques sont débloqués dans cette version.';

  @override
  String get shopTabPalettes => 'Palettes';

  @override
  String get shopTabThemes => 'Thèmes';

  @override
  String get shopTabBorders => 'Cadres';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'Promo';

  @override
  String get shopPalettesIntro =>
      'Des couleurs supplémentaires pour dessiner votre avatar et vos icônes de groupe. Les créations reçues s\'affichent toujours intégralement — un pack débloque seulement le fait de dessiner vous-même avec ces couleurs.';

  @override
  String shopPaletteColorCount(int count) {
    return '$count couleurs supplémentaires';
  }

  @override
  String get shopThemesEmptyTitle => 'Pas encore de thèmes';

  @override
  String get shopThemesEmptyBody =>
      'Les thèmes premium arrivent — les trois thèmes intégrés restent gratuits pour toujours.';

  @override
  String get shopBordersSoonTitle => 'Les cadres arrivent';

  @override
  String get shopBordersSoonBody =>
      'Des cadres décoratifs pour votre avatar, visibles par toutes les personnes avec qui vous discutez. En cours de développement.';

  @override
  String get shopPlusBenefitsSection => 'Ce que vous obtenez';

  @override
  String get shopPlusBenefitHold =>
      'Vos messages attendent 72 heures sur le relais au lieu de 24 pendant que vous êtes hors ligne.';

  @override
  String get shopPlusBenefitFiles =>
      'Envoyez de gros fichiers — jusqu\'à 50 Mo par message, au-delà de la limite gratuite de 5 Mo.';

  @override
  String get shopPlusBenefitPads =>
      'Créez des blocs plus grands — jusqu\'à 200 Mo pour une discussion et 500 Mo pour un groupe.';

  @override
  String get shopPlusBenefitTimeWiltGroups =>
      'Host bigger Time Wilt groups — up to 100 members instead of 20.';

  @override
  String get shopPlusBenefitSupport =>
      'Vous faites vivre le relais et gardez WiltKey indépendant.';

  @override
  String get shopSubscribeButton => 'S\'abonner';

  @override
  String get shopPriceUnavailable => 'Indisponible';

  @override
  String get shopPromoIntro =>
      'Vous avez un code promo ? Saisissez-le ci-dessous et Google Play l\'appliquera à votre compte.';

  @override
  String get shopPromoHint => 'CODE PROMO';

  @override
  String get shopPromoRedeemButton => 'Utiliser dans Google Play';

  @override
  String get shopPromoNote =>
      'Les codes s\'utilisent dans le Play Store. Une fois appliqué, votre déblocage apparaît ici automatiquement.';

  @override
  String pairLargerPadsUpsell(String max) {
    return 'Blocs plus grands avec Plus — jusqu\'à $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return 'Espace libre insuffisant — cette conversation nécessite $needed et vous avez $free.';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return 'Génération du keystream… $written / $total';
  }

  @override
  String get pairKeepAppOpen =>
      'Garde l\'application ouverte — le bloc sécurisé est encore en cours de création.';

  @override
  String groupLargerPadsUpsell(String max) {
    return 'Blocs de groupe plus grands avec Plus — jusqu\'à $max';
  }

  @override
  String get settingsBorderSection => 'Cadre d\'avatar';

  @override
  String get shopBordersIntro =>
      'Cadres et accessoires pour votre avatar. Tous ceux avec qui vous discutez voient votre cadre — un cadre verrouillé vous empêche seulement de l\'équiper, jamais de l\'afficher.';

  @override
  String get shopBorderSubtitle => 'Cadre d\'avatar';

  @override
  String get shopFreeLabel => 'Gratuit';

  @override
  String get notificationModePrivate => 'Privé';

  @override
  String get notificationModePrivateDesc =>
      'Vérifie régulièrement les nouveaux messages en arrière-plan sans utiliser le service push de Google. Les alertes peuvent être retardées, mais aucun signal ne passe par un service tiers.';

  @override
  String get connectSectionOneOnOne => 'Tête-à-tête';

  @override
  String get connectSectionGroups => 'Groupes';

  @override
  String get connectByteBudgetTitle => 'Budget d\'octets';

  @override
  String get connectByteBudgetDesc =>
      'Temps illimité, budget limité. Idéal pour les amis proches, la famille et les échanges ultra-sécurisés.';

  @override
  String get connectTimeWiltTitle => 'Time Wilt';

  @override
  String get connectTimeWiltDesc =>
      'Temps limité, budget illimité. Idéal pour faire de nouvelles connaissances, des rendez-vous ou des rencontres spontanées.';

  @override
  String get connectRemotePairTitle => 'Appairage distant (test)';

  @override
  String get connectRemotePairDesc =>
      'Mode test : appairez-vous avec un testeur via le relais avec un PIN et un hash d\'identité.';

  @override
  String get connectByteBudgetGroupTitle => 'Groupe budget d\'octets';

  @override
  String get connectByteBudgetGroupDesc =>
      'Temps illimité, budget limité. Un groupe créé en invitant les membres en personne.';

  @override
  String get connectTimeWiltGroupTitle => 'Groupe Time Wilt';

  @override
  String get connectTimeWiltGroupDesc =>
      'Temps limité, budget illimité. Un groupe éphémère dont les messages expirent au fur et à mesure.';

  @override
  String get connectJoinGroupTitle => 'Rejoindre un groupe';

  @override
  String get connectJoinGroupDesc =>
      'Quelqu\'un à proximité vous a invité — recherchez son signal.';

  @override
  String get connectJoinRemoteGroupTitle =>
      'Rejoindre un groupe distant (test)';

  @override
  String get connectJoinRemoteGroupDesc =>
      'Mode test : rejoignez le groupe d\'un testeur via le relais.';

  @override
  String get connectBadgeSoon => 'BIENTÔT';

  @override
  String get timeWiltLifetimeLabel => 'Durée de vie du chat';

  @override
  String get timeWiltPlusHint => 'Débloquez jusqu\'à 6 mois avec Plus';

  @override
  String get timeWiltExplanation =>
      'La discussion devient en lecture seule quand le minuteur expire.';

  @override
  String timeWiltPairRequestDialogBody(String peerName, String lifetime) {
    return 'Accepter le chat Time Wilt de $peerName ? Il deviendra en lecture seule dans $lifetime.';
  }

  @override
  String timeWiltLifetimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String timeWiltLifetimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
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
      other: '$count mois',
      one: '1 mois',
    );
    return '$_temp0';
  }

  @override
  String get timeWiltLifetimeMoments => 'quelques instants';
}
