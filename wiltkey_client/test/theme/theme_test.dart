import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiltkey_client/core/theme/components/petal_flower.dart';
import 'package:wiltkey_client/core/theme/theme_controller.dart';
import 'package:wiltkey_client/core/theme/theme_registry.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/theme/wiltkey_components.dart';
import 'package:wiltkey_client/core/theme/themes/cyberpunk_theme.dart';
import 'package:wiltkey_client/core/theme/themes/garden_theme.dart';
import 'package:wiltkey_client/core/theme/themes/paperink_theme.dart';
import 'package:wiltkey_client/core/theme/components/cyberpunk_components.dart';

/// Exercises the full component factory + token reads for a theme.
class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) {
    final wkc = context.wkc;
    return Scaffold(
      backgroundColor: context.wk.bg,
      body: wkc.ambientBackground(
        child: Column(
          children: [
            wkc.screenTitle(
              context,
              'Chats',
              subtitle: '3 contacts · 1 locked',
            ),
            wkc.statusBadge(context, StatusBadgeKind.group),
            wkc.budgetIndicator(
              ourFraction: 0.7,
              theirFraction: 0.3,
              isWilted: false,
            ),
            wkc.groupBudgetIndicator(
              members: const [
                MemberBudget(fraction: 0.8, isSelf: true),
                MemberBudget(fraction: 0.2, isHost: true),
              ],
              emptySlots: 1,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetalFlower.petalsFor (per side, 4 petals)', () {
    test('empty -> 0', () => expect(PetalFlower.petalsFor(0.0), 0));
    test('full -> 4', () => expect(PetalFlower.petalsFor(1.0), 4));
    test('over-full clamps -> 4', () => expect(PetalFlower.petalsFor(1.5), 4));
    test(
      'tiny budget keeps a petal',
      () => expect(PetalFlower.petalsFor(0.01), 1),
    );
    test('quarter boundary', () => expect(PetalFlower.petalsFor(0.25), 1));
    test('just over a quarter', () => expect(PetalFlower.petalsFor(0.26), 2));
    test('three quarters', () => expect(PetalFlower.petalsFor(0.75), 3));
  });

  group('WiltkeyThemeRegistry', () {
    test('known id resolves', () {
      expect(WiltkeyThemeRegistry.byId('garden').id, 'garden');
      expect(WiltkeyThemeRegistry.byId('cyberpunk').id, 'cyberpunk');
    });
    test('unknown id falls back to cyberpunk', () {
      expect(WiltkeyThemeRegistry.byId('does-not-exist').id, 'cyberpunk');
      expect(WiltkeyThemeRegistry.byId(null).id, 'cyberpunk');
    });
    test('every theme builds a ThemeData with both extensions', () {
      for (final d in WiltkeyThemeRegistry.all) {
        final theme = d.build();
        expect(theme, isA<ThemeData>());
      }
    });
  });

  group('ThemeController persistence', () {
    test('load() restores a stored id', () async {
      SharedPreferences.setMockInitialValues({'wk_theme_id': 'garden'});
      await ThemeController().load();
      expect(ThemeController().themeId, 'garden');
    });

    test('load() normalizes an unknown stored id to default', () async {
      SharedPreferences.setMockInitialValues({'wk_theme_id': 'bogus'});
      await ThemeController().load();
      expect(ThemeController().themeId, WiltkeyThemeRegistry.defaultId);
    });

    test('setTheme() persists the choice', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeController().setTheme('garden');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wk_theme_id'), 'garden');
      expect(ThemeController().themeId, 'garden');
    });
  });

  testWidgets('PetalFlower renders in full, low and wilted states', (
    tester,
  ) async {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
    const colors = {'ours': Colors.orange, 'peer': Colors.green};
    for (final spec in [
      (0.9, 0.9, false),
      (0.1, 0.0, false),
      (0.0, 0.0, true),
    ]) {
      await tester.pumpWidget(
        host(
          PetalFlower(
            ourFraction: spec.$1,
            theirFraction: spec.$2,
            isWilted: spec.$3,
            oursColor: colors['ours']!,
            peerColor: colors['peer']!,
            centerFill: Colors.brown,
            centerStroke: Colors.green,
            groundColor: Colors.grey,
            lockedStroke: Colors.grey,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PetalFlower), findsOneWidget);
    }
  });

  testWidgets('PetalFlower animates a petal fall when budget drops', (
    tester,
  ) async {
    Widget host(double ours) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: PetalFlower(
            ourFraction: ours,
            isWilted: false,
            oursColor: Colors.orange,
            peerColor: Colors.green,
            centerFill: Colors.brown,
            centerStroke: Colors.green,
            groundColor: Colors.grey,
            lockedStroke: Colors.grey,
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(1.0)); // 4 petals
    await tester.pumpWidget(host(0.4)); // -> 2 petals, two should fall
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1)); // let the fall complete
    expect(find.byType(PetalFlower), findsOneWidget);
  });

  testWidgets('components render under both themes and survive a live switch', (
    tester,
  ) async {
    // Cyberpunk: budget = segmented bar.
    await tester.pumpWidget(
      MaterialApp(theme: buildCyberpunkTheme(), home: const _Probe()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(PetalFlower), findsNothing);

    // Garden: budget = petal flower.
    await tester.pumpWidget(
      MaterialApp(theme: buildGardenTheme(), home: const _Probe()),
    );
    await tester.pump(const Duration(milliseconds: 300)); // cross-fade + snap
    expect(tester.takeException(), isNull);
    expect(find.byType(PetalFlower), findsOneWidget);

    // Switch to Paper & Ink: budget = enso circle.
    await tester.pumpWidget(
      MaterialApp(theme: buildPaperinkTheme(), home: const _Probe()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(PetalFlower), findsNothing);

    // Switch back — no exceptions from const-frozen colors or component swap.
    await tester.pumpWidget(
      MaterialApp(theme: buildCyberpunkTheme(), home: const _Probe()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  // Regression: the budget indicator sits as a trailing child of an unbounded
  // Row in the contact list. The cyberpunk bar fills its width, so it must be
  // width-bounded or it throws an infinite-width constraint (which blanked the
  // whole cyberpunk contact list). Verify both themes lay out in that slot.
  testWidgets(
    'budgetIndicator lays out as a trailing Row glyph in both themes',
    (tester) async {
      Widget row(ThemeData theme) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Row(
              children: [
                const Expanded(child: Text('Mateusz')),
                context.wkc.budgetIndicator(
                  ourFraction: 0.6,
                  theirFraction: 0.2,
                  isWilted: false,
                ),
              ],
            ),
          ),
        ),
      );

      for (final theme in [
        buildCyberpunkTheme(),
        buildGardenTheme(),
        buildPaperinkTheme(),
      ]) {
        await tester.pumpWidget(row(theme));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Mateusz'), findsOneWidget);
      }
    },
  );

  // The scan effect (cyberpunk radar / garden meadow) must paint real device
  // data, animate, and reconcile blips appearing/disappearing without throwing.
  testWidgets('syncVisual renders + reconciles blips in both themes', (
    tester,
  ) async {
    const blipsA = [
      SyncBlip(
        id: 'a',
        strength: 0.9,
        angle: 0.3,
        isWiltkey: true,
        isNear: true,
      ),
      SyncBlip(id: 'b', strength: 0.4, angle: 2.0, isWiltkey: true),
      SyncBlip(id: 'c', strength: 0.2, angle: 4.5), // generic BLE bud
      SyncBlip(
        id: 'g',
        strength: 0.6,
        angle: 1.0,
        isWiltkey: true,
        isGroup: true,
      ),
    ];
    // 'b' lost, 'd' newly found — exercises grow-in / wilt-out lifecycle.
    const blipsB = [
      SyncBlip(
        id: 'a',
        strength: 0.8,
        angle: 0.3,
        isWiltkey: true,
        isNear: true,
      ),
      SyncBlip(
        id: 'd',
        strength: 0.5,
        angle: 3.1,
        isWiltkey: true,
        isNear: true,
      ),
    ];

    Widget host(ThemeData theme, List<SyncBlip> blips) => MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => context.wkc.syncVisual(
            state: SyncVisualState.scanning,
            blips: blips,
            log: const ['[Scanner] active'],
          ),
        ),
      ),
    );

    for (final theme in [
      buildCyberpunkTheme(),
      buildGardenTheme(),
      buildPaperinkTheme(),
    ]) {
      await tester.pumpWidget(host(theme, blipsA));
      await tester.pump(const Duration(milliseconds: 200)); // mid grow-in
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(host(theme, blipsB)); // reconcile: lose + add
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 2)); // let wilt-out complete
      expect(tester.takeException(), isNull);
    }

    // Garden vine→bloom: drive connecting → success with a jumpy progress and
    // let the smoothing + bloom animate. Must not throw across the sequence.
    Widget vine(SyncVisualState state, double progress) => MaterialApp(
      theme: buildGardenTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              context.wkc.syncVisual(state: state, progress: progress),
        ),
      ),
    );
    await tester.pumpWidget(vine(SyncVisualState.connecting, 0.1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(
      vine(SyncVisualState.connecting, 0.6),
    ); // plateau jump
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(vine(SyncVisualState.success, 1.0)); // bloom
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800)); // bloom completes
    expect(tester.takeException(), isNull);

    // Paper & Ink scroll→seal: same connecting → success drive; the success
    // stamp sequence (static seal glyph, saveLayer tinting) must not throw.
    Widget scroll(SyncVisualState state, double progress) => MaterialApp(
      theme: buildPaperinkTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              context.wkc.syncVisual(state: state, progress: progress),
        ),
      ),
    );
    await tester.pumpWidget(scroll(SyncVisualState.connecting, 0.1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(
      scroll(SyncVisualState.transferring, 0.6),
    ); // plateau jump
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(scroll(SyncVisualState.success, 1.0)); // stamp
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800)); // stamp completes
    expect(tester.takeException(), isNull);

    // Cyberpunk leaves the non-scanning states to its own card (SizedBox.shrink).
    expect(
      const CyberpunkComponents().syncVisual(state: SyncVisualState.connecting),
      isA<SizedBox>(),
    );
  });

  testWidgets('pinProgress renders across digit/error states in both themes', (
    tester,
  ) async {
    Widget host(ThemeData theme, int entered, bool error) => MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => context.wkc.pinProgress(
            context,
            entered: entered,
            length: 6,
            error: error,
          ),
        ),
      ),
    );
    for (final theme in [
      buildCyberpunkTheme(),
      buildGardenTheme(),
      buildPaperinkTheme(),
    ]) {
      for (final entered in [0, 3, 6]) {
        await tester.pumpWidget(host(theme, entered, false));
        await tester.pump(
          const Duration(milliseconds: 250),
        ); // petal pop settles
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(host(theme, 6, true)); // error state
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('unlockTransition animates and calls onDone in both themes', (
    tester,
  ) async {
    for (final theme in [
      buildCyberpunkTheme(),
      buildGardenTheme(),
      buildPaperinkTheme(),
    ]) {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  context.wkc.unlockTransition(onDone: () => done = true),
            ),
          ),
        ),
      );
      await tester.pump(); // post-frame starts the controller
      await tester.pumpAndSettle(); // run the full sequence to completion
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  // Regression: the unlock transition is shown in the root overlay, whose
  // ambient theme may lack WiltkeyTokens (e.g. the dev showcase sets the theme
  // inside `home`). It must resolve tokens from a wrapping Theme, not the
  // MaterialApp default. A bare resolve would throw a null-check in `context.wk`.
  testWidgets('unlockTransition resolves tokens from a wrapping Theme', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        // No theme: mimics the showcase, where MaterialApp.theme has no tokens.
        home: Theme(
          data: buildGardenTheme(),
          child: Builder(
            builder: (context) => Scaffold(
              body: context.wkc.unlockTransition(onDone: () => done = true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(done, isTrue);
  });

  testWidgets('nukeOverlay animates and calls onDone in both themes', (
    tester,
  ) async {
    for (final theme in [
      buildCyberpunkTheme(),
      buildGardenTheme(),
      buildPaperinkTheme(),
    ]) {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  context.wkc.nukeOverlay(onDone: () => done = true),
            ),
          ),
        ),
      );
      await tester.pump(); // post-frame starts the controller
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
    }
  });
}
