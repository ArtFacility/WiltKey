import 'package:flutter/material.dart';
import 'story_composer_screen.dart';

export 'story_composer_screen.dart' show StoryTextTag, StoryComposerScreen;

/// Entry point to open the full-screen 24-hour Wilting Story studio.
class CreateStorySheet {
  static Future<void> show(
    BuildContext context, {
    String initialMode = 'photo',
  }) {
    return StoryComposerScreen.open(context, initialMode: initialMode);
  }
}
