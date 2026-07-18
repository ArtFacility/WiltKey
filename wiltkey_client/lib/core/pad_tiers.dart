import 'entitlements/entitlement_service.dart';

/// The OTP pad sizes offered at 1:1 BLE pairing.
///
/// ## Why this table can grow safely
/// The pairing handshake puts the **byte count** on the wire (`buffer_bytes`),
/// never this index — the index exists only to drive the local slider. So a peer
/// on an older build that has never heard of a 200 MB tier still allocates
/// exactly the size it is told. (`ble_pairing_manager` does reverse-map a received
/// size back to an index to sync its slider display, but guards on `indexOf == -1`,
/// so an unknown size just leaves the display alone.) **Never** change this to
/// send an index.
///
/// ## Who needs the unlock
/// Only the **initiator** picks a size; the responder honours whatever arrives.
/// So a large pad requires `largerPads` on ONE side — pairing a Plus user with a
/// free user still gets both a 200 MB pad.
class WkPadTiers {
  WkPadTiers._();

  /// Pad sizes in bytes, ascending. Indices 0..[freeMaxIndex] are free for
  /// everyone; the rest need the larger-pads unlock.
  static const List<int> values = [
    100000, // 0: 100 KB
    500000, // 1: 500 KB
    1000000, // 2: 1 MB
    2000000, // 3: 2 MB
    5000000, // 4: 5 MB
    10000000, // 5: 10 MB
    20000000, // 6: 20 MB  ← last free tier
    40000000, // 7: 40 MB
    60000000, // 8: 60 MB
    80000000, // 9: 80 MB
    100000000, // 10: 100 MB
    150000000, // 11: 150 MB
    200000000, // 12: 200 MB
  ];

  /// Display labels, index-aligned with [values].
  static const List<String> labels = [
    '100 KB',
    '500 KB',
    '1 MB',
    '2 MB',
    '5 MB',
    '10 MB',
    '20 MB',
    '40 MB',
    '60 MB',
    '80 MB',
    '100 MB',
    '150 MB',
    '200 MB',
  ];

  /// Highest tier available without the unlock (20 MB).
  static const int freeMaxIndex = 6;

  /// Highest tier that exists at all (200 MB).
  static int get maxIndex => values.length - 1;

  /// Boot default — 10 MB, matching the pre-tier default.
  static const int defaultIndex = 5;

  /// True once the larger tiers are selectable (FOSS: always; Play: owns the SKU).
  static bool get largerUnlocked =>
      EntitlementService.instance.largerPadsUnlocked;

  /// The highest index the local user may pick right now.
  static int get selectableMaxIndex => largerUnlocked ? maxIndex : freeMaxIndex;

  /// True if [index] needs the larger-pads unlock.
  static bool isPremiumIndex(int index) => index > freeMaxIndex;

  /// Clamp a desired index to what the user may actually select.
  static int clampToAllowed(int index) =>
      index.clamp(0, selectableMaxIndex).toInt();

  static int bytesAt(int index) => values[index.clamp(0, maxIndex).toInt()];

  static String labelAt(int index) => labels[index.clamp(0, maxIndex).toInt()];
}
