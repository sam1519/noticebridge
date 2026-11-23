import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/auth_provider.dart';
import '../services/email_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

export '../services/email_utils.dart' show checkEmailTypo;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  bool _rememberMe = true;
  String? _emailSuggestion;

  @override
  void initState() {
    super.initState();
    _email.addListener(() {
      final suggestion = checkEmailTypo(_email.text);
      if (suggestion != _emailSuggestion) {
        setState(() => _emailSuggestion = suggestion);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _applyDomain(String domain) {
    final current = _email.text.trim();
    final atIndex = current.indexOf('@');
    final prefix = atIndex >= 0 ? current.substring(0, atIndex) : current;
    if (prefix.isNotEmpty) {
      _email.text = '$prefix@$domain';
    } else {
      _email.text = '@$domain';
    }
    setState(() => _emailSuggestion = null);
  }

  Widget _domainChip(String domain, AppPalette p) {
    return InkWell(
      onTap: () => _applyDomain(domain),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: alpha(p.accent, 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: alpha(p.accent, 0.25)),
        ),
        child: Text(
          '@$domain',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.accentText),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    try {
      if (_register) {
        await auth.register(_name.text.trim(), _email.text.trim(), _password.text);
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _email.text.trim());
    final newPassCtrl = TextEditingController();
    final p = context.pal;

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool busyReset = false;
        bool hideNewPass = true;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: p.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: p.accentText),
                const SizedBox(width: 10),
                const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter your registered email and a new secure password.',
                    style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Official Email', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: hideNewPass,
                  decoration: InputDecoration(
                    labelText: 'New Password (8+ chars, A-Z, 0-9, symbol)',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(hideNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setLocal(() => hideNewPass = !hideNewPass),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: busyReset
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final pass = newPassCtrl.text;
                        if (email.isEmpty || pass.length < 8) {
                          showSnack(ctx, 'Please enter a valid email and 8+ character password');
                          return;
                        }
                        setLocal(() => busyReset = true);
                        try {
                          await context.read<AuthProvider>().resetPassword(email, pass);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) showSnack(ctx, e.toString());
                        } finally {
                          if (ctx.mounted) setLocal(() => busyReset = false);
                        }
                      },
                child: busyReset
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Reset & Save'),
              ),
            ],
          ),
        );
      },
    );

    if (success == true && mounted) {
      _email.text = emailCtrl.text.trim();
      _password.text = newPassCtrl.text;
      showSnack(context, 'Password updated successfully! You can now log in.');
    }
  }

  void _showTermsDialog() {
    final p = context.pal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: p.accentText),
            const SizedBox(width: 10),
            const Text('Security & Terms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NoticeBridge Official Portal Security', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '• All notice uploads, summaries, and user credentials are encrypted with 256-bit SSL transport.\n'
                '• Your email is kept confidential and strictly used for official deadline notifications.\n'
                '• AI notice processing uses privacy-preserving sandboxed models without public retention.\n'
                '• You retain full rights to delete your notices, tasks, and account data at any time.',
                style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
        ],
      ),
    );
  }

  Future<void> _serverDialog() async {
    final c = TextEditingController(text: Api.I.baseUrl);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: c, decoration: const InputDecoration(labelText: 'Backend URL')),
            const SizedBox(height: 10),
            const Text(
              'Android emulator: http://10.0.2.2:5000\n'
              'Chrome / Windows: http://127.0.0.1:5000\n'
              'Real phone: http://<your-laptop-IP>:5000',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      await Api.I.setBaseUrl(c.text);
      if (mounted) showSnack(context, 'Server set to ${Api.I.baseUrl}');
    }
  }

  Widget _reqChip(String label, bool met, AppPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met ? Colors.green.withAlpha(35) : alpha(p.line, 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: met ? Colors.green.withAlpha(120) : alpha(p.line, 0.7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: met ? Colors.green : p.muted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: met ? (p.dark ? Colors.greenAccent : const Color(0xFF1B5E20)) : p.muted,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Official Portal Brand Header
                      const Center(child: BridgeLogo(size: 120)),
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: alpha(p.accent, 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: alpha(p.accent, 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: p.accentText),
                              const SizedBox(width: 6),
                              Text(
                                'OFFICIAL CITIZEN & STUDENT PORTAL',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: p.accentText),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeSlide(
                        index: 0,
                        child: Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1, color: p.text),
                              children: [
                                const TextSpan(text: 'Notice'),
                                TextSpan(text: 'Bridge', style: TextStyle(color: p.accentText)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeSlide(
                        index: 1,
                        child: Text(
                          'Understand any notice. Know what to do. Never miss a deadline.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted, height: 1.4, fontSize: 13.5),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Main Login / Register Card
                      FadeSlide(
                        index: 2,
                        child: AppCard(
                          padding: const EdgeInsets.all(22),
                          radius: 26,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Segmented Switcher (Sign In vs Create Account)
                              Container(
                                decoration: BoxDecoration(
                                  color: alpha(p.text, 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: alpha(p.line, 0.6)),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _register = false;
                                          _form.currentState?.reset();
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                          decoration: BoxDecoration(
                                            color: !_register ? p.card : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: !_register
                                                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontWeight: !_register ? FontWeight.w800 : FontWeight.w600,
                                              color: !_register ? p.text : p.muted,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _register = true;
                                          _form.currentState?.reset();
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                          decoration: BoxDecoration(
                                            color: _register ? p.card : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: _register
                                                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontWeight: _register ? FontWeight.w800 : FontWeight.w600,
                                              color: _register ? p.text : p.muted,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Name (Registration only)
                              if (_register) ...[
                                TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    hintText: 'Letters only (e.g. Ram Kumar)',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  validator: (v) {
                                    if (!_register) return null;
                                    final val = v?.trim() ?? '';
                                    if (val.isEmpty) return 'Enter your full name';
                                    if (val.length < 3) return 'Name must be at least 3 characters';
                                    if (val.length > 50) return 'Name must be at most 50 characters';
                                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) {
                                      return 'Name must contain only letters and spaces';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Email Field with Real-Time Typo Detection
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Official Email',
                                  hintText: 'e.g. ram@gmail.com',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: (v) {
                                  final val = v?.trim() ?? '';
                                  if (val.isEmpty) return 'Enter your official email address';
                                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                  if (!emailRegex.hasMatch(val)) {
                                    return 'Enter a valid official email (e.g. name@example.com)';
                                  }
                                  final typo = checkEmailTypo(val);
                                  if (typo != null) {
                                    return 'Invalid email domain. Did you mean $typo?';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 6),

                              // Quick Domain Selector Chips
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _domainChip('gmail.com', p),
                                  _domainChip('outlook.com', p),
                                  _domainChip('yahoo.com', p),
                                  _domainChip('icloud.com', p),
                                ],
                              ),

                              // Interactive Typo Correction Suggestion Chip
                              if (_emailSuggestion != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.auto_fix_high, size: 16, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Email Domain Typo Detected',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                            ),
                                            Text(
                                              'Did you mean: $_emailSuggestion?',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          _email.text = _emailSuggestion!;
                                          setState(() => _emailSuggestion = null);
                                        },
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text('Auto-Fix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Password Field
                              TextFormField(
                                controller: _password,
                                obscureText: _hide,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _hide = !_hide),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_register) setState(() {});
                                },
                                validator: (v) {
                                  final val = v ?? '';
                                  if (val.isEmpty) return 'Enter your password';
                                  if (!_register) return null;
                                  if (val.length < 8) return 'Password must be at least 8 characters';
                                  if (!RegExp(r'[A-Z]').hasMatch(val)) return 'Password must contain an uppercase letter (A-Z)';
                                  if (!RegExp(r'[a-z]').hasMatch(val)) return 'Password must contain a lowercase letter (a-z)';
                                  if (!RegExp(r'[0-9]').hasMatch(val)) return 'Password must contain a number (0-9)';
                                  if (!RegExp(r'[^a-zA-Z0-9\s]').hasMatch(val)) return 'Password must contain a special character (!@#\$%^&*)';
                                  if (val.contains(' ')) return 'Password cannot contain spaces';
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),

                              // Sign In mode: Remember me & Forgot Password
                              if (!_register) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('Remember me', style: TextStyle(fontSize: 12.5, color: p.muted)),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _forgotPasswordDialog,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot password?',
                                        style: TextStyle(color: p.accentText, fontSize: 12.5, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Registration Password Requirement Chips
                              if (_register) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _reqChip('8+ chars', _password.text.length >= 8, p),
                                    _reqChip('Uppercase (A-Z)', RegExp(r'[A-Z]').hasMatch(_password.text), p),
                                    _reqChip('Lowercase (a-z)', RegExp(r'[a-z]').hasMatch(_password.text), p),
                                    _reqChip('Number (0-9)', RegExp(r'[0-9]').hasMatch(_password.text), p),
                                    _reqChip('Special char', RegExp(r'[^a-zA-Z0-9\s]').hasMatch(_password.text), p),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),

                              // Submit Button
                              GlowButton(
                                label: _register ? 'Create Official Account' : 'Sign In to Official Account',
                                icon: _register ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
                                expand: true,
                                loading: _busy,
                                onPressed: _busy ? null : _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Trust & Security Notice
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 13, color: p.muted),
                            const SizedBox(width: 5),
                            Text(
                              '256-bit SSL Encrypted • Official Government & Citizen Portal',
                              style: TextStyle(fontSize: 11.5, color: p.muted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Legal and server settings links
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _showTermsDialog,
                            child: Text('Security & Privacy', style: TextStyle(color: p.muted, fontSize: 12)),
                          ),
                          Text('•', style: TextStyle(color: p.muted)),
                          TextButton.icon(
                            onPressed: _serverDialog,
                            icon: Icon(Icons.settings_ethernet, size: 16, color: p.muted),
                            label: Text('Server settings', style: TextStyle(color: p.muted, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
