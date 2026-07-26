import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

import '../../../../core/models.dart';
import '../../../../core/state.dart';
import '../../../../core/theme/wk.dart';
import '../../../../core/theme/wiltkey_tokens.dart';

/// Bubble for a large payload whose body is still held on the relay.
///
/// Big files aren't pushed down the socket any more — the relay advertises them
/// and keeps the body until we download it and confirm storage (or its hold TTL
/// runs out). So this bubble is the whole lifecycle: **idle** (tap to fetch),
/// **downloading** (a determinate ring + byte counter), and **failed** (tap to
/// retry, costing nothing because the relay still has its copy).
class DownloadBubble extends StatelessWidget {
  final ChatMessage message;
  final Contact contact;
  final AppState appState;

  const DownloadBubble({
    super.key,
    required this.message,
    required this.contact,
    required this.appState,
  });

  IconData get _icon => switch (message.contentType) {
    'image' || 'image_hidden' => Icons.image_outlined,
    'voice' => Icons.mic_none_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  String _kindLabel(AppLocalizations l10n) => switch (message.contentType) {
    'image' || 'image_hidden' => l10n.chatFileKindPhoto,
    'voice' => l10n.chatFileKindVoice,
    _ => l10n.chatFileKindFile,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;

    // Repaint on every progress tick without rebuilding the whole message list.
    return ValueListenableBuilder<int>(
      valueListenable: appState.downloadRevision,
      builder: (context, _, __) {
        final p = appState.downloadProgress[message.id];
        final bool busy = p != null && !p.failed;
        final bool failed = p?.failed ?? false;
        final Color accent = failed ? t.danger : t.action;

        return GestureDetector(
          onTap: busy
              ? null
              : () {
                  if (failed) appState.clearDownloadError(message.id);
                  appState.downloadPendingFile(contact, message);
                },
          child: Container(
            width: 210,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: t.borderWidth,
              ),
              borderRadius: BorderRadius.circular(t.radiusControl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _leading(t, accent, p, busy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.uppercaseLabels
                                ? _kindLabel(l10n).toUpperCase()
                                : _kindLabel(l10n),
                            style: t.body.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            busy
                                ? '${AppState.formatBytes(p.received)} / '
                                      '${AppState.formatBytes(p.total)}'
                                : AppState.formatBytes(message.remoteSize),
                            style: t.dataMono.copyWith(
                              fontSize: 9.5,
                              color: t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (busy && p.fraction != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: p.fraction,
                      minHeight: 3,
                      backgroundColor: t.budgetEmpty,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                if (!busy)
                  Text(
                    failed
                        ? l10n.chatFileDownloadFailed
                        : l10n.chatFileTapToDownload,
                    style: t.dataMono.copyWith(fontSize: 9.5, color: accent),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Icon at rest; a determinate ring (or spinner when the size is unknown)
  /// while the body is streaming in.
  Widget _leading(
    WiltkeyTokens t,
    Color accent,
    DownloadProgress? p,
    bool busy,
  ) {
    if (!busy) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(t.radiusControl),
        ),
        child: Icon(
          p?.failed ?? false ? Icons.refresh : _icon,
          color: accent,
          size: 19,
        ),
      );
    }
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: p!.fraction, // null → indeterminate (unknown length)
              strokeWidth: 2.4,
              backgroundColor: t.budgetEmpty,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          if (p.fraction != null)
            Text(
              '${(p.fraction! * 100).round()}',
              style: t.dataMono.copyWith(fontSize: 8.5, color: accent),
            ),
        ],
      ),
    );
  }
}
