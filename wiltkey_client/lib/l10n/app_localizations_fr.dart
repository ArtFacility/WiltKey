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
  String get navPair => 'Jumeler';

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
  String get settingsLanguageChinese => '中文 (Chinesisch)';

  @override
  String get notificationModeOff => 'Désactivé';

  @override
  String get notificationModeOffDesc =>
      'Pas de vérification en arrière-plan. Tu ne verras les messages qu\'à l\'ouverture de l\'application.';

  @override
  String get notificationModeLowPower => 'Économie d\'énergie';

  @override
  String get notificationModeLowPowerDesc =>
      'Vérifie les nouveaux messages toutes les 10 minutes environ. Économe pour la batterie.';

  @override
  String get notificationModeInstant => 'Instantané';

  @override
  String get notificationModeInstantDesc =>
      'Garde un lien sécurisé actif en arrière-plan pour des alertes instantanées. Affiche une notification permanente et consomme plus de batterie.';

  @override
  String get notificationNewMessageBody => 'Tu as un message';

  @override
  String get notificationSecureLinkActive => 'Lien sécurisé actif';

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
      'Déverrouille avec ton empreinte au lieu du code PIN. Le PIN reste requis après 4 heures d\'inactivité.';

  @override
  String get settingsBiometricFailedSnackBar =>
      'Impossible d\'activer le déverrouillage par empreinte.';

  @override
  String get pinForgotButton => 'PIN oublié ? Réinitialiser l\'appareil';

  @override
  String get pairTitle => 'Jumeler les appareils';

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
  String get chatTapForDetails => 'Appuie pour les détails';

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
}
