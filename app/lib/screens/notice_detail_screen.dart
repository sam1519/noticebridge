import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/auth_provider.dart';
import '../services/speech.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'tasks_tab.dart';

class NoticeDetailScreen extends StatefulWidget {
  final String noticeId;
  const NoticeDetailScreen({super.key, required this.noticeId});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late Future<({Notice notice, List<TaskItem> tasks})> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.I.notice(widget.noticeId);
  }

  @override
  void dispose() {
    Speech.I.stop();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this notice?'),
        content: const Text('Its tasks will be deleted too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.I.deleteNotice(widget.noticeId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
  }

  Future<void> _share() async {
    try {
      final url = await Api.I.share(widget.noticeId);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Share with family'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Anyone with this link can read the simplified summary and to-do list:'),
            const SizedBox(height: 8),
            SelectableText(url, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Note: if the link starts with 127.0.0.1 or localhost, it only opens on this laptop. '
              'Deploy the backend or use your laptop\'s Wi-Fi IP so others can open it.',
              style: TextStyle(fontSize: 12),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                showSnack(context, 'Link copied');
              },
              child: const Text('Copy link'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
  }

  Widget _frame(Widget child) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _frame(Center(child: CircularProgressIndicator(color: p.accent)));
        }
        if (snap.hasError) {
          return _frame(Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RoundIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              ),
            ),
            Expanded(child: Center(child: Text(snap.error.toString(), style: TextStyle(color: p.muted)))),
          ]));
        }
        final notice = snap.data!.notice;
        final tasks = snap.data!.tasks;

        return DefaultTabController(
          length: 4,
          child: _frame(
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    RoundIconButton(icon: Icons.arrow_back, tooltip: 'Back', onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(notice.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(icon: Icons.share_outlined, tooltip: 'Share with family', onTap: _share),
                    const SizedBox(width: 8),
                    RoundIconButton(icon: Icons.delete_outline, tooltip: 'Delete', onTap: _delete),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _Hero(notice: notice, tasks: tasks),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: p.line),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: alpha(p.accent, 0.20),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: alpha(p.accent, 0.65)),
                    ),
                    labelColor: p.text,
                    unselectedLabelColor: p.muted,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5),
                    splashBorderRadius: BorderRadius.circular(18),
                    tabs: const [
                      Tab(height: 54, icon: Icon(Icons.notes, size: 20), text: 'Summary'),
                      Tab(height: 54, icon: Icon(Icons.translate, size: 20), text: 'Translate'),
                      Tab(height: 54, icon: Icon(Icons.checklist, size: 20), text: 'Tasks'),
                      Tab(height: 54, icon: Icon(Icons.mail_outline, size: 20), text: 'Reply'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _SummaryTab(notice: notice),
                    _TranslateTab(notice: notice),
                    _NoticeTasksTab(tasks: tasks),
                    _ReplyTab(notice: notice),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------------- hero
class _Hero extends StatelessWidget {
  final Notice notice;
  final List<TaskItem> tasks;
  const _Hero({required this.notice, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // Earliest upcoming task dueDate if available, or notice.effectiveDeadline
    final pendingDeadline = tasks
        .where((t) => t.dueDate != null && !t.done)
        .map((t) => t.dueDate!)
        .fold<DateTime?>(null, (min, d) => min == null || d.isBefore(min) ? d : min);
    final anyTaskDeadline = tasks
        .where((t) => t.dueDate != null)
        .map((t) => t.dueDate!)
        .fold<DateTime?>(null, (min, d) => min == null || d.isBefore(min) ? d : min);
    final dl = pendingDeadline ?? anyTaskDeadline ?? notice.effectiveDeadline;

    String currentUrgency = notice.urgency;
    int? daysLeft;
    if (dl != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(dl.year, dl.month, dl.day);
      daysLeft = due.difference(today).inDays;
      if (daysLeft <= 5) {
        currentUrgency = 'high';
      } else if (daysLeft <= 15) {
        currentUrgency = 'medium';
      } else {
        currentUrgency = 'low';
      }
    }

    final uc = urgencyColor(currentUrgency);
    final String line;
    if (currentUrgency == 'high') {
      line = (daysLeft != null && daysLeft < 0)
          ? 'High urgency · Overdue by ${-daysLeft} day${daysLeft == -1 ? '' : 's'}'
          : 'High urgency · Action required within 5 days${daysLeft != null ? ' ($daysLeft d left)' : ''}';
    } else if (currentUrgency == 'medium') {
      line = 'Mid urgency · Action due within 15 days${daysLeft != null ? ' ($daysLeft d left)' : ''}';
    } else {
      line = 'Less urgency · Beyond 15 days${daysLeft != null ? ' ($daysLeft d left)' : ''}';
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: alpha(uc, 0.5),
      child: Row(children: [
        UrgencyRing(urgency: currentUrgency, size: 92),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(categoryIcon(notice.category), size: 15, color: p.accentText),
              const SizedBox(width: 6),
              Text('${notice.category.toUpperCase()} NOTICE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: p.muted)),
            ]),
            const SizedBox(height: 6),
            Text(line, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: uc, height: 1.2)),
            const SizedBox(height: 6),
            Text(
              '${tasks.length} task${tasks.length == 1 ? '' : 's'}  ·  added ${DateFormat('d MMM y').format(notice.createdAt.toLocal())}',
              style: TextStyle(fontSize: 12.5, color: p.muted),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Summary
class _SummaryTab extends StatefulWidget {
  final Notice notice;
  const _SummaryTab({required this.notice});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  String? _level;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final n = widget.notice;
    final level = _level ?? context.read<AuthProvider>().user?.readingLevel ?? 'simple';
    final uc = urgencyColor(n.urgency);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        PillSelector<String>(
          options: const [
            MapEntry('verySimple', 'Very simple'),
            MapEntry('simple', 'Simple'),
            MapEntry('detailed', 'Detailed'),
          ],
          selected: level,
          onChanged: (v) => setState(() => _level = v),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'What this notice says',
          icon: Icons.lightbulb_outline,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                n.summaryFor(level),
                key: ValueKey(level),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Speech.I.speak(n.summaryFor(level), 'en'),
              icon: Icon(Icons.volume_up, color: p.accentText),
              label: Text('Read aloud', style: TextStyle(color: p.accentText, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        if (n.riskIfIgnored.isNotEmpty)
          StripeCard(
            color: uc,
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: uc),
                const SizedBox(width: 8),
                Text('WHAT IF I IGNORE THIS?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: uc)),
              ]),
              const SizedBox(height: 8),
              Text(n.riskIfIgnored, style: const TextStyle(height: 1.45)),
            ]),
          ),
        if (n.amounts.isNotEmpty)
          SectionCard(
            title: 'Amounts mentioned',
            icon: Icons.currency_rupee,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: n.amounts
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: alpha(p.accent, 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: alpha(p.accent, 0.5)),
                        ),
                        child: Text(a, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ))
                  .toList(),
            ),
          ),
        if (n.documentsNeeded.isNotEmpty)
          SectionCard(
            title: 'Documents / items needed',
            icon: Icons.folder_open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: n.documentsNeeded
                  .map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.check_circle_outline, size: 18, color: p.accentText),
                          const SizedBox(width: 10),
                          Expanded(child: Text(d, style: const TextStyle(height: 1.35))),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        if (n.highlights.isNotEmpty)
          SectionCard(
            title: 'Where did this come from?',
            icon: Icons.fact_check_outlined,
            child: Column(
              children: n.highlights
                  .map((h) => ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        iconColor: p.accentText,
                        collapsedIconColor: p.muted,
                        title: Text(h.point, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                color: alpha(p.accent, 0.12),
                                child: IntrinsicHeight(
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                    Container(width: 4, color: p.accent),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text('"${h.source}"', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4)),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: p.accentText,
            collapsedIconColor: p.muted,
            leading: Icon(Icons.article_outlined, color: p.muted),
            title: const Text('Original notice text', style: TextStyle(fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [SelectableText(n.originalText, style: const TextStyle(height: 1.45))],
          ),
        ),
        if (n.analyzedBy == 'offline')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Basic offline analysis was used. Add an AI key in the backend .env file for richer summaries, translation and reply drafts.',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------- Translate
class _TranslateTab extends StatefulWidget {
  final Notice notice;
  const _TranslateTab({required this.notice});

  @override
  State<_TranslateTab> createState() => _TranslateTabState();
}

class _TranslateTabState extends State<_TranslateTab> {
  String? _lang;
  String? _text;
  bool _busy = false;

  Future<void> _translate() async {
    final lang = _lang ?? context.read<AuthProvider>().user?.preferredLang ?? 'hi';
    setState(() {
      _busy = true;
      _text = null;
    });
    try {
      final t = await Api.I.translate(widget.notice.id, lang);
      if (mounted) setState(() => _text = t);
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final lang = _lang ?? context.read<AuthProvider>().user?.preferredLang ?? 'hi';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('TRANSLATE INTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: p.muted)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kLanguages
              .map((l) => ChoicePill(
                    label: l['name']!,
                    selected: lang == l['code'],
                    onTap: () => setState(() {
                      _lang = l['code'];
                      _text = null;
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        GlowButton(
          label: _busy ? 'Translating...' : 'Translate summary',
          icon: Icons.translate,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : _translate,
        ),
        const SizedBox(height: 18),
        if (_text != null)
          FadeSlide(
            child: SectionCard(
              title: languageName(lang),
              icon: Icons.language,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(_text!, style: const TextStyle(fontSize: 17, height: 1.6)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                    onPressed: () => Speech.I.speak(_text!, lang),
                    icon: Icon(Icons.volume_up, color: p.accentText),
                    label: Text('Read aloud', style: TextStyle(color: p.accentText, fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _text!));
                      showSnack(context, 'Copied');
                    },
                    icon: Icon(Icons.copy, color: p.accentText),
                    label: Text('Copy', style: TextStyle(color: p.accentText, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Tasks
class _NoticeTasksTab extends StatelessWidget {
  final List<TaskItem> tasks;
  const _NoticeTasksTab({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (tasks.isEmpty) {
      return Center(child: Text('No specific tasks found in this notice.', style: TextStyle(color: p.muted)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('TAP TO MARK AS DONE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: p.muted)),
        ),
        ...List.generate(tasks.length, (i) => FadeSlide(index: i, child: TaskTile(task: tasks[i]))),
      ],
    );
  }
}

// ------------------------------------------------------------------ Reply
class _ReplyTab extends StatefulWidget {
  final Notice notice;
  const _ReplyTab({required this.notice});

  @override
  State<_ReplyTab> createState() => _ReplyTabState();
}

class _ReplyTabState extends State<_ReplyTab> {
  final _goal = TextEditingController();
  String? _draft;
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final d = await Api.I.replyDraft(widget.notice.id, _goal.text.trim());
      if (mounted) setState(() => _draft = d);
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Text(
          'Need to respond to this notice? Tell us what you want to say and we will draft a polite reply.',
          style: TextStyle(color: p.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goal,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'e.g. Ask for 15 more days to pay / Say I already paid on 5 Nov',
          ),
        ),
        const SizedBox(height: 14),
        GlowButton(
          label: _busy ? 'Writing...' : 'Draft reply',
          icon: Icons.edit_note,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : _generate,
        ),
        const SizedBox(height: 16),
        if (_draft != null)
          FadeSlide(
            child: SectionCard(
              title: 'Your draft',
              icon: Icons.mail_outline,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(_draft!, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _draft!));
                    showSnack(context, 'Copied');
                  },
                  icon: Icon(Icons.copy, color: p.accentText),
                  label: Text('Copy', style: TextStyle(color: p.accentText, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
