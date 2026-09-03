import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/network/remote_pairing_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiltkey_client/core/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v1.3.5 History Retention & Media Gallery Tests', () {
    late WiltkeyDatabase db;
    const testChatId = 'test_chat_history_135';

    setUp(() async {
      db = WiltkeyDatabase.instance;
      await db.init();
      await db.deleteMessagesForChat(testChatId);
    });

    test('pruneChatMessages preserves keepLastCount messages and deletes older rows', () async {
      final now = DateTime.now();

      // Insert 10 messages
      for (int i = 0; i < 10; i++) {
        final msg = ChatMessage(
          id: 'msg_$i',
          senderId: i % 2 == 0 ? 'user_me' : 'peer_1',
          text: 'Message #$i',
          contentType: 'text',
          timestamp: now.add(Duration(minutes: i)),
          isSentByMe: i % 2 == 0,
          offset: i * 50,
          isFailed: false,
          isDelivered: true,
          isPending: false,
          allowSave: false,
          replyToId: null,
          ephemeral: false,
          ttlSeconds: 0,
          wilted: false,
          wiltedBy: {},
          isEdited: false,
          isDeleted: false,
          remoteSize: 0,
        );
        await db.saveMessage(msg, testChatId);
      }

      // Verify 10 messages exist
      var loaded = await db.getMessagesPage(testChatId, limit: 20);
      expect(loaded.length, 10);

      // Prune down to keep last 4 messages
      final prunedCount = await db.pruneChatMessages(testChatId, 4);
      expect(prunedCount, 6);

      // Verify only latest 4 remain (messages #6, #7, #8, #9)
      loaded = await db.getMessagesPage(testChatId, limit: 20);
      expect(loaded.length, 4);
      expect(loaded.first.id, 'msg_6');
      expect(loaded.last.id, 'msg_9');
    });

    test('getChatMediaMessages, getChatVoiceMessages, and getChatLinkMessages query correct subsets', () async {
      final now = DateTime.now();

      // Insert 1 photo
      await db.saveMessage(
        ChatMessage(
          id: 'photo_1',
          senderId: 'peer_1',
          text: 'base64_photo_bytes',
          contentType: 'image',
          timestamp: now.add(const Duration(minutes: 1)),
          isSentByMe: false,
          offset: 0,
          isFailed: false,
          isDelivered: true,
          isPending: false,
          allowSave: true,
          replyToId: null,
          ephemeral: false,
          ttlSeconds: 0,
          wilted: false,
          wiltedBy: {},
          isEdited: false,
          isDeleted: false,
          remoteSize: 0,
        ),
        testChatId,
      );

      // Insert 1 voice note
      await db.saveMessage(
        ChatMessage(
          id: 'voice_1',
          senderId: 'user_me',
          text: 'base64_voice_bytes',
          contentType: 'voice',
          timestamp: now.add(const Duration(minutes: 2)),
          isSentByMe: true,
          offset: 100,
          isFailed: false,
          isDelivered: true,
          isPending: false,
          allowSave: false,
          replyToId: null,
          ephemeral: false,
          ttlSeconds: 0,
          wilted: false,
          wiltedBy: {},
          isEdited: false,
          isDeleted: false,
          remoteSize: 0,
        ),
        testChatId,
      );

      // Insert 1 link message
      await db.saveMessage(
        ChatMessage(
          id: 'link_1',
          senderId: 'peer_1',
          text: 'Check this website out: https://wiltkey.org',
          contentType: 'text',
          timestamp: now.add(const Duration(minutes: 3)),
          isSentByMe: false,
          offset: 200,
          isFailed: false,
          isDelivered: true,
          isPending: false,
          allowSave: false,
          replyToId: null,
          ephemeral: false,
          ttlSeconds: 0,
          wilted: false,
          wiltedBy: {},
          isEdited: false,
          isDeleted: false,
          remoteSize: 0,
        ),
        testChatId,
      );

      final photos = await db.getChatMediaMessages(testChatId);
      final voices = await db.getChatVoiceMessages(testChatId);
      final links = await db.getChatLinkMessages(testChatId);

      expect(photos.length, 1);
      expect(photos.first.id, 'photo_1');

      expect(voices.length, 1);
      expect(voices.first.id, 'voice_1');

      expect(links.length, 1);
      expect(links.first.id, 'link_1');
    });
  });

  group('v1.3.5 QR Remote Pairing Security Tests', () {
    setUp(() {
      final appState = AppState();
      appState.userId = 'mock_user_id_12345';
      appState.publicKeyHex = 'mock_pub_hex_12345';
    });

    test('qrPayload URI encodes correctly', () {
      final controller = RemotePairingController();
      controller.pin = '654321';

      final payload = controller.qrPayload;
      expect(payload.startsWith('wiltkey://pair?'), isTrue);

      final uri = Uri.parse(payload);
      expect(uri.queryParameters['pin'], '654321');
      expect(uri.queryParameters['type'], 'timewilt');
      expect(uri.queryParameters['host'], 'mock_user_id_12345');
    });

    test('Remote pairing strictly rejects recharging existing OTP contacts', () async {
      final controller = RemotePairingController();
      final appState = AppState();

      // Add a mock existing OTP contact (maxBufferBytes > 0)
      final existingOtpContact = Contact(
        id: 'c_existing_otp_1',
        name: 'Existing In-Person Friend',
        keyHash: 'peer_otp_key_hash_1234567890abcdef',
        relayUrl: 'https://api.wiltkey.org',
        isPrivateNode: false,
        maxBufferBytes: 50 * 1024 * 1024,
        remainingBufferBytes: 20 * 1024 * 1024,
        peerRemainingBufferBytes: 20 * 1024 * 1024,
        lastActivity: DateTime.now(),
      );
      appState.contacts = [existingOtpContact];

      // Attempting to join with the existing OTP contact keyHash
      await controller.join('123456', 'peer_otp_key_hash_1234567890abcdef');

      // The attempt must immediately fail because recharge is forbidden remotely
      // and expected host hash validation / contact check aborts before corrupting pad.
      expect(controller.phase, RemotePairPhase.error);
      expect(controller.result, isNull);
    });
  });
}
