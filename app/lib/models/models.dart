List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

int? _parseMonth(String m) {
  switch (m.toLowerCase()) {
    case 'jan': case 'january': return 1;
    case 'feb': case 'february': return 2;
    case 'mar': case 'march': return 3;
    case 'apr': case 'april': return 4;
    case 'may': return 5;
    case 'jun': case 'june': return 6;
    case 'jul': case 'july': return 7;
    case 'aug': case 'august': return 8;
    case 'sep': case 'september': return 9;
    case 'oct': case 'october': return 10;
    case 'nov': case 'november': return 11;
    case 'dec': case 'december': return 12;
    default: return null;
  }
}

DateTime? _extractDateFromText(String text) {
  if (text.isEmpty) return null;
  // Format: "December 5, 2026"
  final m1 = RegExp(
    r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (m1 != null) {
    final mon = _parseMonth(m1.group(1)!);
    final day = int.tryParse(m1.group(2)!) ?? 1;
    final year = int.tryParse(m1.group(3)!) ?? DateTime.now().year;
    if (mon != null) return DateTime(year, mon, day);
  }
  // Format: "5 December 2026"
  final m2 = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?,?\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (m2 != null) {
    final day = int.tryParse(m2.group(1)!) ?? 1;
    final mon = _parseMonth(m2.group(2)!);
    final year = int.tryParse(m2.group(3)!) ?? DateTime.now().year;
    if (mon != null) return DateTime(year, mon, day);
  }
  return null;
}

class Highlight {
  final String point;
  final String source;
  Highlight({required this.point, required this.source});
  factory Highlight.fromJson(Map<String, dynamic> j) =>
      Highlight(point: (j['point'] ?? '').toString(), source: (j['source'] ?? '').toString());
}

class Notice {
  final String id;
  final String title;
  final String category;
  final String _rawUrgency;
  final DateTime? deadline;
  final String riskIfIgnored;
  final String analyzedBy;
  final String originalText;
  final String simple;
  final String verySimple;
  final String detailed;
  final List<String> amounts;
  final List<String> documentsNeeded;
  final List<Highlight> highlights;
  final Map<String, String> translations;
  final DateTime createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.category,
    required String urgency,
    this.deadline,
    required this.riskIfIgnored,
    required this.analyzedBy,
    required this.originalText,
    required this.simple,
    required this.verySimple,
    required this.detailed,
    required this.amounts,
    required this.documentsNeeded,
    required this.highlights,
    required this.translations,
    required this.createdAt,
  }) : _rawUrgency = urgency;

  DateTime? get effectiveDeadline {
    if (deadline != null) return deadline;
    return _extractDateFromText('$simple $detailed $originalText');
  }

  /// Dynamic urgency based on deadline remaining days:
  /// - <= 5 days: high urgency (including overdue)
  /// - 6 to 15 days: medium urgency (around 15 days)
  /// - > 15 days: low (less) urgency
  String get urgency {
    final dl = effectiveDeadline;
    if (dl != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(dl.year, dl.month, dl.day);
      final diff = due.difference(today).inDays;
      if (diff <= 5) return 'high';
      if (diff <= 15) return 'medium';
      return 'low';
    }
    return _rawUrgency;
  }

  factory Notice.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] is Map) ? j['summary'] as Map : {};
    final tr = (j['translations'] is Map) ? j['translations'] as Map : {};
    final dl = j['deadline'] == null ? null : DateTime.tryParse(j['deadline'].toString())?.toLocal();
    return Notice(
      id: j['_id'].toString(),
      title: (j['title'] ?? 'Notice').toString(),
      category: (j['category'] ?? 'other').toString(),
      urgency: (j['urgency'] ?? 'low').toString(),
      deadline: dl,
      riskIfIgnored: (j['riskIfIgnored'] ?? '').toString(),
      analyzedBy: (j['analyzedBy'] ?? 'offline').toString(),
      originalText: (j['originalText'] ?? '').toString(),
      simple: (s['simple'] ?? '').toString(),
      verySimple: (s['verySimple'] ?? s['simple'] ?? '').toString(),
      detailed: (s['detailed'] ?? s['simple'] ?? '').toString(),
      amounts: _strList(j['amounts']),
      documentsNeeded: _strList(j['documentsNeeded']),
      highlights: (j['highlights'] is List)
          ? (j['highlights'] as List)
              .map((e) => Highlight.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : [],
      translations: tr.map((k, v) => MapEntry(k.toString(), v.toString())),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  /// level: simple | verySimple | detailed
  String summaryFor(String level) {
    switch (level) {
      case 'verySimple':
        return verySimple;
      case 'detailed':
        return detailed;
      default:
        return simple;
    }
  }
}

class TaskItem {
  final String id;
  final String title;
  String status; // pending | done
  final DateTime? dueDate;
  final String? noticeId;
  final String? noticeTitle;

  TaskItem({
    required this.id,
    required this.title,
    required this.status,
    this.dueDate,
    this.noticeId,
    this.noticeTitle,
  });

  bool get done => status == 'done';

  /// Dynamic urgency based on dueDate:
  /// <= 5 days: high (or overdue)
  /// 6 to 15 days: medium
  /// > 15 days: low
  String get urgency {
    if (dueDate == null) return 'low';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final diff = due.difference(today).inDays;
    if (diff <= 5) return 'high';
    if (diff <= 15) return 'medium';
    return 'low';
  }

  factory TaskItem.fromJson(Map<String, dynamic> j) {
    String? nid;
    String? ntitle;
    final n = j['noticeId'];
    if (n is Map) {
      nid = n['_id']?.toString();
      ntitle = n['title']?.toString();
    } else if (n != null) {
      nid = n.toString();
    }
    return TaskItem(
      id: j['_id'].toString(),
      title: (j['title'] ?? '').toString(),
      status: (j['status'] ?? 'pending').toString(),
      dueDate: j['dueDate'] == null ? null : DateTime.tryParse(j['dueDate'].toString())?.toLocal(),
      noticeId: nid,
      noticeTitle: ntitle,
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String preferredLang;
  final String readingLevel;
  final bool isEmailVerified;
  final String authProvider;
  final String avatarUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.preferredLang,
    required this.readingLevel,
    this.isEmailVerified = true,
    this.authProvider = 'email',
    this.avatarUrl = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        preferredLang: (j['preferredLang'] ?? 'hi').toString(),
        readingLevel: (j['readingLevel'] ?? 'simple').toString(),
        isEmailVerified: j['isEmailVerified'] ?? true,
        authProvider: (j['authProvider'] ?? 'email').toString(),
        avatarUrl: (j['avatarUrl'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'preferredLang': preferredLang,
        'readingLevel': readingLevel,
        'isEmailVerified': isEmailVerified,
        'authProvider': authProvider,
        'avatarUrl': avatarUrl,
      };
}
