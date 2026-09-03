import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wiltkey_client/core/db/wiltkey_db.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/stories/story_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v1.4.0 Social Quotas & Wilting Stories Tests', () {
    test('SocialBudgetInfo correctly calculates used fraction and remaining bytes', () {
      final freeBudget = SocialBudgetInfo(
        userId: 'alice_key_hash',
        bytesUsed: 2 * 1024 * 1024, // 2MB used
        maxBytes: 10 * 1024 * 1024, // 10MB free quota
        isPlus: false,
        weekStart: DateTime.now(),
        resetInSeconds: 3600 * 24 * 5,
      );

      expect(freeBudget.isPlus, isFalse);
      expect(freeBudget.usedFraction, closeTo(0.2, 0.001));
      expect(freeBudget.remainingBytes, equals(8 * 1024 * 1024));

      final plusBudget = SocialBudgetInfo(
        userId: 'bob_key_hash',
        bytesUsed: 50 * 1024 * 1024, // 50MB used
        maxBytes: 100 * 1024 * 1024, // 100MB plus quota
        isPlus: true,
        weekStart: DateTime.now(),
        resetInSeconds: 3600 * 24 * 2,
      );

      expect(plusBudget.isPlus, isTrue);
      expect(plusBudget.usedFraction, closeTo(0.5, 0.001));
      expect(plusBudget.remainingBytes, equals(50 * 1024 * 1024));
    });

    test('Story model remaining time and progress countdown calculations', () {
      final now = DateTime.now();
      final createdAt = now.subtract(const Duration(hours: 6));
      final expiresAt = now.add(const Duration(hours: 18)); // 24h total duration

      final story = Story(
        id: 'story_123',
        senderId: 'sender_abc',
        storyType: 'text',
        content: 'Hello World',
        createdAt: createdAt,
        expiresAt: expiresAt,
        bytesUsed: 150,
      );

      expect(story.isExpired, isFalse);
      expect(story.remainingProgress, closeTo(0.75, 0.02));
    });

    test('SocialBudgetInfo.fromJson correctly parses integer unix epoch week_start', () {
      final json = {
        'status': 'ok',
        'user_id': 'alice_key_hash',
        'bytes_used': 150000,
        'max_bytes': 10485760,
        'is_plus': false,
        'week_start': 1756137600, // Unix epoch timestamp in seconds (int)
        'reset_in_seconds': 432000,
      };

      final info = SocialBudgetInfo.fromJson(json);
      expect(info.userId, equals('alice_key_hash'));
      expect(info.bytesUsed, equals(150000));
      expect(info.maxBytes, equals(10485760));
      expect(info.isPlus, isFalse);
      expect(info.weekStart.millisecondsSinceEpoch, equals(1756137600 * 1000));
      expect(info.resetInSeconds, equals(432000));
      expect(info.usedFraction, closeTo(0.0143, 0.001));
    });
  });

  group('v1.4.0 Contact Private Notes & Custom Nicknames Tests', () {
    late WiltkeyDatabase db;
    const testContactId = 'test_notes_contact_140';
    const testKeyHash = 'charlie_hash_140';

    setUp(() async {
      db = WiltkeyDatabase.instance;
      await db.init();
    });

    test('Contact displayName falls back to name when customNickname is null or empty', () {
      final contact = Contact(
        id: testContactId,
        name: 'Official Bob',
        relayUrl: 'http://localhost:8000',
        isPrivateNode: false,
        maxBufferBytes: 10000,
        remainingBufferBytes: 10000,
        peerRemainingBufferBytes: 10000,
        keyHash: 'bob_hash',
        lastActivity: DateTime.now(),
      );

      expect(contact.displayName, equals('Official Bob'));

      final nicknamed = contact.copyWith(customNickname: 'Bobby');
      expect(nicknamed.displayName, equals('Bobby'));

      final emptyNick = contact.copyWith(customNickname: '   ');
      expect(emptyNick.displayName, equals('Official Bob'));
    });

    test('updateContactNotes stores and updates private notes and custom nickname in SQLite', () async {
      final contact = Contact(
        id: testContactId,
        name: 'Charlie',
        relayUrl: 'http://localhost:8000',
        isPrivateNode: false,
        maxBufferBytes: 5000,
        remainingBufferBytes: 5000,
        peerRemainingBufferBytes: 5000,
        keyHash: testKeyHash,
        lastActivity: DateTime.now(),
      );

      await db.upsertContact(contact);

      // Update notes and nickname
      await db.updateContactNotes(
        testKeyHash,
        customNickname: 'Chuck',
        privateNotes: 'Met at DEFCON 2026. Hardware hacker.',
      );

      final contacts = await db.getAllContacts();
      final updated = contacts.firstWhere((c) => c.keyHash == testKeyHash);

      expect(updated.displayName, equals('Chuck'));
      expect(updated.customNickname, equals('Chuck'));
      expect(updated.privateNotes, equals('Met at DEFCON 2026. Hardware hacker.'));
    });
  });
}
