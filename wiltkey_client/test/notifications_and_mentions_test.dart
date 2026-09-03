import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Contact notification modes', () {
    test('defaults to all and exposes helper getters', () {
      final c = Contact(
        id: 'c1',
        name: 'Alice',
        keyHash: 'hash1',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        maxBufferBytes: 1000,
        remainingBufferBytes: 500,
        peerRemainingBufferBytes: 500,
        lastActivity: DateTime.now(),
      );

      expect(c.notificationMode, equals('all'));
      expect(c.isMuted, isFalse);
      expect(c.isMentionsOnly, isFalse);

      final muted = c.copyWith(notificationMode: 'muted');
      expect(muted.notificationMode, equals('muted'));
      expect(muted.isMuted, isTrue);
      expect(muted.isMentionsOnly, isFalse);

      final mentionsOnly = c.copyWith(notificationMode: 'mentions_only');
      expect(mentionsOnly.notificationMode, equals('mentions_only'));
      expect(mentionsOnly.isMuted, isFalse);
      expect(mentionsOnly.isMentionsOnly, isTrue);
    });

    test('serializes and deserializes notificationMode correctly', () {
      final c = Contact(
        id: 'c2',
        name: 'Group Chat',
        keyHash: 'group_hash_1',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        isGroup: true,
        maxBufferBytes: 1000,
        remainingBufferBytes: 500,
        peerRemainingBufferBytes: 0,
        lastActivity: DateTime.now(),
        notificationMode: 'mentions_only',
      );

      final json = c.toJson();
      expect(json['notificationMode'], equals('mentions_only'));

      final restored = Contact.fromJson(json);
      expect(restored.notificationMode, equals('mentions_only'));
      expect(restored.isMentionsOnly, isTrue);
    });
  });

  group('AppState notification filtering and alerts', () {
    late AppState state;
    late Contact dmContact;
    late Contact groupContact;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      state.appLifecycleState = AppLifecycleState.resumed;
      state.isLocked = false;
      state.isDrainingPendingInbox = false;
      state.visibleChatId = null;
      state.messageAlert.value = null;
      state.notifyDirectMessages = true;
      state.notifyGroupMessages = true;
      state.notifyEvents = true;
      state.notifyMentionsAndReplies = true;

      dmContact = Contact(
        id: 'dm1',
        name: 'Bob',
        keyHash: 'hash_bob',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        isGroup: false,
        maxBufferBytes: 1000,
        remainingBufferBytes: 500,
        peerRemainingBufferBytes: 500,
        lastActivity: DateTime.now(),
      );

      groupContact = Contact(
        id: 'grp1',
        name: 'Team Alpha',
        keyHash: 'hash_group_alpha',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        isGroup: true,
        maxBufferBytes: 1000,
        remainingBufferBytes: 500,
        peerRemainingBufferBytes: 0,
        lastActivity: DateTime.now(),
      );
    });

    test('emits alert for standard DM when enabled and not muted', () {
      state.emitMessageAlert(dmContact);
      expect(state.messageAlert.value, isNotNull);
      expect(state.messageAlert.value!.contact.id, equals('dm1'));
    });

    test('suppresses alert for DM when notifyDirectMessages is false', () {
      state.notifyDirectMessages = false;
      state.emitMessageAlert(dmContact);
      expect(state.messageAlert.value, isNull);
    });

    test('suppresses alert for muted DM', () {
      final muted = dmContact.copyWith(notificationMode: 'muted');
      state.emitMessageAlert(muted);
      expect(state.messageAlert.value, isNull);
    });

    test('suppresses regular group alert when notifyGroupMessages is false', () {
      state.notifyGroupMessages = false;
      state.emitMessageAlert(groupContact, isMentionOrReply: false);
      expect(state.messageAlert.value, isNull);
    });

    test('allows group alert when notifyGroupMessages is false if mentioned/replied', () {
      state.notifyGroupMessages = false;
      state.emitMessageAlert(groupContact, isMentionOrReply: true);
      expect(state.messageAlert.value, isNotNull);
      expect(state.messageAlert.value!.contact.id, equals('grp1'));
    });

    test('mentions_only group mode ignores regular message but fires on mention/reply', () {
      final mentionsGroup = groupContact.copyWith(notificationMode: 'mentions_only');
      
      // Regular message -> no alert
      state.emitMessageAlert(mentionsGroup, isMentionOrReply: false);
      expect(state.messageAlert.value, isNull);

      // Mention/reply message -> fires alert
      state.emitMessageAlert(mentionsGroup, isMentionOrReply: true);
      expect(state.messageAlert.value, isNotNull);
      expect(state.messageAlert.value!.contact.id, equals('grp1'));
    });

    test('muted group suppresses even mentions/replies', () {
      final mutedGroup = groupContact.copyWith(notificationMode: 'muted');
      state.emitMessageAlert(mutedGroup, isMentionOrReply: true);
      expect(state.messageAlert.value, isNull);
    });
  });
}
