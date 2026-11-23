import 'dart:math' as math;

int _damerauLevenshtein(String a, String b) {
  final al = a.length, bl = b.length;
  final d = List.generate(al + 1, (_) => List.filled(bl + 1, 0));
  for (int i = 0; i <= al; i++) {
    d[i][0] = i;
  }
  for (int j = 0; j <= bl; j++) {
    d[0][j] = j;
  }
  for (int i = 1; i <= al; i++) {
    for (int j = 1; j <= bl; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      d[i][j] = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost,
      ].reduce(math.min);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d[i][j] = math.min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[al][bl];
}

const List<String> kPopularEmailDomains = [
  'gmail.com',
  'yahoo.com',
  'outlook.com',
  'hotmail.com',
  'icloud.com',
  'live.com',
  'proton.me',
  'zoho.com',
];

const Set<String> kProviderNames = {
  'gmail', 'yahoo', 'outlook', 'hotmail', 'icloud', 'proton', 'zoho', 'live', 'msn', 'aol'
};

const Set<String> kValidTlds = {
  'com', 'org', 'net', 'edu', 'gov', 'mil', 'int', 'info', 'biz',
  'io', 'co', 'in', 'ai', 'app', 'dev', 'me', 'tech', 'cloud',
  'online', 'site', 'store', 'global', 'uk', 'us', 'ca', 'au',
  'de', 'fr', 'jp', 'cn', 'br', 'za', 'eu', 'ac', 'ch', 'nl', 'se', 'no',
  'es', 'it', 'ru', 'mx', 'sg', 'nz', 'ie', 'tv', 'cc', 'xyz', 'pro', 'name'
};

const Map<String, String> kDirectTypoDomains = {
  'com.gmail': 'gmail.com',
  'in.gmail': 'gmail.com',
  'co.gmail': 'gmail.com',
  'org.gmail': 'gmail.com',
  'net.gmail': 'gmail.com',
  'com.yahoo': 'yahoo.com',
  'com.outlook': 'outlook.com',
  'gmali.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gmial.com': 'gmail.com',
  'gmaill.com': 'gmail.com',
  'gmall.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gmaik.com': 'gmail.com',
  'gmeil.com': 'gmail.com',
  'gmaul.com': 'gmail.com',
  'mil.com': 'gmail.com',
  'gila.vom': 'gmail.com',
  'gila.com': 'gmail.com',
  'gmail.vom': 'gmail.com',
  'gmali.co': 'gmail.com',
  'gamil.co': 'gmail.com',
  'yaho.com': 'yahoo.com',
  'yahooo.com': 'yahoo.com',
  'hotmial.com': 'hotmail.com',
  'hotamil.com': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outloo.com': 'outlook.com',
  'iclud.com': 'icloud.com',
};

/// Evaluates if an email has a typo domain (like com.gmail, gmali.com, mil.com, gila.vom).
/// Returns the suggested corrected email, or null if the email domain is valid.
String? checkEmailTypo(String email) {
  if (email.trim().isEmpty) return null;
  final clean = email.trim().toLowerCase();
  final parts = clean.split('@');
  if (parts.length != 2) return null;
  final prefix = parts[0];
  final domain = parts[1];
  if (domain.isEmpty) return null;

  // Exact known popular domains are completely valid
  if (kPopularEmailDomains.contains(domain)) return null;

  // 1. Missing dot (e.g. jhon@gmail)
  if (!domain.contains('.')) {
    if (kProviderNames.contains(domain)) {
      return '$prefix@$domain.com';
    }
    return '$prefix@$domain.com';
  }

  // 2. Direct lookup for known typos (e.g. com.gmail, gmali.com, mil.com)
  if (kDirectTypoDomains.containsKey(domain)) {
    return '$prefix@${kDirectTypoDomains[domain]}';
  }

  final domainParts = domain.split('.');
  final sub = domainParts[0];
  final tld = domainParts.last;

  // 3. Provider used as TLD (e.g. com.gmail, in.gmail, xyz.gmail)
  if (kProviderNames.contains(tld)) {
    if (sub == 'com' || sub == 'co' || sub == 'in' || sub == 'org' || sub == 'net') {
      return '$prefix@$tld.${sub == "co" ? "com" : sub}';
    }
    return '$prefix@$tld.com';
  }

  // 4. Any domain containing gmail/gmali/gami/gmai variations
  if (domain.contains('gmail') ||
      domain.contains('gmali') ||
      domain.contains('gamil') ||
      domain.contains('gmai') ||
      domain.contains('gila')) {
    return '$prefix@gmail.com';
  }

  // 5. Invalid or unrecognized top-level domain extension (e.g. .vom, .con, etc.)
  if (!kValidTlds.contains(tld)) {
    return '$prefix@${domainParts.sublist(0, domainParts.length - 1).join('.')}.com';
  }

  // 6. Fuzzy distance matching for other major providers
  for (final pop in kPopularEmailDomains) {
    if (_damerauLevenshtein(domain, pop) <= 2) {
      return '$prefix@$pop';
    }
  }

  return null;
}
