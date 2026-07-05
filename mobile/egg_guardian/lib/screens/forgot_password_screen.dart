import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/theme.dart';

/// Two-step Forgot Password flow:
///   Step 1 – user enters email → token sent via email
///   Step 2 – user enters token + new password → password updated
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _tokenCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  bool _isLoading     = false;
  bool _tokenSent     = false;  // step 1 done → show step 2
  bool _obscurePass   = true;
  bool _obscureConf   = true;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ─── Step 1: request token ────────────────────────────────────────────

  Future<void> _requestToken() async {
    if (!_step1Key.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      await ApiService().forgotPassword(_emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _tokenSent = true;
          _success   = 'A reset token has been sent to ${_emailCtrl.text.trim()}. '
                       'Check your email and paste the token below.';
        });
        _animController.reset();
        _animController.forward();
      }
    } catch (_) {
      // Even on error we pretend success (security best practice)
      if (mounted) {
        setState(() {
          _tokenSent = true;
          _success   = 'If that email is registered, a reset token has been sent.';
        });
        _animController.reset();
        _animController.forward();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Step 2: verify token + set new password ──────────────────────────

  Future<void> _resetPassword() async {
    if (!_step2Key.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _success = null; });

    try {
      await ApiService().resetPassword(
        _tokenCtrl.text.trim(),
        _passCtrl.text,
      );
      if (mounted) {
        _showSnack('Password reset! You can now sign in with your new password.', isError: false);
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: EgTheme.body(14)),
      backgroundColor: isError ? EgTheme.danger : EgTheme.success,
      duration: const Duration(seconds: 5),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EgTheme.bgDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: EgTheme.bgGradient),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: EgTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: FadeTransition(
                          opacity: _fadeIn,
                          child: _tokenSent ? _buildStep2() : _buildStep1(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1 Widget ─────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [EgTheme.accentLight, EgTheme.accentDark],
            ),
            borderRadius: EgTheme.r16,
            boxShadow: [BoxShadow(color: EgTheme.accent.withOpacity(0.3), blurRadius: 20)],
          ),
          child: const Icon(Icons.lock_reset_rounded, color: Colors.black, size: 30),
        ),
        const SizedBox(height: 20),
        Text('Forgot Password', style: EgTheme.display(22)),
        const SizedBox(height: 6),
        Text(
          'Enter your registered email address and we will send you a reset token.',
          style: EgTheme.body(13, color: EgTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Container(
          decoration: EgTheme.card(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _step1Key,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: EgTheme.body(15),
                  decoration: EgTheme.inputDecoration('Email address', icon: Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(v)) {
                      return 'Invalid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _requestToken,
                    style: EgTheme.primaryButton(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                          )
                        : Text('Send Reset Token',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black,
                            )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 2 Widget ─────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: EgTheme.success.withOpacity(0.1),
            borderRadius: EgTheme.r16,
            border: Border.all(color: EgTheme.success.withOpacity(0.3)),
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: EgTheme.success, size: 30),
        ),
        const SizedBox(height: 20),
        Text('Check Your Email', style: EgTheme.display(22)),
        const SizedBox(height: 6),
        if (_success != null)
          Text(_success!, style: EgTheme.body(13, color: EgTheme.textSecondary),
              textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Container(
          decoration: EgTheme.card(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _step2Key,
            child: Column(
              children: [
                // Token
                TextFormField(
                  controller: _tokenCtrl,
                  style: EgTheme.body(14),
                  decoration: EgTheme.inputDecoration('Reset Token', icon: Icons.vpn_key_outlined),
                  validator: (v) => (v == null || v.isEmpty) ? 'Paste the token from your email' : null,
                ),
                const SizedBox(height: 14),
                // New password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: EgTheme.body(15),
                  decoration: EgTheme.inputDecoration('New Password', icon: Icons.lock_outline)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: EgTheme.textSecondary, size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Minimum 8 characters';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
                    if (!v.contains(RegExp(r'[a-zA-Z]'))) return 'Must contain a letter';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConf,
                  style: EgTheme.body(15),
                  decoration: EgTheme.inputDecoration('Confirm Password', icon: Icons.lock_outline)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConf ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: EgTheme.textSecondary, size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConf = !_obscureConf),
                    ),
                  ),
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EgTheme.danger.withOpacity(0.08),
                      borderRadius: EgTheme.r8,
                      border: Border.all(color: EgTheme.danger.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: EgTheme.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: EgTheme.body(13, color: EgTheme.danger))),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: EgTheme.primaryButton(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                          )
                        : Text('Reset Password',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black,
                            )),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _tokenSent = false;
                    _error = null;
                    _success = null;
                  }),
                  child: Text('Resend token',
                      style: EgTheme.body(13,
                          color: EgTheme.accent, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
