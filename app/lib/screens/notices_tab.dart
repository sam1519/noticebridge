import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'notice_detail_screen.dart';

class NoticesTab extends StatefulWidget {
  final VoidCallback onChanged;
  final VoidCallback onGoToTasks;
  const NoticesTab({super.key, required this.onChanged, required this.onGoToTasks});

  @override
  State<NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends State<NoticesTab> {
  late Future<({List<Notice> notices, List<TaskItem> tasks})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Notice> notices, List<TaskItem> tasks})> _load() async {
    final n = await Api.I.notices();
    final t = await Api.I.tasks();
    return (notices: n, tasks: t);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final name = (context.watch<AuthProvider>().user?.name ?? '').split(' ').first;

    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: p.accent));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off, size: 52, color: p.muted),
                const SizedBox(height: 10),
                Text(snap.error.toString(), textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                const SizedBox(height: 16),
                GlowButton(label: 'Retry', icon: Icons.refresh, onPressed: _reload),
              ]),
            ),
          );
        }

        final data = snap.data!;
        final notices = data.notices;
        final now = DateTime.now();
        final dueSoon = data.tasks.where((t) {
          if (t.done || t.dueDate == null) return false;
          final days = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          return days <= 15;
        }).length;
        final high = notices.where((n) => n.urgency == 'high').length;

        return RefreshIndicator(
          onRefresh: _reload,
          color: p.accent,
          backgroundColor: p.card,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 190),
            children: [
              ScreenHeader(
                subtitle: DateFormat('EEEE, d MMMM').format(now),
                title: name.isEmpty ? 'My notices' : 'Hello, $name',
              ),
              FadeSlide(
                index: 0,
                child: Row(children: [
                  Expanded(
                    child: StatTile(value: '${notices.length}', label: 'Notices', icon: Icons.description_outlined, color: p.accentText),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(value: '$high', label: 'High urgency', icon: Icons.local_fire_department_outlined, color: urgencyColor('high')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      value: '$dueSoon',
                      label: 'Due soon',
                      icon: Icons.alarm,
                      color: urgencyColor('medium'),
                      onTap: widget.onGoToTasks,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text('YOUR NOTICES',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: p.muted)),
              ),
              if (notices.isEmpty)
                const _EmptyState()
              else
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 760 ? 2 : 1;
                  final w = (c.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    children: List.generate(notices.length, (i) {
                      final n = notices[i];
                      return SizedBox(
                        width: w,
                        child: _NoticeCard(
                          index: i,
                          notice: n,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => NoticeDetailScreen(noticeId: n.id)),
                            );
                            widget.onChanged();
                          },
                        ),
                      );
                    }),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(children: [
        const BridgeLogo(size: 110),
        const SizedBox(height: 18),
        const Text('No notices yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Tap "Add notice" to paste text or upload\na photo / PDF. We will explain it in simple words.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, height: 1.4),
        ),
      ]),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;
  final int index;
  const _NoticeCard({required this.notice, required this.onTap, required this.index});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final uc = urgencyColor(notice.urgency);
    return FadeSlide(
      index: index + 1,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: alpha(uc, 0.15), borderRadius: BorderRadius.circular(15)),
            child: Icon(categoryIcon(notice.category), color: uc, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notice.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(notice.verySimple, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, height: 1.35)),
              const SizedBox(height: 10),
              Row(children: [
                UrgencyBadge(notice.urgency),
                const Spacer(),
                Text(DateFormat('d MMM y').format(notice.createdAt.toLocal()), style: TextStyle(fontSize: 12, color: p.muted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
