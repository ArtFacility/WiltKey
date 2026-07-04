import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:wiltkey_client/features/groups/presentation/emoji_creator_screen.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/core/theme/wiltkey_tokens.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => '.';
  @override
  Future<String?> getApplicationSupportPath() async => '.';
  @override
  Future<String?> getLibraryPath() async => '.';
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
  @override
  Future<String?> getExternalStoragePath() async => '.';
  @override
  Future<List<String>?> getExternalCachePaths() async => [];
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [];
  @override
  Future<String?> getDownloadsPath() async => '.';
}

class MockImagePickerPlatform extends ImagePickerPlatform {
  final XFile mockFile;
  MockImagePickerPlatform(this.mockFile);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions? options,
  }) async {
    return mockFile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 transparent PNG bytes
  final transparentPngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 96, 96, 96,
    0, 0, 0, 5, 0, 1, 165, 246, 69, 122, 0, 0, 0, 0, 73, 69,
    78, 68, 174, 66, 96, 130
  ]);

  setUpAll(() async {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    final mockXFile = XFile.fromData(transparentPngBytes, name: 'mock.png');
    ImagePickerPlatform.instance = MockImagePickerPlatform(mockXFile);
    SharedPreferences.setMockInitialValues({});
  });

  group('EmojiCreator State Models & Painters', () {
    test('EraseStroke clone creates deep copies of points list', () {
      final stroke = EraseStroke(
        points: [const Offset(10, 10), const Offset(20, 20)],
        width: 15.0,
      );
      final cloned = stroke.clone();

      expect(cloned.width, stroke.width);
      expect(cloned.points, equals(stroke.points));
      expect(identical(cloned.points, stroke.points), isFalse);
    });

    test('EditStep stores turns and strokes correctly', () {
      final stroke = EraseStroke(points: [const Offset(5, 5)], width: 10.0);
      final step = EditStep(rotationRadians: 1.5, strokes: [stroke]);

      expect(step.rotationRadians, 1.5);
      expect(step.strokes.length, 1);
      expect(step.strokes.first, stroke);
    });
  });

  group('EmojiCreatorScreen Widget Test', () {
    testWidgets('picks image, toggles modes, rotates, and undos', (WidgetTester tester) async {
      final theme = WiltkeyThemeRegistry.byId('cyberpunk').build();

      await tester.runAsync(() async {
        // Wrap in MaterialApp and Theme with WiltkeyTokens
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const EmojiCreatorScreen(chatKey: 'test_chat_key'),
          ),
        );

        // Trigger frame to run the post-frame callback _pickImage
        await tester.pump();
        // Wait for image picker and codec decoding to complete
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();

        // Verify that we are now in the crop stage
        expect(find.text('Pan & zoom to frame the emoji'), findsOneWidget);

        // Verify we have a "Pan & Zoom" and "Erase BG" buttons
        expect(find.text('Pan & Zoom'), findsOneWidget);
        expect(find.text('Erase BG'), findsOneWidget);

        // Find the tools
        final eraseBgButton = find.text('Erase BG');
        final panZoomButton = find.text('Pan & Zoom');

        // Tap on Erase BG
        await tester.tap(eraseBgButton);
        await tester.pump();

        // Confirm text updates to Erase mode
        expect(find.text('Drag to erase the background'), findsOneWidget);

        // Find Rotate button
        final rotateFinder = find.byIcon(Icons.rotate_right);
        expect(rotateFinder, findsOneWidget);

        // Tap Rotate 90°
        await tester.tap(rotateFinder);
        await tester.pump();

        // Find Undo
        final undoFinder = find.byIcon(Icons.undo);
        expect(undoFinder, findsOneWidget);

        // Tap Undo
        await tester.tap(undoFinder);
        await tester.pump();

        // Tap back to Pan & Zoom mode
        await tester.tap(panZoomButton);
        await tester.pump();

        expect(find.text('Pan & zoom to frame the emoji'), findsOneWidget);
      });
    });
  });
}
