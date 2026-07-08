import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:egg_guardian/screens/forgot_password_screen.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/session_service.dart';
import 'package:egg_guardian/theme.dart';

class LoginScreen extends StatefulWidget {
  final String? sessionExpiredMessage;
  const LoginScreen({super.key, this.sessionExpiredMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _jobRoleController  = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  bool _isLoading        = false;
  bool _isRegister       = false;
  bool _obscurePassword  = true;
  bool _rememberMe       = true;
  bool _isPendingApproval = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    _loadSavedEmail();

    if (widget.sessionExpiredMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnack(widget.sessionExpiredMessage!, isError: true);
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _jobRoleController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('remembered_email');
    if (saved != null && mounted) {
      setState(() => _emailController.text = saved);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; _isPendingApproval = false; });

    try {
      final api = ApiService();
      if (_isRegister) {
        final newUser = await api.register(
          _emailController.text.trim(),
          _passwordController.text,
          fullName: _fullNameController.text.trim(),
          jobRole:  _jobRoleController.text.trim(),
        );
        if (newUser.isActive) {
          // First user — auto-approved, log in immediately
          await api.login(_emailController.text.trim(), _passwordController.text, rememberMe: _rememberMe);
          final user = await api.getCurrentUser();
          await api.setAdminStatus(user.isSuperuser);
          SessionService().startSession();
          if (mounted) {
            Navigator.pushReplacementNamed(context, user.isSuperuser ? '/admin' : '/devices');
          }
        } else {
          setState(() { _isRegister = false; _error = null; _isPendingApproval = false; });
          _showSnack('Account created! Wait for an admin to approve your account before signing in.');
        }
        return;
      }

      // Login flow
      await api.login(_emailController.text.trim(), _passwordController.text, rememberMe: _rememberMe);
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_email', _emailController.text.trim());
      } else {
        await prefs.remove('remembered_email');
      }
      final user = await api.getCurrentUser();
      await api.setAdminStatus(user.isSuperuser);
      SessionService().startSession();
      if (mounted) {
        Navigator.pushReplacementNamed(context, user.isSuperuser ? '/admin' : '/devices');
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.message.toLowerCase().contains('pending')) {
        setState(() => _isPendingApproval = true);
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Is the server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    _animController.reset();
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
      _isPendingApproval = false;
    });
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: EgTheme.bgDeep,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: EgTheme.bgGradient),
            ),
          ),
          // Subtle amber glow top-right
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [EgTheme.accent.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 32),
                          _buildCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: EgTheme.r16,
            boxShadow: [
              BoxShadow(color: EgTheme.accent.withOpacity(0.35), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: ClipRRect(
            borderRadius: EgTheme.r16,
            child: Image.asset(
              'assets/logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (b) => EgTheme.accentGradient.createShader(b),
          child: Text('Egg Guardian', style: EgTheme.display(26)),
        ),
        const SizedBox(height: 6),
        Text(
          _isRegister ? 'Create your account' : 'Sign in to your account',
          style: EgTheme.body(14, color: EgTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: EgTheme.card(),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pending approval banner ──
            if (_isPendingApproval) ...[
              _buildPendingBanner(),
              const SizedBox(height: 20),
            ],

            // ── Register fields ──
            if (_isRegister) ...[
              _buildField(
                _fullNameController,
                'Full Name',
                icon: Icons.person_outline,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Full name is required';
                  if (v.trim().length < 2) return 'Enter your full name';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                _jobRoleController,
                'Job Role',
                icon: Icons.work_outline,
                hint: 'e.g. Farm Supervisor',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Job role is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),
            ],

            // ── Email ──
            _buildField(
              _emailController,
              'Email address',
              icon: Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Invalid email address';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ── Password ──
            _buildPasswordField(),

            // ── Remember me (login only) ──
            if (!_isRegister) ...[
              const SizedBox(height: 8),
              _buildRememberMe(),
              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: EgTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  ),
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: EgTheme.accent,
                    ),
                  ),
                ),
              ),
            ],

            // ── Error banner ──
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(),
            ],

            const SizedBox(height: 24),

            // ── Submit ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: EgTheme.primaryButton(),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : Text(_isRegister ? 'Create Account' : 'Sign In',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black)),
              ),
            ),

            const SizedBox(height: 20),

            // ── Toggle mode ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isRegister ? 'Already have an account?' : "Don't have an account?",
                  style: EgTheme.body(13, color: EgTheme.textSecondary),
                ),
                TextButton(
                  onPressed: _toggleMode,
                  style: TextButton.styleFrom(
                    foregroundColor: EgTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    _isRegister ? 'Sign In' : 'Register',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    String? hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      style: EgTheme.body(15),
      decoration: EgTheme.inputDecoration(label, icon: icon).copyWith(hintText: hint),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: EgTheme.body(15),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (_isRegister) {
          if (v.length < 8) return 'Minimum 8 characters';
          if (!RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) {
            return 'Must include letters and numbers';
          }
        }
        return null;
      },
      decoration: EgTheme.inputDecoration('Password', icon: Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: EgTheme.textSecondary,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildRememberMe() {
    return InkWell(
      onTap: () => setState(() => _rememberMe = !_rememberMe),
      borderRadius: EgTheme.r8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: EgTheme.accent,
                checkColor: Colors.black,
                side: const BorderSide(color: EgTheme.border),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('Remember me', style: EgTheme.body(13, color: EgTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EgTheme.accent.withOpacity(0.08),
        borderRadius: EgTheme.r12,
        border: Border.all(color: EgTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: EgTheme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Approval', style: EgTheme.body(14, color: EgTheme.accent, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Your account is awaiting admin approval. You\'ll be notified once access is granted.',
                  style: EgTheme.body(13, color: EgTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: EgTheme.danger.withOpacity(0.1),
        borderRadius: EgTheme.r12,
        border: Border.all(color: EgTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: EgTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: EgTheme.body(13, color: EgTheme.danger))),
        ],
      ),
    );
  }
}
