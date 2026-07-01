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
  String get navPair => '配对';

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
  String get settingsLanguageEnglish => 'English';

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
  String get notificationModeLowPowerDesc => '每隔约 10 分钟检查一次新消息。省电模式。';

  @override
  String get notificationModeInstant => '即时通知';

  @override
  String get notificationModeInstantDesc => '在后台保持安全连接以获取即时通知。会显示一条常驻通知，且较为耗电。';

  @override
  String get notificationNewMessageBody => '你收到一条消息';

  @override
  String get notificationSecureLinkActive => '安全链路已激活';

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
  String get settingsBiometricDescription => '用指纹代替 PIN 解锁。闲置 4 小时后仍需输入 PIN。';

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
      'If you run low on chat capacity, you can borrow unused space from your peer. This can also happen automatically so you can keep chatting.';

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
}
