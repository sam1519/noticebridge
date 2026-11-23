import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  late Future<List<TaskItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.I.tasks();
  }

  Future<void> _reload() async {
    setState(() => _future = Api.I.tasks());
    await _future;
  }

  static const _order = [
    'Overdue',
    'High urgency (≤ 5 days)',
    'Mid urgency (6–15 days)',
    'Less urgency (> 15 days)',
    'No deadline',
    'Done',
  ];

  Map<String, List<TaskItem>> _group(List<TaskItem> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final map = <String, List<TaskItem>>{};
    for (final t in tasks) {
      String g;
      if (t.done) {
        g = 'Done';
      } else if (t.dueDate == null) {
        g = 'No deadline';
      } else {
        final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        final diff = d.difference(today).inDays;
        if (diff < 0) {
          g = 'Overdue';
        } else if (diff <= 5) {
          g = 'High urgency (≤ 5 days)';
        } else if (diff <= 15) {
          g = 'Mid urgency (6–15 days)';
        } else {
          g = 'Less urgency (> 15 days)';
        }
      }
      map.putIfAbsent(g, () => []).add(t);
    }
    return map;
  }

  Color _groupColor(String g, AppPalette p) {
    if (g == 'Overdue' || g.startsWith('High urgency')) {
      return urgencyColor('high');
    }
    if (g.startsWith('Mid urgency')) {
      return urgencyColor('medium');
    }
    if (g == 'Done' || g.startsWith('Less urgency')) {
      return urgencyColor('low');
    }
    return p.muted;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FutureBuilder<List<TaskItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: p.accent));
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(snap.error.toString(), style: TextStyle(color: p.muted)),
              const SizedBox(height: 12),
              GlowButton(label: 'Retry', icon: Icons.refresh, onPressed: _reload),
            ]),
          );
        }
        final tasks = snap.data!;
        final pending = tasks.where((t) => !t.done).length;

        if (tasks.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              const ScreenHeader(title: 'Deadlines', subtitle: 'Your action timeline'),
              const SizedBox(height: 50),
              Center(child: Icon(Icons.event_available_outlined, size: 64, color: p.muted)),
              const SizedBox(height: 14),
              Center(child: Text('No tasks yet.\nAdd a notice to get your checklist.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4))),
            ],
          );
        }

        final groups = _group(tasks);
        final widgets = <Widget>[
          ScreenHeader(title: 'Deadlines', subtitle: '$pending to do  ·  ${tasks.length - pending} done'),
        ];
        var idx = 0;
        final orderedKeys = [
          ..._order.where((k) => groups.containsKey(k)),
          ...groups.keys.where((k) => !_order.contains(k)),
        ];
        for (final g in orderedKeys) {
          final list = groups[g];
          if (list == null || list.isEmpty) continue;
          final gc = _groupColor(g, p);
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: gc, shape: BoxShape.circle, boxShadow: [BoxShadow(color: alpha(gc, 0.5), blurRadius: 8)])),
                const SizedBox(width: 10),
                Text(g.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1.2, color: gc)),
                const SizedBox(width: 8),
                Text('${list.length}', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          );
          widgets.add(
            Container(
              margin: const EdgeInsets.only(left: 5, bottom: 10),
              padding: const EdgeInsets.only(left: 18),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: alpha(gc, 0.45), width: 2))),
              child: Column(
                children: list.map((t) {
                  idx++;
                  return FadeSlide(index: idx, child: TaskTile(key: ValueKey(t.id), task: t, showNotice: true));
                }).toList(),
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: RefreshIndicator(
          onRefresh: _reload,
          color: p.accent,
          backgroundColor: p.card,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 130), children: widgets),
            ),
          ),
        );
      },
    );
  }
}

/// A single checklist row. Used on the Deadlines tab and inside a notice.
class TaskTile extends StatefulWidget {
  final TaskItem task;
  final bool showNotice;
  const TaskTile({super.key, required this.task, this.showNotice = false});

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  Future<void> _toggle(bool? v) async {
    final t = widget.task;
    final old = t.status;
    setState(() => t.status = (v ?? false) ? 'done' : 'pending');
    try {
      await Api.I.setTaskStatus(t.id, t.status);
    } catch (e) {
      if (mounted) {
        setState(() => t.status = old);
        showSnack(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final t = widget.task;
    final now = DateTime.now();
    String? dueText;
    Color dueColor = p.muted;
    if (t.dueDate != null) {
      final days = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      dueText = DateFormat('d MMM y').format(t.dueDate!);
      if (!t.done) {
        if (days < 0) {
          dueText += '  ·  overdue by ${-days} day${days == -1 ? '' : 's'}';
          dueColor = urgencyColor('high');
        } else if (days == 0) {
          dueText += '  ·  due today! (High)';
          dueColor = urgencyColor('high');
        } else if (days <= 5) {
          dueText += '  ·  $days day${days == 1 ? '' : 's'} left (High urgency)';
          dueColor = urgencyColor('high');
        } else if (days <= 15) {
          dueText += '  ·  $days days left (Mid urgency)';
          dueColor = urgencyColor('medium');
        } else {
          dueText += '  ·  $days days left (Less urgency)';
          dueColor = urgencyColor('low');
        }
      }
    }
    final green = urgencyColor('low');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => _toggle(!t.done),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.done ? green : Colors.transparent,
            border: Border.all(color: t.done ? green : p.muted, width: 2),
          ),
          child: t.done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              t.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: t.done ? p.muted : p.text,
                decoration: t.done ? TextDecoration.lineThrough : null,
              ),
            ),
            if (dueText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: alpha(dueColor, 0.14), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event, size: 13, color: dueColor),
                  const SizedBox(width: 5),
                  Flexible(child: Text(dueText, style: TextStyle(color: dueColor, fontWeight: FontWeight.w700, fontSize: 12))),
                ]),
              ),
            ],
            if (widget.showNotice && t.noticeTitle != null) ...[
              const SizedBox(height: 6),
              Text(t.noticeTitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
            ],
          ]),
        ),
      ]),
    );
  }
}
