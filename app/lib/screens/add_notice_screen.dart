import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AddNoticeScreen extends StatefulWidget {
  const AddNoticeScreen({super.key});

  @override
  State<AddNoticeScreen> createState() => _AddNoticeScreenState();
}

class _AddNoticeScreenState extends State<AddNoticeScreen> {
  final _text = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;
  bool _busy = false;

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _bytes = res.files.single.bytes;
        _fileName = res.files.single.name;
      });
    }
  }

  Future<void> _analyze() async {
    final trimmed = _text.text.trim();
    if (_bytes == null && trimmed.length < 5) {
      showSnack(context, 'Please enter the notice text or upload a file.');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await Api.I.createNotice(
        text: _bytes == null ? trimmed : null,
        bytes: _bytes,
        filename: _fileName,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: _busy
                  ? const _Thinking()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      children: [
                        Row(children: [
                          RoundIconButton(icon: Icons.arrow_back, tooltip: 'Back', onTap: () => Navigator.pop(context)),
                        ]),
                        const ScreenHeader(title: 'Add a notice', subtitle: 'Photo, PDF or pasted text'),
                        FadeSlide(
                          index: 0,
                          child: AppCard(
                            onTap: _pickFile,
                            padding: const EdgeInsets.all(20),
                            borderColor: alpha(p.accent, 0.6),
                            child: Row(children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(color: alpha(p.accent, 0.16), borderRadius: BorderRadius.circular(16)),
                                child: Icon(Icons.upload_file, color: p.accentText, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Upload a file', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const SizedBox(height: 3),
                                  Text('JPG, PNG, PDF or TXT', style: TextStyle(color: p.muted, fontSize: 13)),
                                ]),
                              ),
                              Icon(Icons.chevron_right, color: p.muted),
                            ]),
                          ),
                        ),
                        if (_fileName != null)
                          AppCard(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Icon(Icons.attach_file, color: p.accentText),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_fileName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _bytes = null;
                                  _fileName = null;
                                }),
                              ),
                            ]),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Row(children: [
                            Expanded(child: Divider(color: p.line)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR PASTE THE TEXT', style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                            ),
                            Expanded(child: Divider(color: p.line)),
                          ]),
                        ),
                        FadeSlide(
                          index: 1,
                          child: TextField(
                            controller: _text,
                            minLines: 8,
                            maxLines: 14,
                            enabled: _bytes == null,
                            decoration: const InputDecoration(
                              hintText: 'Paste the full text of the notice here...',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        GlowButton(label: 'Explain this notice', icon: Icons.auto_awesome, expand: true, onPressed: _analyze),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the notice is being analyzed: bridge + rotating messages.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> {
  static const _messages = [
    'Reading your notice...',
    'Finding deadlines and amounts...',
    'Checking how urgent it is...',
    'Writing it in simple words...',
    'Almost there...',
  ];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const BridgeLogo(size: 150),
        const SizedBox(height: 26),
        SizedBox(width: 200, child: LinearProgressIndicator(color: p.accent, backgroundColor: p.line, minHeight: 4, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(_messages[_i], key: ValueKey(_i), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text('(photos can take up to a minute)', style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}
