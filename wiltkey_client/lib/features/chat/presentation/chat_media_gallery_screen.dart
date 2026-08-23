import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/db/wiltkey_db.dart';
import '../../../core/models.dart';
import '../../../core/state.dart';
import '../../../core/theme/wk.dart';
import '../../../core/theme/wiltkey_tokens.dart';
import 'widgets/chat_image_thumbnail.dart';
import 'widgets/image_viewer.dart';
import 'widgets/link_warning_dialog.dart';
import 'widgets/voice_message_player.dart';

/// Full-screen gallery displaying all shared Photos, Voice Notes, and Links in a chat.
class ChatMediaGalleryScreen extends StatefulWidget {
  final Contact contact;

  const ChatMediaGalleryScreen({super.key, required this.contact});

  @override
  State<ChatMediaGalleryScreen> createState() => _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends State<ChatMediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  late TabController _tabController;

  List<ChatMessage> _mediaMessages = [];
  List<ChatMessage> _voiceMessages = [];
  List<ChatMessage> _linkMessages = [];
  bool _loadingPhotos = true;
  bool _loadingVoice = true;
  bool _loadingLinks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPhotos();
    _loadVoice();
    _loadLinks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    final chatId = widget.contact.id;
    final masterKey = _appState.masterKeyHex;
    final media = await WiltkeyDatabase.instance.getChatMediaMessages(
      chatId,
      masterKeyHex: masterKey,
    );
    if (mounted) {
      setState(() {
        _mediaMessages = media;
        _loadingPhotos = false;
      });
    }
  }

  Future<void> _loadVoice() async {
    final chatId = widget.contact.id;
    final masterKey = _appState.masterKeyHex;
    final voice = await WiltkeyDatabase.instance.getChatVoiceMessages(
      chatId,
      masterKeyHex: masterKey,
    );
    if (mounted) {
      setState(() {
        _voiceMessages = voice;
        _loadingVoice = false;
      });
    }
  }

  Future<void> _loadLinks() async {
    final chatId = widget.contact.id;
    final masterKey = _appState.masterKeyHex;
    final links = await WiltkeyDatabase.instance.getChatLinkMessages(
      chatId,
      masterKeyHex: masterKey,
    );
    if (mounted) {
      setState(() {
        _linkMessages = links;
        _loadingLinks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    final photoCount = _loadingPhotos ? '…' : '${_mediaMessages.length}';
    final voiceCount = _loadingVoice ? '…' : '${_voiceMessages.length}';
    final linkCount = _loadingLinks ? '…' : '${_linkMessages.length}';

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: t.action),
        title: Text(
          t.uppercaseLabels
              ? l10n.chatDetailsSectionMedia.toUpperCase()
              : l10n.chatDetailsSectionMedia,
          style: t.screenTitle.copyWith(fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: t.action,
          labelColor: t.action,
          unselectedLabelColor: t.textTertiary,
          labelStyle: t.sectionLabel.copyWith(fontSize: 11),
          tabs: [
            Tab(
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              text: '${l10n.chatDetailsMediaPhotos} ($photoCount)',
            ),
            Tab(
              icon: const Icon(Icons.mic_none_outlined, size: 18),
              text: '${l10n.chatDetailsMediaVoice} ($voiceCount)',
            ),
            Tab(
              icon: const Icon(Icons.link_outlined, size: 18),
              text: '${l10n.chatDetailsMediaLinks} ($linkCount)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotosTab(t, l10n),
          _buildVoiceTab(t, l10n),
          _buildLinksTab(t, l10n),
        ],
      ),
    );
  }

  Widget _buildPhotosTab(WiltkeyTokens t, AppLocalizations l10n) {
    if (_loadingPhotos) {
      return _buildSkeletonPhotosGrid(t);
    }
    if (_mediaMessages.isEmpty) {
      return _buildEmptyState(t, Icons.photo_library_outlined, l10n.chatDetailsNoMedia);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _mediaMessages.length,
      itemBuilder: (context, index) {
        final msg = _mediaMessages[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusControl),
          child: Container(
            color: t.surface,
            child: ChatImageThumbnail(
              appState: _appState,
              contact: widget.contact,
              message: msg,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceTab(WiltkeyTokens t, AppLocalizations l10n) {
    if (_loadingVoice) {
      return _buildSkeletonVoiceList(t);
    }
    if (_voiceMessages.isEmpty) {
      return _buildEmptyState(t, Icons.mic_none_outlined, l10n.chatDetailsNoVoice);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _voiceMessages.length,
      itemBuilder: (context, index) {
        final msg = _voiceMessages[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(t.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    msg.isSentByMe ? 'You' : widget.contact.name,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: msg.isSentByMe ? t.action : t.textPrimary,
                    ),
                  ),
                  Text(
                    _formatTimestamp(msg.timestamp),
                    style: t.dataMono.copyWith(color: t.textTertiary, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              VoiceMessagePlayer(message: msg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksTab(WiltkeyTokens t, AppLocalizations l10n) {
    if (_loadingLinks) {
      return _buildSkeletonLinksList(t);
    }
    if (_linkMessages.isEmpty) {
      return _buildEmptyState(t, Icons.link_outlined, l10n.chatDetailsNoLinks);
    }

    final linkRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _linkMessages.length,
      itemBuilder: (context, index) {
        final msg = _linkMessages[index];
        final text = msg.decryptedText ?? msg.text;
        final match = linkRegex.firstMatch(text);
        final url = match?.group(0) ?? text;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(t.radiusCard),
          ),
          child: InkWell(
            onTap: () {
              try {
                showLinkWarningDialog(context, Uri.parse(url));
              } catch (_) {}
            },
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.action.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(t.radiusControl),
                  ),
                  child: Icon(Icons.link, color: t.action, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(
                          color: t.action,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${msg.isSentByMe ? 'You' : widget.contact.name} · ${_formatTimestamp(msg.timestamp)}',
                        style: t.dataMono.copyWith(
                          color: t.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: t.textTertiary, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonPhotosGrid(WiltkeyTokens t) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.radiusControl),
            border: Border.all(color: t.border.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              color: t.textTertiary.withValues(alpha: 0.25),
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonVoiceList(WiltkeyTokens t) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(t.radiusCard),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.border.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: t.border.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLinksList(WiltkeyTokens t) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(t.radiusCard),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(t.radiusControl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: t.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.border.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(WiltkeyTokens t, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: t.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            style: t.bodySecondary.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }
}
