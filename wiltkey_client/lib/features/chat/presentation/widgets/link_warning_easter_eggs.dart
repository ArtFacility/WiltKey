/// Easter egg matcher for external link warnings.
///
/// If the application UI is set to English, matching domains or known URLs
/// return a cheeky, contextual warning message. For non-English locales,
/// returns `null` to gracefully fall back to the localized standard warning.
String? getLinkEasterEgg(Uri uri, String languageCode) {
  if (languageCode != 'en') return null;

  final host = uri.host.toLowerCase();
  final path = uri.path;
  final query = uri.queryParameters;
  final fullUrl = uri.toString().toLowerCase();

  // 1. Rickroll Detection (YouTube / youtu.be video IDs)
  final isYouTube = host.contains('youtube.com') ||
      host == 'youtu.be' ||
      host.endsWith('.youtube.com');
  if (isYouTube) {
    final videoId = query['v'] ?? (host == 'youtu.be' ? path.replaceAll('/', '') : '');
    const rickrollIds = {
      'dQw4w9WgXcQ',
      'oHg5SJYRHA0',
      'cvh0nX08nRw',
      '2ocykBzWDiM',
      'xvFZjo5PgG0',
      'iik254BiWBk',
    };
    if (rickrollIds.any((id) => fullUrl.contains(id.toLowerCase()) || videoId == id)) {
      return "Sorry boss, they're trying to rickroll you.";
    }
  }

  // 2. ArtFacility Domains
  if (host == 'artfacility.xyz' || host.endsWith('.artfacility.xyz')) {
    return 'Looking for other awesome open source software?';
  }
  if (host.contains('artfacility')) {
    return 'I think you got the link wrong boss.';
  }

  // 3. WiltKey Domains
  if (host == 'wiltkey.org' || host.endsWith('.wiltkey.org')) {
    return "Visiting home base? Don't forget to star the repo.";
  }

  // 4. xHamster & Adult Sites
  if (host.contains('xhamster')) {
    return 'You know there are no hamsters on this one?';
  }
  if (host.contains('pornhub.com') ||
      host.contains('xvideos.com') ||
      host.contains('xnxx.com') ||
      host.contains('redtube.com')) {
    return 'You know everyone around you can see your screen, right?';
  }

  // 5. Facebook / Meta
  if (host == 'facebook.com' ||
      host.endsWith('.facebook.com') ||
      host == 'fb.com' ||
      host.endsWith('.fb.com')) {
    return "Warning: you're about to open the dumbest side of the internet.";
  }

  // 6. Link Shorteners
  const linkShorteners = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'is.gd',
    'buff.ly',
    'ow.ly',
    'cutt.ly',
    'rb.gy',
    'shorturl.at',
    'tiny.cc',
    'rotf.lol',
  };
  if (linkShorteners.contains(host) || linkShorteners.any((s) => host.endsWith('.$s'))) {
    return 'Living the dangerous life I see...';
  }

  // 7. Twitter / X
  if (host == 'x.com' ||
      host.endsWith('.x.com') ||
      host == 'twitter.com' ||
      host.endsWith('.twitter.com')) {
    return 'Warning: Entering the bird site (or whatever it is called this week).';
  }

  // 8. TikTok
  if (host.contains('tiktok.com')) {
    return 'Brain rot incoming in 3... 2... 1...';
  }

  // 9. Reddit
  if (host.contains('reddit.com')) {
    return 'Leaving privacy behind to read arguments from 8 years ago.';
  }

  // 10. Wikipedia
  if (host.contains('wikipedia.org')) {
    return 'Say goodbye to the next 3 hours down a rabbit hole.';
  }

  // 11. GitHub / GitLab
  if (host.contains('github.com') || host.contains('gitlab.com')) {
    return 'Entering code territory. Bring coffee.';
  }

  // 12. StackOverflow
  if (host.contains('stackoverflow.com')) {
    return 'Marked as duplicate of a question from 2011.';
  }

  // 13. 4chan
  if (host.contains('4chan.org')) {
    return 'Abandon all hope, ye who enter here.';
  }

  // 14. Google
  if (host == 'google.com' || host.endsWith('.google.com')) {
    return 'They already know everything, but sure, go ahead.';
  }

  // 15. Amazon
  if (host == 'amazon.com' || host.endsWith('.amazon.com')) {
    return 'Your wallet is currently begging for mercy.';
  }

  // 16. Localhost
  if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
    return 'There is no place like 127.0.0.1.';
  }

  // 17. Tor Onion Sites
  if (host.endsWith('.onion')) {
    return "Tor browser required. You're entering the dark alleys.";
  }

  return null;
}
