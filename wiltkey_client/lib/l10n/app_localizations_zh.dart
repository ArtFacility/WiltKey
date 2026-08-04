// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navChats => '聊天';

  @override
  String get navPair => '连接';

  @override
  String get navSettings => '设置';

  @override
  String get nukedTitle => '设备已重置';

  @override
  String get nukedExplanation => '此设备上的所有消息和密钥已删除。安全数据库已被清空。';

  @override
  String get nukedResetButton => '创建新身份';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSave => '保存';

  @override
  String get commonBack => '返回';

  @override
  String get commonContinue => '继续';

  @override
  String get commonFinish => '完成';

  @override
  String get onboardingWelcomeTitle => '欢迎使用 Wiltkey';

  @override
  String get onboardingWelcomeDescription =>
      'Wiltkey 是一款私人加密通讯工具。我们不保存任何元数据、日志或服务器历史。消息在本地加密，若检测 to 截屏会自动销毁。';

  @override
  String get onboardingWelcomeNoHistory => '无服务器历史记录，无恢复密钥。';

  @override
  String get onboardingIntelTitle => '安全信息';

  @override
  String get onboardingLanguageDescription => '选择你的首选语言以继续。你可以随时在设置中更改。';

  @override
  String get onboardingFactLanguageTitle => '语言设置';

  @override
  String get onboardingFactLanguageBody =>
      '选择你的首选语言以继续。你可以随时在设置中更改。你的选择会保存在本地。';

  @override
  String get onboardingThemeTitle => '选择你的主题';

  @override
  String get onboardingThemeDescription => '在下方选择一个主题。你之后可以在设置中随时更改。';

  @override
  String get onboardingProfileTitle => '你的身份';

  @override
  String get onboardingProfileUsernameLabel => '用户名';

  @override
  String get onboardingProfileUsernameHint => '输入用户名';

  @override
  String get onboardingProfileCodenameLabel => '连接码（5 位字母/数字）';

  @override
  String get onboardingProfileCodenameExplanation => '此代码在配对时共享，用以连接附近的朋友。';

  @override
  String get onboardingProfileUsernameError => '请设置用户名。';

  @override
  String get onboardingProfileCodenameError => '连接码必须恰好为 5 个字符。';

  @override
  String get onboardingAvatarTitle => '像素头像';

  @override
  String get onboardingAvatarBrushColor => '画笔颜色';

  @override
  String get onboardingAvatarRandom => '随机';

  @override
  String get onboardingAvatarClear => '清除';

  @override
  String get onboardingPinTitle => '解锁密码 PIN';

  @override
  String get onboardingPinExplanation =>
      '设置 PIN 码（4-6 位数字）来保护你的聊天记录。每次打开应用时，你都需要输入此密码。如果你忘记了它，消息将无法恢复。';

  @override
  String get onboardingPinEnter => '输入 PIN 码';

  @override
  String get onboardingPinConfirm => '确认 PIN 码';

  @override
  String get onboardingPinLengthError => 'PIN 码必须为 4 至 6 位数字。';

  @override
  String get onboardingPinMatchError => '两次输入的 PIN 码不一致。';

  @override
  String onboardingSetupFailed(String error) {
    return '设置失败: $error';
  }

  @override
  String get onboardingFactMetadataTitle => '元数据问题';

  @override
  String get onboardingFactMetadataBody =>
      '大多数聊天软件会加密消息内容，但仍会追踪你的联系人、聊天时间以及频率。Wiltkey 不会记录任何元数据、服务器端 data 或连接信息。';

  @override
  String get onboardingFactThemeTitle => '选择你的主题';

  @override
  String get onboardingFactThemeBody =>
      '主题仅影响视觉外观。每个主题都遵循相同的安全标准。你可以随时在设置中切换主题。';

  @override
  String get onboardingFactOtpTitle => '完美保密';

  @override
  String get onboardingFactOtpBody =>
      'Wiltkey 使用一次性密码本 (OTP) 加密。密钥与消息大小完全一致、完全随机且永不重复使用。这从数学上实现了完美保密，没有密钥任何人都无法解密消息。';

  @override
  String get onboardingFactLimitsTitle => '连接限制';

  @override
  String get onboardingFactLimitsBody =>
      '聊天容量限制旨在鼓励建立有意义且慎重的人际关系。限制容量可确保对话目的明确，且植根于真实的现实连接。';

  @override
  String get onboardingFactKdfTitle => '安全哈希';

  @override
  String get onboardingFactKdfBody =>
      '普通的 PIN 码 in 几毫秒内就可以被暴力破解。Wiltkey 会通过强化函数处理你的 PIN 码，让针对本地数据库的暴力破解变得根本不可能。';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTabProfile => '个人资料';

  @override
  String get settingsTabSecurity => '安全';

  @override
  String get settingsSecuritySectionAccess => '访问与解锁';

  @override
  String get settingsSecuritySectionDanger => '危险区域';

  @override
  String get settingsTabNetwork => '网络';

  @override
  String get settingsTabAlerts => '通知';

  @override
  String get settingsSavedIndicator => '已保存';

  @override
  String get settingsProfileSectionAppearance => '外观';

  @override
  String get settingsProfileSectionAvatar => '像素头像';

  @override
  String get settingsProfileSectionProfile => '个人资料设置';

  @override
  String get settingsProfileSectionOtherVisuals => '其他视觉设置';

  @override
  String get settingsThemeLabel => '主题';

  @override
  String get settingsPixelArtEditor => '像素画编辑器';

  @override
  String get settingsProfileBrushColor => '画笔颜色';

  @override
  String get settingsProfileChipIdenticon => '标识头像';

  @override
  String get settingsProfileChipClear => '清除';

  @override
  String get settingsProfileChipRandom => '随机';

  @override
  String get avatarEditButton => '编辑头像';

  @override
  String get groupCreateEditIcon => '编辑图标';

  @override
  String get settingsProfileUsername => '用户名';

  @override
  String get settingsProfileBleNick => '简短昵称（5 个字符）';

  @override
  String get settingsProfileKeyhash => '账户 ID';

  @override
  String get settingsProfileKeyhashCopied => '账户 ID 已复制到剪贴板';

  @override
  String get settingsProfileChangePinButton => '修改 PIN 码';

  @override
  String get settingsProfileResetIdentityButton => '重置账户';

  @override
  String get settingsResetConfirmTitle => '重置身份？';

  @override
  String get settingsResetConfirmBody => '这将永久删除所有消息、联系人并生成新身份。此操作无法撤销。';

  @override
  String get settingsResetConfirmCancel => '取消';

  @override
  String get settingsResetConfirmReset => '重置';

  @override
  String get settingsChangePinTitle => '修改 PIN 码';

  @override
  String get changePinVerifyTitle => '验证当前 PIN 码';

  @override
  String get changePinVerifyPrompt => '输入当前 PIN 码以继续。';

  @override
  String get changePinSetTitle => '设置新 PIN 码';

  @override
  String get settingsChangePinOldPin => '输入当前 PIN 码';

  @override
  String get settingsChangePinNewPin => '输入新 PIN 码 (4-6 位数字)';

  @override
  String get settingsChangePinConfirmPin => '确认新 PIN 码';

  @override
  String get settingsChangePinEmptyFieldsError => '请填写所有字段。';

  @override
  String get settingsChangePinLengthError => '新 PIN 码必须为 4 至 6 位数字。';

  @override
  String get settingsChangePinMatchError => '两次输入的新 PIN 码不一致。';

  @override
  String get settingsChangePinUpdatedSnackBar => 'PIN 码已更新。';

  @override
  String get settingsChangePinIncorrectError => '当前 PIN 码不正确。';

  @override
  String get settingsNetworkRoutingTitle => '网络设置';

  @override
  String get settingsNetworkDevRelayToggle => '使用本地开发服务器';

  @override
  String get settingsNetworkDevRelayUrlLabel => '开发服务器 URL';

  @override
  String get settingsNetworkDevRelayDescription =>
      '启用此选项将覆盖生产服务器，并将消息路由到本地开发服务器。';

  @override
  String get settingsNetworkActiveGateway => '当前服务器 URL';

  @override
  String get settingsNetworkDiagnostics => '诊断';

  @override
  String get settingsNetworkDebugButton => '打开调试控制台';

  @override
  String get settingsDebugButtonsToggle => '调试按钮';

  @override
  String get settingsDebugButtonsDescription => '在聊天列表和聊天内显示终端控制台按钮。';

  @override
  String get settingsDebugTitle => '调试控制台';

  @override
  String get settingsAlertsBackgroundNotifications => '后台消息通知';

  @override
  String get settingsAlertsExplanation =>
      '通知仅会显示 \'你收到一条消息\'。在输入 PIN 码解锁应用前，消息在设备上保持加密状态。';

  @override
  String get settingsTextSizeLabel => '聊天文字大小';

  @override
  String get settingsTextSizePreview => '你的消息会是这个样子。';

  @override
  String get settingsLanguageLabel => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English (英语)';

  @override
  String get settingsLanguageHungarian => 'Magyar (匈牙利语)';

  @override
  String get settingsLanguagePolish => 'Polski (波兰语)';

  @override
  String get settingsLanguageGerman => 'Deutsch (德语)';

  @override
  String get settingsLanguageFrench => 'Français (法语)';

  @override
  String get settingsLanguageSwedish => 'Svenska (瑞典语)';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get notificationModeOff => '关闭';

  @override
  String get notificationModeOffDesc => '无后台检查。只有打开应用时才能收到消息。';

  @override
  String get notificationModeLowPower => '低功耗';

  @override
  String get notificationModeLowPowerDesc =>
      '在后台定期检查新消息——刚关闭应用后会较频繁地检查，随后逐渐减少以节省电量。没有持续连接，因此通知可能会有延迟。';

  @override
  String get notificationModeInstant => '即时通知';

  @override
  String get notificationModeInstantDesc =>
      '可选。在后台保持一条端到端加密连接，实时同步收到的消息，并通过一条常驻通知显示。出于隐私考虑，Wiltkey 使用此方式而非 Google 或 Apple 的推送服务，因此即使没有 Google Play 服务也能正常工作——代价是更耗电。';

  @override
  String get notificationNewMessageBody => '你收到一条消息';

  @override
  String get notificationSecureLinkActive => '正在同步安全消息';

  @override
  String get onboardingNotificationsTitle => '通知';

  @override
  String get onboardingNotificationsExplanation =>
      'Wiltkey 不使用 Google 或 Apple 的推送通知——你的消息不会以任何形式经过它们的服务器。请选择你希望的提醒方式。你随时可以在“设置”中更改。';

  @override
  String get onboardingFactPushTitle => '无推送服务器';

  @override
  String get onboardingFactPushBody =>
      '普通应用通过 Google 或 Apple 转发通知，从而暴露谁在何时给你发消息。Wiltkey 从不这样做——默认完全不进行后台检查，任何提醒都完全在你的设备上运行。';

  @override
  String get notificationModeInstantDescFcm =>
      '可选。使用 Google 的推送服务作为轻量级唤醒信号，让新消息实时送达。只有不含内容的信号会经过 Google——绝不包含你的消息，消息在中继上保持端到端加密，直到你的设备将其取回。比持续连接更省电。';

  @override
  String get onboardingNotificationsExplanationFcm =>
      '为实现实时提醒，此版本仅将 Google 的推送服务用作唤醒信号——一个不含内容的信号，绝不包含你的消息，你的消息也绝不会经过 Google 的服务器。选择你希望的提醒方式；你可以随时在设置中更改。';

  @override
  String get onboardingFactPushTitleFcm => '无内容推送';

  @override
  String get onboardingFactPushBodyFcm =>
      '普通应用通过 Google 转发通知内容，从而暴露发送了什么以及何时发送。此版本仅将 Google 用作不含内容的唤醒信号——没有消息数据，没有可读的元数据——所有内容始终保持端到端加密。';

  @override
  String get chatsLockedSubtitle => '已锁定 · 需当面配对以解锁';

  @override
  String chatsMemberCount(int count) {
    return '$count 个成员';
  }

  @override
  String chatsSubtitle(int totalCount, int lockedCount) {
    return '$totalCount 个联系人 · $lockedCount 个已锁定';
  }

  @override
  String get chatsTitle => '聊天';

  @override
  String get chatsPopupPair => '配对设备';

  @override
  String get chatsPopupCreateGroup => '创建群组';

  @override
  String get chatsPopupJoinGroup => '加入群组';

  @override
  String get chatsSearchHint => '搜索';

  @override
  String get chatsEmptyNoMatches => '无匹配项';

  @override
  String get chatsEmptyNoChats => '暂无聊天';

  @override
  String get chatsEmptyPairInstruction => '当面与朋友配对以开始聊天。';

  @override
  String get chatsEmptyPairButton => '配对设备';

  @override
  String chatsRowMeRemaining(String remaining, String theirRemaining) {
    return '我剩余 $remaining · 对方剩余 $theirRemaining';
  }

  @override
  String chatsRowGroupRemaining(String remaining, String max) {
    return '$remaining / $max';
  }

  @override
  String get pinMaxAttemptsExceeded => '输入错误次数过多。设备已抹除。';

  @override
  String pinAccessDenied(int attempts) {
    return 'PIN 码不正确。还剩 $attempts 次机会。';
  }

  @override
  String get pinMinLengthError => 'PIN 码至少需要 4 位数字。';

  @override
  String get pinPurgeConfirmTitle => '重置设备？';

  @override
  String get pinPurgeConfirmBody => '忘记 PIN 码了？这将永久删除所有消息并重置账户。此操作无法撤销。';

  @override
  String get pinPurgeConfirmButton => '重置设备';

  @override
  String get pinLockedTitle => '已锁定';

  @override
  String get pinLockedSubtitle => '输入 PIN 码以解锁';

  @override
  String get pinUnlockButton => '解锁';

  @override
  String get pinUseFingerprintButton => '使用指纹';

  @override
  String get settingsBiometricToggle => '指纹解锁';

  @override
  String get settingsBiometricDescription => '用指纹代替 PIN 解锁。超过下方设置的时限后仍需输入 PIN。';

  @override
  String get settingsBiometricIdleTitle => 'PIN 回退';

  @override
  String get settingsBiometricIdleDescription => '闲置超过此时长未解锁后，需要重新输入 PIN。';

  @override
  String settingsBiometricIdleValue(int hours) {
    return '$hours 小时';
  }

  @override
  String get settingsBiometricIdleNever => '从不';

  @override
  String get settingsBiometricFailedSnackBar => '无法启用指纹解锁。';

  @override
  String get pinForgotButton => '忘记 PIN 码？重置设备';

  @override
  String get pairTitle => '配对设备';

  @override
  String get pairRescanTooltip => '刷新扫描';

  @override
  String get pairBluetoothOffWarning => '蓝牙已关闭。配对需要蓝牙来查找附近的设备——请打开蓝牙以继续。';

  @override
  String get pairBluetoothTurnOnButton => '打开蓝牙';

  @override
  String get pairDoNotExitWarning => '请保持 WiltKey 打开——在两台设备都完成配对之前，请勿切换应用或退出。';

  @override
  String get pairRequestDialogTitle => '配对请求';

  @override
  String pairRequestDialogBody(String peerName, String size) {
    return '$peerName 想要与你配对。\n\n聊天容量: $size。\n\n是否接受安全配对？';
  }

  @override
  String get pairRequestReject => '拒绝';

  @override
  String get pairRequestAccept => '接受';

  @override
  String get pairPingStatusPinging => '测试中...';

  @override
  String pairPingStatusLatency(String latency) {
    return '延迟: ${latency}ms';
  }

  @override
  String get pairPingStatusFailed => '失败';

  @override
  String get pairPingStatusTest => '测试连接';

  @override
  String get pairDeviceNameLabel => '你的设备名称';

  @override
  String get pairDeviceNameHint => '输入名称';

  @override
  String get pairDiscoverableTitle => '允许附近的人发现我';

  @override
  String get pairDiscoverableSubtitle => '允许附近的朋友找到你';

  @override
  String get pairNearbyDevicesTitle => '附近的设备';

  @override
  String get pairNearbyDevicesInstruction => '将两台设备靠近以连接。';

  @override
  String get pairDirectSyncFormRelayLabel => '服务器 URL';

  @override
  String get pairDirectSyncFormSyncButton => '连接设备';

  @override
  String get pairSyncingConnecting => '正在连接...';

  @override
  String pairSyncingGeneratingKey(String size) {
    return '正在生成安全密钥 ($size)';
  }

  @override
  String pairSyncingSeedLabel(String seed) {
    return '密钥: $seed';
  }

  @override
  String pairSyncingPercentComplete(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get pairSuccessConnectionSecured => '连接成功';

  @override
  String pairSuccessGroupBody(String groupName) {
    return '已加入群组 \"$groupName\"。安全密钥已在你的设备上本地生成。';
  }

  @override
  String pairSuccessOneOnOneBody(String title, String label) {
    return '安全密钥已交换并在你的设备上生成。已与 $title 连接，聊天容量为 $label。';
  }

  @override
  String get pairSuccessReturnButton => '前往聊天';

  @override
  String get chatDetailsTitle => '聊天详情';

  @override
  String chatDetailsSubtitleWithNick(String nick, String type) {
    return '昵称: $nick · $type';
  }

  @override
  String get chatDetailsOfficialRelay => '官方中继';

  @override
  String get chatDetailsPrivateNode => '私有节点';

  @override
  String chatDetailsHeaderMeRemaining(String remaining, String theirRemaining) {
    return '我剩余 $remaining · 对方剩余 $theirRemaining';
  }

  @override
  String get chatDetailsSectionProfile => '个人资料';

  @override
  String get chatDetailsProfileExplanation => '头像和昵称会在连接时自动同步。如果需要，你也可以现在手动同步。';

  @override
  String get chatDetailsProfileSyncButton => '同步个人资料';

  @override
  String get chatDetailsProfileSnackBar => '个人资料已发送。';

  @override
  String get chatDetailsSectionPermissions => '权限设置';

  @override
  String get chatDetailsPermissionsPhotos => '允许分享照片';

  @override
  String get chatDetailsPermissionsEmojis => '自定义表情';

  @override
  String get chatDetailsPermissionsEmojisAvailable => '可用';

  @override
  String get chatDetailsPermissionsEmojisNeedsSize => '需要更大的聊天容量';

  @override
  String get chatDetailsSectionMetadata => '元数据空间';

  @override
  String chatDetailsMetadataExplanation(String budget, String max) {
    return '此聊天从总共 $max 的空间中分配了 $budget 用于设置、头像和自定义表情。';
  }

  @override
  String get chatDetailsSectionLanes => '安全通道';

  @override
  String get chatDetailsLanesMySend => '我的发送容量';

  @override
  String get chatDetailsLanesPeerSend => '对方的发送容量';

  @override
  String get chatDetailsLanesBorrowed => '借用的空间';

  @override
  String get chatDetailsLanesCapacityLeft => '我的剩余容量';

  @override
  String get chatDetailsLanesExplanation =>
      '如果你的聊天容量不足，可以借用对方未使用的空间。这也可能会自动发生，以便你继续聊天。';

  @override
  String get chatDetailsLanesBorrowButton => '申请聊天空间';

  @override
  String get chatDetailsLanesSnackBar => '申请已发送给对方。';

  @override
  String get chatDetailsSectionEmojis => '自定义表情';

  @override
  String get chatDetailsEmojisExplanation => '在你的消息中使用 :名称: 格式来发送这些自定义表情。';

  @override
  String get chatDetailsEmojisExplanationDisabled =>
      '当前聊天容量太小，无法使用自定义表情。请使用更大的聊天容量配对以启用该功能。';

  @override
  String get chatDetailsEmojisCreate => '创建';

  @override
  String get chatDetailsSectionDestructive => '危险设置';

  @override
  String get chatDetailsNukeButton => '销毁聊天（双方）';

  @override
  String get chatDetailsDeleteEmojiTitle => '删除表情？';

  @override
  String get chatDetailsDeleteEmojiBody => '此自定义表情将被永久删除。是否继续？';

  @override
  String get chatDetailsDeleteEmojiDelete => '删除';

  @override
  String chatDetailsAddEmojiSnackBar(String name) {
    return '已添加 :$name:';
  }

  @override
  String chatImageTooLargeSnackBar(String cost, String charge) {
    return '图片体积 ($cost) 超出当前剩余容量 ($charge)。';
  }

  @override
  String get chatImageExceedsMaxSizeSnackBar => '图片过大，无法发送。';

  @override
  String get chatImageNeedsPlusSnackBar =>
      '图片超出免费额度——WiltKey Plus 将上限提升至 50 MB。';

  @override
  String get chatTapForDetails => '轻触查看详情';

  @override
  String get chatSyncTooltip => '同步消息';

  @override
  String get chatStickerHint => '长按表情以贴纸形式发送';

  @override
  String get chatSyncStarted => '正在检查遗漏的消息…';

  @override
  String get chatSyncOffline => '离线状态下无法同步。';

  @override
  String get chatEncrypting => '加密中…';

  @override
  String get chatScreenshotDetected => '检测到截屏';

  @override
  String get chatScreenshotExplanation => '检测到截屏。为安全起见，你现在可以抹除密钥和所有消息。';

  @override
  String get chatScreenshotWipeButton => '立刻抹除消息 and 密钥';

  @override
  String get chatScreenshotIgnoreButton => '忽略警告';

  @override
  String get chatSimulateScreenshotButton => '模拟截屏';

  @override
  String chatCostIndicator(String cost) {
    return '容量消耗: $cost';
  }

  @override
  String get groupCreateTitle => '创建群组';

  @override
  String get groupCreatePixelArtIcon => '群组头像';

  @override
  String get groupCreateRandomIcon => '生成';

  @override
  String get groupCreateClearIcon => '清除';

  @override
  String get groupCreateNameLabel => '群组名称';

  @override
  String get groupCreateNameEmptyValidator => '请输入群组名称';

  @override
  String get groupCreateNameLengthValidator => '最多 24 个字符';

  @override
  String get groupCreatePoliciesSection => '群组策略设置';

  @override
  String get groupCreatePolicyPadSize => '群聊容量';

  @override
  String get groupCreatePolicyLaneSize => '每位成员发送容量';

  @override
  String get groupCreatePolicyMaxMembersLabel => '最大成员数限制';

  @override
  String groupCreatePolicyMaxMembersValue(int count) {
    return '最多 $count 人';
  }

  @override
  String get groupCreatePolicyAllowImages => '允许分享照片';

  @override
  String get groupCreatePolicyAllowImagesSub => '允许成员发送照片';

  @override
  String get groupCreatePolicyPayloadSize => '最大消息大小';

  @override
  String get groupCreateButton => '创建群组';

  @override
  String get groupCreateProgressTitle => '正在创建群组…';

  @override
  String get groupCreateProgressSubtitle => '正在准备群组的加密容量和成员通道，这可能需要片刻，请稍候。';

  @override
  String groupCreateFailedSnackBar(String error) {
    return '创建群组失败: $error';
  }

  @override
  String get pairSyncingAwaitingApproval => '正在等待对方接受...';

  @override
  String get pairSyncingCoordinating => '正在配置密钥交换...';

  @override
  String get pairSyncingStep1 => '正在建立安全链路...';

  @override
  String get pairSyncingStep2 => '正在生成安全种子...';

  @override
  String pairSyncingStep3(String seed) {
    return '正在交换公钥... $seed';
  }

  @override
  String get pairSyncingStep4 => '正在生成安全聊天密钥...';

  @override
  String get pairSyncingStep5 => '正在校验密钥完整性...';

  @override
  String get pairSyncingStep6 => '安全设置成功完成。';

  @override
  String chatRemainingLabel(String bytes) {
    return '剩余 $bytes';
  }

  @override
  String get chatLockedLabel => '已锁定 · 需当面配对以继续';

  @override
  String get chatMessageHint => '消息';

  @override
  String get chatVoiceComingSoon => '语音消息即将推出。';

  @override
  String get chatVoiceHoldHint => '按住以录制语音消息。';

  @override
  String get chatVoiceReleaseCancel => '松开以取消';

  @override
  String get chatVoicePermissionDenied => '录制语音消息需要麦克风权限。';

  @override
  String get chatVoiceQualityLofi => '低保真';

  @override
  String get chatVoiceQualityVoice => '语音';

  @override
  String get chatVoiceQualityClear => '清晰';

  @override
  String get chatVoiceUnavailable => '语音消息不可用';

  @override
  String chatVoiceTooLargeSnackBar(String cost, String charge) {
    return '语音消息过大（$cost），超出剩余空间（$charge）。';
  }

  @override
  String get chatDetailsDeleteConfirmTitle => '删除聊天？';

  @override
  String get chatDetailsDeleteConfirmBody => '这将永久删除此联系人的所有消息和加密密钥。此操作无法撤销。';

  @override
  String get chatDetailsDeleteConfirmButton => '删除聊天';

  @override
  String get chatsActionArchive => '归档';

  @override
  String get chatsActionNuke => '删除聊天与密钥';

  @override
  String get chatsActionDelete => '删除';

  @override
  String get chatsArchivedBadge => '已归档';

  @override
  String get chatsArchivedSubtitle => '已归档 · 只读';

  @override
  String get chatsArchiveConfirmTitle => '归档聊天？';

  @override
  String get chatsArchiveConfirmBody =>
      '这将通过删除此聊天的一次性密钥本来释放空间。你的消息仍可阅读，但聊天将变为只读——你将无法再在其中收发消息。';

  @override
  String get chatsArchiveConfirmButton => '归档';

  @override
  String get chatsActionPin => '置顶';

  @override
  String get chatsActionUnpin => '取消置顶';

  @override
  String get chatsFilterAll => '全部';

  @override
  String get chatsFilterDirect => '私聊';

  @override
  String get chatsFilterGroups => '群组';

  @override
  String get chatsSectionArchived => '已归档';

  @override
  String groupTapForDetails(String hostName) {
    return '轻触查看详情 · 房主: $hostName';
  }

  @override
  String groupEmptySlots(int count) {
    return '还有 $count 个空余通道可用';
  }

  @override
  String get groupHost => '房主';

  @override
  String get groupMember => '成员';

  @override
  String get groupDepleted => '容量已耗尽';

  @override
  String get groupNotYetMet => '还没见过面';

  @override
  String get groupRechargeButton => '重新充能群组';

  @override
  String get groupRechargeTitle => '要重新充能群组吗？';

  @override
  String get groupRechargeBody => '用新密钥重新充能聊天。聊天记录会保留，但成员必须与你当面重聚才能重新加入。';

  @override
  String get groupRechargeConfirm => '重新充能';

  @override
  String get groupRechargeDone => '群组已重新充能 — 再次见面即可重新添加成员。';

  @override
  String get groupRechargeNeededComposer => '群主重新充能了群组 — 再次见面即可重新加入';

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
    return '正在从 $name 同步群组详情和消息...';
  }

  @override
  String get groupInviteMember => '邀请成员';

  @override
  String get groupLeaveGroup => '退出群组';

  @override
  String get groupRemoveMember => '移除成员';

  @override
  String get groupRemoveMemberTitle => '移除成员？';

  @override
  String groupRemoveMemberBody(String name) {
    return '确定将 $name 移出群组？这将作废他们的配对密钥。';
  }

  @override
  String get groupLeaveGroupTitle => '退出群组？';

  @override
  String get groupLeaveGroupBody => '确定退出此群组？这将删除你本地的密钥和历史记录。';

  @override
  String get groupSyncStepText => '同步';

  @override
  String get groupDecryptingImage => '正在解密图片...';

  @override
  String get chatFileTapToDownload => '轻触以下载';

  @override
  String get chatFileDownloadFailed => '轻触重试';

  @override
  String get chatFileKindPhoto => '照片';

  @override
  String get chatFileKindVoice => '语音消息';

  @override
  String get chatFileKindFile => '文件';

  @override
  String get groupTapToRevealImage => '轻触以显示图片';

  @override
  String groupImageSize(String size) {
    return '大小: $size';
  }

  @override
  String get groupImageFailedToLoad => '图片加载失败';

  @override
  String get groupScreenshotWipeButton => '立刻擦除所有密钥';

  @override
  String get groupRefillGranted => '通道充能成功。';

  @override
  String groupRefillFailed(String error) {
    return '充能失败: $error';
  }

  @override
  String get groupLaneDepleted => '通道容量已尽';

  @override
  String get groupLaneDepletedExplanation => '请向群组房主申请充能。';

  @override
  String get groupRefillRequestSent => '充能申请已传送至房主。';

  @override
  String get groupRequestRefill => '申请充能';

  @override
  String groupExceedsSizeLimit(int size) {
    return '超出大小限制 ($size B)';
  }

  @override
  String get groupDetailsTitle => '群组详情';

  @override
  String groupDetailsSharedPadHost(String hostName) {
    return '共享空间 · 房主: $hostName';
  }

  @override
  String get groupDetailsSectionEditPolicies => '群组策略';

  @override
  String get groupDetailsSavePoliciesButton => '保存策略';

  @override
  String get groupDetailsSavePoliciesSnackBar => '群组策略已保存。';

  @override
  String get groupDetailsSectionEmojis => '自定义表情';

  @override
  String get groupDetailsSectionMetadata => '元数据空间';

  @override
  String get groupDetailsMetadataExplanation =>
      '共享空间的第 0 号通道保留了 1 MB 用于群组元数据——群头像、成员名单和自定义表情都存放在这里。';

  @override
  String get groupDetailsSectionSync => '群组同步';

  @override
  String get groupDetailsSyncExplanation => '向房主请求最新的群详情、策略和成员列表。';

  @override
  String get groupDetailsSyncButton => '同步详情';

  @override
  String get groupDetailsSyncSnackBar => '已向房主请求更新。';

  @override
  String get groupDetailsSectionDestructive => '危险设置';

  @override
  String get groupDetailsLeaveButton => '退出群组';

  @override
  String get groupDetailsNukeButton => '删除群组';

  @override
  String get groupDetailsDeleteConfirmTitle => '删除群组？';

  @override
  String get groupDetailsDeleteConfirmBody =>
      '这将永久解散群组，并清除所有成员的聊天历史和加密密钥。此操作不可逆。';

  @override
  String get groupDetailsDeleteConfirmButton => '解散群组';

  @override
  String get chatImageCompressionTitle => '压缩图片';

  @override
  String chatImageCompressionOriginal(String size) {
    return '原图: $size';
  }

  @override
  String chatImageCompressionEstimated(String size) {
    return '预计大小: $size';
  }

  @override
  String chatImageCompressionEstimatedWithSaving(String size, String saving) {
    return '预计大小: $size (节省约 $saving)';
  }

  @override
  String chatImageCompressionCost(String cost) {
    return '容量消耗: ~$cost';
  }

  @override
  String get chatImageCompressionExplanation => '转换为 WebP 格式，最大 2000px。';

  @override
  String get chatImageCompressionLowSize => '高压缩率';

  @override
  String get chatImageCompressionHighSize => '高画质';

  @override
  String get chatImageCompressionMaxQuality => '最高画质';

  @override
  String get chatImageCompressionUncompressed => '不压缩';

  @override
  String chatImageCompressionPercentQuality(int percent) {
    return '质量: $percent%';
  }

  @override
  String get chatImageCompressionSendHidden => '发送隐藏图（轻触显示）';

  @override
  String get chatImageCompressionSendButton => '发送';

  @override
  String get groupGrantRefill => '批准充能';

  @override
  String get groupLaneLocked => '已锁定 · 字节已耗尽';

  @override
  String get groupMembersTitle => '群组成员';

  @override
  String get groupMembersExplanation => '所有成员共享按通道划分的群聊空间。消息通过服务器发送。';

  @override
  String get pairChatSize => '聊天容量';

  @override
  String get chatSystemConnected => '已连接。聊天会话已加密。';

  @override
  String chatSystemJoinedGroup(String groupName) {
    return '已加入群组 \"$groupName\"。安全连接已建立。';
  }

  @override
  String get themeCyberpunkName => '霓虹网格';

  @override
  String get themeCyberpunkDesc => '经典原版。黑曜石色配荧光青，终端风格。';

  @override
  String get themeGardenName => '暮色花园';

  @override
  String get themeGardenDesc => '温和的泥土色调与温暖的亚麻材质，用花瓣点缀你的额度。';

  @override
  String get themePaperinkName => '纸与墨';

  @override
  String get themePaperinkDesc => '温润的和纸，浓淡相宜的墨色，朱红印章。';

  @override
  String get themePickerPlayExclusive => '此主题为 WiltKey Play 商店版本专属。';

  @override
  String get themePreviewTooltip => '预览';

  @override
  String get themePreviewSectionDashboard => '聊天列表';

  @override
  String get themePreviewSectionChat => '对话';

  @override
  String get themePreviewSectionEffects => '特效';

  @override
  String get themePreviewPlayUnlock => '播放解锁动画';

  @override
  String get themePreviewPlayNuke => '播放自毁动画';

  @override
  String get themePreviewApply => '使用此主题';

  @override
  String get themePreviewGetInShop => '前往商店获取';

  @override
  String get themePreviewMsgThem1 => '我们的密钥本只剩 800 字节了，要不要见一面？';

  @override
  String get themePreviewMsgMe => '好啊！来我家看电影？顺便充值';

  @override
  String get themePreviewMsgThem2 => '成交，我带零食 🍿';

  @override
  String get themePreviewRowPhoto => '攀岩馆的照片 🧗';

  @override
  String get themePreviewRowLost => '密钥本用完了——见面充值吧';

  @override
  String get accessibilityWarningTitle => '无障碍服务已启用';

  @override
  String accessibilityWarningBody(String names) {
    return '有一个可读取屏幕内容的无障碍服务正在运行：$names。这对于屏幕阅读器或密码管理器等工具来说是正常的。如果不是你开启的，请检查你的无障碍设置。';
  }

  @override
  String get accessibilityWarningDismiss => '关闭';

  @override
  String get accessibilityWarningOpenSettings => '查看设置';

  @override
  String get chatImageCompressionAllowDownload => '允许保存到相册';

  @override
  String get chatImageCompressionWilting => '凋零图片（打开后消失）';

  @override
  String get chatImageDownload => '下载';

  @override
  String get chatImageSaveAs => '另存为';

  @override
  String get chatImageSavedToGallery => '已保存到相册';

  @override
  String get chatImageSaveFailed => '无法保存图片';

  @override
  String get chatImageSourceTitle => '发送照片';

  @override
  String get chatImageSourceCamera => '拍照';

  @override
  String get chatImageSourceGallery => '从相册选择';

  @override
  String get screenshotRequestTooltip => '请求截图';

  @override
  String get screenshotWaiting => '等待批准…';

  @override
  String get screenshotConsentTitle => '截图请求';

  @override
  String screenshotConsentBody(String name) {
    return '$name 想保存此聊天的截图。允许吗？';
  }

  @override
  String get screenshotDenied => '截图请求被拒绝。';

  @override
  String get screenshotCaptureFailed => '无法生成截图。';

  @override
  String get screenshotWatermark => 'WiltKey — 经同意的截图';

  @override
  String screenshotRequestInline(String name) {
    return '$name 请求截图';
  }

  @override
  String get screenshotRequestAllowed => '你已允许截图';

  @override
  String get screenshotRequestDeclined => '你已拒绝截图';

  @override
  String get screenshotRequestExpired => '截图请求已过期';

  @override
  String get wiltingTapToReveal => '点按查看凋零消息';

  @override
  String get wiltingMessageTag => '凋零消息';

  @override
  String get wiltedMessage => '已凋零的消息';

  @override
  String get wiltingSheetTitle => '凋零消息';

  @override
  String get wiltingSheetBody => '收件人打开后，消息将在这么多秒后消失。';

  @override
  String get wiltingSheetSend => '发送凋零消息';

  @override
  String get wiltingHoldToSendHint => '长按以发送凋零消息';

  @override
  String get replyYou => '你';

  @override
  String get replySomeone => '某人';

  @override
  String get replyPreviewImage => '📷 照片';

  @override
  String get replyPreviewVoice => '🎤 语音消息';

  @override
  String get replyPreviewMessage => '消息';

  @override
  String get replyUnavailable => '原始消息不可用';

  @override
  String get shopEntryTitle => '商店与 WiltKey Plus';

  @override
  String get shopEntrySubtitle => '主题、解锁与 Plus';

  @override
  String get supportEntryTitle => '支持项目';

  @override
  String get supportEntrySubtitle => '帮助 WiltKey 持续运行';

  @override
  String get shopTitle => '商店';

  @override
  String get supportTitle => '支持 WiltKey';

  @override
  String get shopPlusSection => 'WiltKey Plus';

  @override
  String get shopUnlocksSection => '解锁内容';

  @override
  String get shopPlusTagline => '更长的离线消息保留时间及更大的文件传输。';

  @override
  String get shopEmptyTitle => '这里还没有内容';

  @override
  String get shopEmptyBody => '商品即将上线，请稍后再来。';

  @override
  String get shopRestoreButton => '恢复购买';

  @override
  String get shopRestoredSnack => '购买已恢复';

  @override
  String get shopBuyButton => '购买';

  @override
  String get shopOwnedLabel => '已拥有';

  @override
  String get shopActiveLabel => '生效中';

  @override
  String get shopManageNote => '在 Google Play 中管理';

  @override
  String get shopPurchasePendingSnack => '购买处理中…';

  @override
  String get shopPurchaseFailedSnack => '购买未能完成';

  @override
  String get supportIntro =>
      'WiltKey 是免费且开源的，此版本免费解锁所有装饰内容。如果你愿意支持开发和官方中继服务器，请访问下方页面。';

  @override
  String get supportOpenButton => '打开支持页面';

  @override
  String get supportFreeNote => '此版本已解锁所有装饰内容。';

  @override
  String get shopTabPalettes => '调色板';

  @override
  String get shopTabThemes => '主题';

  @override
  String get shopTabBorders => '边框';

  @override
  String get shopTabPlus => 'Plus';

  @override
  String get shopTabPromo => 'promo';

  @override
  String get shopPalettesIntro =>
      '用于绘制头像和群组图标的额外颜色。收到的作品始终完整显示——色板仅解锁你自己用这些颜色作画的能力。';

  @override
  String shopPaletteColorCount(int count) {
    return '$count 种额外颜色';
  }

  @override
  String get shopThemesEmptyTitle => '暂无主题';

  @override
  String get shopThemesEmptyBody => '高级主题即将推出——三款内置主题永久免费。';

  @override
  String get shopBordersSoonTitle => '边框即将推出';

  @override
  String get shopBordersSoonBody => '为你的头像添加装饰边框，与你聊天的所有人都能看到。正在开发中。';

  @override
  String get shopPlusBenefitsSection => '你将获得';

  @override
  String get shopPlusBenefitHold => '离线时，你的消息在中继服务器上保留 72 小时，而非 24 小时。';

  @override
  String get shopPlusBenefitFiles => '发送大文件——每条消息最多 50 MB，突破免费的 5 MB 限制。';

  @override
  String get shopPlusBenefitPads => '创建更大的密码本——单聊最高 200 MB，群组最高 500 MB。';

  @override
  String get shopPlusBenefitSupport => '你让中继服务器持续运行，并保持 WiltKey 的独立性。';

  @override
  String get shopSubscribeButton => '订阅';

  @override
  String get shopPriceUnavailable => '不可用';

  @override
  String get shopPromoIntro => '有促销代码吗？在下方输入，Google Play 会将其应用到你的账号。';

  @override
  String get shopPromoHint => '促销代码';

  @override
  String get shopPromoRedeemButton => '在 Google Play 中兑换';

  @override
  String get shopPromoNote => '代码在 Play 商店中兑换。应用后，解锁内容会自动显示在这里。';

  @override
  String pairLargerPadsUpsell(String max) {
    return '使用 Plus 获得更大的密码本——最高 $max';
  }

  @override
  String pairNotEnoughSpace(String needed, String free) {
    return '可用空间不足——此聊天需要 $needed，而你只有 $free。';
  }

  @override
  String pairSyncingGenerating(String written, String total) {
    return '正在生成密钥流……$written / $total';
  }

  @override
  String get pairKeepAppOpen => '请保持应用开启——安全密码本仍在创建中。';

  @override
  String groupLargerPadsUpsell(String max) {
    return '使用 Plus 获得更大的群组密码本——最高 $max';
  }

  @override
  String get settingsBorderSection => '头像边框';

  @override
  String get shopBordersIntro =>
      '为你的头像添加边框和配饰。与你聊天的所有人都能看到你的边框——锁定只会阻止你装备它，绝不影响其显示。';

  @override
  String get shopBorderSubtitle => '头像边框';

  @override
  String get shopFreeLabel => '免费';

  @override
  String get notificationModePrivate => '私密';

  @override
  String get notificationModePrivateDesc =>
      '在后台定期检查新消息，不使用 Google 推送服务。提醒可能会有延迟，但没有任何信号经过第三方服务。';

  @override
  String get connectSectionOneOnOne => '一对一聊天';

  @override
  String get connectSectionGroups => '群组';

  @override
  String get connectByteBudgetTitle => '字节预算';

  @override
  String get connectByteBudgetDesc => '无时间限制，有容量限制。最适合长期的亲友聊天及高安全需求。';

  @override
  String get connectTimeWiltTitle => 'Time Wilt';

  @override
  String get connectTimeWiltDesc => '有时间限制，无容量限制。适合认识新朋友、相亲或短期的临时聊天。';

  @override
  String get connectRemotePairTitle => '远程配对（测试）';

  @override
  String get connectRemotePairDesc => '仅供测试：通过服务器与测试人员配对（使用 PIN 与身份哈希）。';

  @override
  String get connectByteBudgetGroupTitle => '字节预算群组';

  @override
  String get connectByteBudgetGroupDesc => '无时间限制，有容量限制。通过当面邀请成员来创建群组。';

  @override
  String get connectTimeWiltGroupTitle => 'Time Wilt 群组';

  @override
  String get connectTimeWiltGroupDesc => '有时间限制，无容量限制。消息随时间自动过期的休闲群组。';

  @override
  String get connectJoinGroupTitle => '加入群组';

  @override
  String get connectJoinGroupDesc => '附近有人邀请了你 — 搜索对方的群组信号。';

  @override
  String get connectJoinRemoteGroupTitle => '加入远程群组（测试）';

  @override
  String get connectJoinRemoteGroupDesc => '仅供测试：通过服务器加入测试人员的群组。';

  @override
  String get connectBadgeSoon => '即将推出';

  @override
  String get timeWiltLifetimeLabel => '聊天时长';

  @override
  String get timeWiltPlusHint => '使用 Plus 解锁长达 6 个月的时长';

  @override
  String get timeWiltExplanation => '计时结束后，聊天将变为只读模式。';

  @override
  String timeWiltPairRequestDialogBody(String peerName, String lifetime) {
    return '是否接受来自 $peerName 的 Time Wilt 聊天？聊天将在 $lifetime 后变为只读模式。';
  }

  @override
  String timeWiltLifetimeDays(int count) {
    return '$count 天';
  }

  @override
  String timeWiltLifetimeHours(int count) {
    return '$count 小时';
  }

  @override
  String timeWiltLifetimeMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String timeWiltLifetimeMonths(int count) {
    return '$count 个月';
  }

  @override
  String get timeWiltLifetimeMoments => '片刻';
}
