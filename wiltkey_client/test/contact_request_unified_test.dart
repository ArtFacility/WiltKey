import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Contact Request Unified Flow Tests', () {
    test('AppEvent status update in-memory mutates data payload correctly', () {
      final ev = AppEvent(
        id: 'contact_request_test123',
        type: 'contact_request',
        title: 'Alice',
        body: 'sent you a contact request',
        chatKey: 'group_abc',
        data: jsonEncode({
          'requester_key': 'peer_key_1',
          'requester_name': 'Alice',
          'status': 'pending',
        }),
        timestamp: DateTime.now(),
      );

      expect(ev.dataMap()['status'], 'pending');

      ev.updateStatus('accepted');
      expect(ev.dataMap()['status'], 'accepted');
      expect(ev.data, contains('"status":"accepted"'));

      ev.updateStatus('declined');
      expect(ev.dataMap()['status'], 'declined');
      expect(ev.data, contains('"status":"declined"'));
    });

    test('surfacePendingContactRequests ignores non-pending and read events', () {
      final appState = AppState();

      final pendingEvent = AppEvent(
        id: 'contact_request_pending',
        type: 'contact_request',
        title: 'Bob',
        body: 'sent you a contact request',
        chatKey: 'group_xyz',
        data: jsonEncode({
          'requester_key': 'peer_bob',
          'requester_name': 'Bob',
          'status': 'pending',
        }),
        timestamp: DateTime.now(),
        read: false,
      );

      final acceptedEvent = AppEvent(
        id: 'contact_request_accepted',
        type: 'contact_request',
        title: 'Charlie',
        body: 'sent you a contact request',
        chatKey: 'group_xyz',
        data: jsonEncode({
          'requester_key': 'peer_charlie',
          'requester_name': 'Charlie',
          'status': 'accepted',
        }),
        timestamp: DateTime.now(),
        read: false,
      );

      final readPendingEvent = AppEvent(
        id: 'contact_request_read',
        type: 'contact_request',
        title: 'Dave',
        body: 'sent you a contact request',
        chatKey: 'group_xyz',
        data: jsonEncode({
          'requester_key': 'peer_dave',
          'requester_name': 'Dave',
          'status': 'pending',
        }),
        timestamp: DateTime.now(),
        read: true,
      );

      appState.events = [readPendingEvent, acceptedEvent, pendingEvent];

      appState.contactRequestPopup.value = null;
      appState.surfacePendingContactRequests();

      // Only pendingEvent should be surfaced
      expect(appState.contactRequestPopup.value, isNotNull);
      expect(appState.contactRequestPopup.value!.id, 'contact_request_pending');

      // Once pendingEvent is resolved, advancing popup should clear it because
      // acceptedEvent is not 'pending' and readPendingEvent is read.
      pendingEvent.updateStatus('accepted');
      pendingEvent.read = true;
      appState.advanceContactRequestPopup();
      expect(appState.contactRequestPopup.value, isNull);
    });

    test('Direct chat message filter suppresses contact request cards', () {
      final messages = [
        ChatMessage(
          id: 'msg_normal',
          senderId: 'alice_key',
          text: 'Hello',
          contentType: 'text',
          timestamp: DateTime.now(),
          isSentByMe: false,
        ),
        ChatMessage(
          id: 'msg_contact_sent',
          senderId: 'system',
          text: jsonEncode({'status': 'pending'}),
          contentType: 'contact_request_sent',
          timestamp: DateTime.now(),
          isSentByMe: true,
        ),
        ChatMessage(
          id: 'msg_contact_recv',
          senderId: 'system',
          text: jsonEncode({'status': 'pending'}),
          contentType: 'contact_request_received',
          timestamp: DateTime.now(),
          isSentByMe: false,
        ),
      ];

      // Replicating chat_screen visibleMessages filter:
      final visible = messages.where(
        (m) =>
            m.contentType != 'emoji_def' &&
            m.contentType != 'emoji_delete' &&
            m.contentType != 'contact_request_sent' &&
            m.contentType != 'contact_request_received',
      ).toList();

      expect(visible.length, 1);
      expect(visible.first.id, 'msg_normal');
    });

    test('Group member membership check recognizes host even if not in memberKeyHashes', () {
      final hostKey = 'host_public_key_hash';
      final memberKey = 'member_public_key_hash';

      final group = Contact(
        id: 'g1',
        name: 'Test Group',
        keyHash: 'group_id_123',
        relayUrl: 'wss://test.relay',
        isPrivateNode: false,
        maxBufferBytes: 10000,
        remainingBufferBytes: 10000,
        peerRemainingBufferBytes: 10000,
        lastActivity: DateTime.now(),
        isGroup: true,
        hostKeyHash: hostKey,
        memberKeyHashes: [memberKey], // host omitted from memberKeyHashes
        groupSeed: 'dummy_group_seed',
      );

      // Verify membership logic used in _handleContactRequest and _handleContactResponse:
      bool isGroupMember(String senderId) {
        return group.memberKeyHashes.contains(senderId) ||
            group.hostKeyHash == senderId;
      }

      expect(isGroupMember(hostKey), isTrue);
      expect(isGroupMember(memberKey), isTrue);
      expect(isGroupMember('unknown_stranger'), isFalse);
    });
  });
}
