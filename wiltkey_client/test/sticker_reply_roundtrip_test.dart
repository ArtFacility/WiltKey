import 'package:flutter_test/flutter_test.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/custom_emoji.dart';

/// Regression: a held sticker must never be mis-parsed as a reply. Stickers and
/// the reply frame both use the SOH (0x01) sentinel; [parseReplyBody] must treat
/// a sticker body as plain content, not a reply to phantom parent "stk".
void main() {
  ({String? id, String text}) roundTrip(String? replyToId, String text) {
    final wire = ChatMessage.buildReplyBody(replyToId, text); // sender builds
    final parsed = ChatMessage.parseReplyBody(wire); // recipient parses
    return (id: parsed.$1, text: parsed.$2);
  }

  test('unicode sticker is not a reply', () {
    final r = roundTrip(null, wrapSticker('😀'));
    expect(r.id, isNull, reason: 'sticker must not be tagged as a reply');
    expect(stickerPayload(r.text), '😀', reason: 'still renders as a sticker');
  });

  test('custom emoji sticker is not a reply', () {
    final r = roundTrip(null, wrapSticker(':partyblob:'));
    expect(r.id, isNull);
    expect(stickerPayload(r.text), ':partyblob:');
  });

  test('a genuine text reply still parses', () {
    final r = roundTrip('2026-07-20 10:00:00.000', 'hello');
    expect(r.id, '2026-07-20 10:00:00.000');
    expect(r.text, 'hello');
    expect(stickerPayload(r.text), isNull);
  });

  test('a genuine reply whose body is a sticker still works', () {
    final r = roundTrip('2026-07-20 10:00:00.000', wrapSticker('😀'));
    expect(r.id, '2026-07-20 10:00:00.000');
    expect(stickerPayload(r.text), '😀');
  });

  test('plain text is untouched', () {
    final r = roundTrip(null, 'just a message');
    expect(r.id, isNull);
    expect(r.text, 'just a message');
  });
}
