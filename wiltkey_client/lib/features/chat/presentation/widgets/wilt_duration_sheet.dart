import 'package:flutter/material.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';
import '../../../../core/theme/wk.dart';

/// Bottom sheet for composing a **wilting** (disappearing) message: pick how many
/// seconds it lives once the recipient opens it (1–60, default 5). Returned by a
/// long-press on the send button; shared by 1-on-1 and group chats. Returns the
/// chosen lifetime in seconds, or null if the user backed out (→ nothing sent).
Future<int?> showWiltDurationSheet(
  BuildContext context, {
  int initialSeconds = 5,
}) {
  final t = context.wk;
  final l10n = AppLocalizations.of(context)!;
  double secs = initialSeconds.toDouble().clamp(1, 60);

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: t.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusCard)),
    ),
    builder: (ctx) => SafeArea(
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_florist_outlined, color: t.action, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t.uppercaseLabels
                        ? l10n.wiltingSheetTitle.toUpperCase()
                        : l10n.wiltingSheetTitle,
                    style: t.screenTitle.copyWith(fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.wiltingSheetBody,
                style: t.bodySecondary.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: secs,
                      min: 1,
                      max: 60,
                      divisions: 59,
                      activeColor: t.action,
                      label: '${secs.round()}s',
                      onChanged: (v) => setSheet(() => secs = v),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${secs.round()}s',
                      textAlign: TextAlign.end,
                      style: t.dataMono.copyWith(
                        color: t.action,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(secs.round()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.action,
                    foregroundColor: t.onAction,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusControl),
                    ),
                  ),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text(
                    t.uppercaseLabels
                        ? l10n.wiltingSheetSend.toUpperCase()
                        : l10n.wiltingSheetSend,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
