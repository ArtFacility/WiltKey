import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../core/db/wiltkey_db.dart';
import '../../../core/models.dart';
import '../../../core/state.dart';
import '../../../core/theme/wk.dart';

/// Blocked Contacts screen: lists the local block list (contact_blocks).
/// Blocking a peer deletes the contact on both ends; the block list here keeps
/// their future inbound contact requests silently dropped until unblocked.
class BlockedContactsScreen extends StatefulWidget {
  const BlockedContactsScreen({super.key});

  @override
  State<BlockedContactsScreen> createState() => _BlockedContactsScreenState();
}

class _BlockedContactsScreenState extends State<BlockedContactsScreen> {
  final AppState _appState = AppState();
  List<ContactBlock> _blocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final blocks = await WiltkeyDatabase.instance.getAllContactBlocks();
    if (!mounted) return;
    setState(() {
      _blocks = blocks;
      _loading = false;
    });
  }

  String _displayName(String keyHash) {
    for (final c in _appState.contacts) {
      if (c.keyHash == keyHash && !c.isGroup) return c.name;
    }
    return keyHash.length >= 12
        ? keyHash.substring(0, 12).toUpperCase()
        : keyHash;
  }

  Future<void> _unblock(ContactBlock block) async {
    await _appState.unblockContact(block.keyHash);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          t.uppercaseLabels
              ? l10n.settingsBlockedContacts.toUpperCase()
              : l10n.settingsBlockedContacts,
          style: t.screenTitle.copyWith(fontSize: 18),
        ),
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, color: t.textTertiary, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          l10n.settingsBlockedEmpty,
                          style: t.bodySecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final block = _blocks[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(color: t.border, width: t.borderWidth),
                        borderRadius: BorderRadius.circular(t.radiusCard),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _displayName(block.keyHash),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (block.blockedAt > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(block.blockedAt),
                                    style: t.bodySecondary.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _unblock(block),
                            child: Text(
                              l10n.contactUnblock,
                              style: t.badgeLabel.copyWith(color: t.action),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
