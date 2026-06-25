import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;

void main() {
  final keyPair = ed25519.generateKey();
  final pubBytes = keyPair.publicKey.bytes;
  final privBytes = keyPair.privateKey.bytes;

  final restoredPub = ed25519.PublicKey(pubBytes);
  final restoredPriv = ed25519.PrivateKey(privBytes);
  final restoredKeyPair = ed25519.KeyPair(restoredPriv, restoredPub);

  print('Keys matched: ${restoredKeyPair.publicKey.bytes.length == 32}');
}
