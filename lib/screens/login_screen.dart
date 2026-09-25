part of '../main.dart';

// ---------------- LOGIN SCREEN ----------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  final List<Offset> _stars = _generateStars(120);

  // Firebase Auth persists the last signed-in session on its own - while that's true and
  // biometric login is turned on for this account, skip the username/password form
  // entirely and gate re-entry behind a fingerprint/Face ID prompt instead. Starts true so
  // the normal form doesn't flash on screen for a split second before this check resolves.
  bool _checkingSession = true;
  bool _showBiometricUnlock = false;
  String? _biometricDisplayName;

  @override
  void initState() {
    super.initState();
    _checkPersistedSession();
  }

  Future<void> _checkPersistedSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) setState(() => _checkingSession = false);
      return;
    }
    final biometricSupported = await BiometricService.isAvailable;
    final enabled = biometricSupported && await BiometricService.isEnabledFor(firebaseUser.uid);
    if (!mounted) return;
    if (!enabled) {
      setState(() => _checkingSession = false);
      return;
    }
    setState(() {
      _checkingSession = false;
      _showBiometricUnlock = true;
      _biometricDisplayName = firebaseUser.email?.split('@').first;
    });
    _attemptBiometricUnlock();
  }

  Future<void> _attemptBiometricUnlock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final authenticated = await BiometricService.authenticate(reason: 'Unlock AES Portal');
    if (!mounted) return;
    if (!authenticated) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Fingerprint/Face ID not recognized. Try again or use your password.';
      });
      return;
    }
    final user = await AuthService.restoreSession();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _showBiometricUnlock = false;
        _errorMessage = 'Your session has expired. Please sign in again.';
      });
      return;
    }
    await LocalNotificationService.start(user.username);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardScreen(currentUser: user)));
  }

  void _switchToPasswordLogin() {
    setState(() {
      _showBiometricUnlock = false;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  // Only offered once per account (see BiometricService.wasPromptedFor) so a "Not Now"
  // doesn't nag the user again on every single login.
  Future<void> _maybeOfferBiometricEnrollment(AppUser user) async {
    final available = await BiometricService.isAvailable;
    if (!available || !mounted) return;
    final alreadyEnabled = await BiometricService.isEnabledFor(user.uid);
    final alreadyPrompted = await BiometricService.wasPromptedFor(user.uid);
    if (alreadyEnabled || alreadyPrompted || !mounted) return;
    await BiometricService.markPromptedFor(user.uid);

    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Enable Fingerprint / Face ID?')),
        content: Text(tr('Sign in faster next time without typing your username and password.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Not Now'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Enable')),
          ),
        ],
      ),
    );
    if (enable != true || !mounted) return;
    final confirmed = await BiometricService.authenticate(reason: 'Confirm to enable Fingerprint/Face ID login');
    if (confirmed) await BiometricService.setEnabledFor(user.uid, true);
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.signIn(username, password);
      if (!mounted) return;
      await _maybeOfferBiometricEnrollment(user);
      if (!mounted) return;
      await LocalNotificationService.start(user.username);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(currentUser: user)),
      );
    } on FirebaseAuthException catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid username or password';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        final msg = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = msg.isNotEmpty ? msg : 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.4,
                colors: [Color(0xFF1B3A24), AESColors.nearBlack],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _StarfieldPainter(_stars)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeSlideIn(
                    duration: const Duration(milliseconds: 550),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AESColors.brightGreen, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AESColors.brightGreen.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.settings,
                              size: 50,
                              color: AESColors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'AL AREESH ENGINEERING\nSOLUTIONS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          _TagChip(label: 'QUALITY'),
                          SizedBox(width: 6),
                          _TagChip(label: 'SAFETY'),
                          SizedBox(width: 6),
                          _TagChip(label: 'RELIABILITY'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      if (_checkingSession)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: AESColors.brightGreen),
                        )
                      else if (_showBiometricUnlock)
                        _buildBiometricCard()
                      else
                        _buildPasswordCard(),
                    ],
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

  Widget _buildPasswordCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          _UnderlineField(
            controller: _usernameController,
            label: tr('Username'),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: 22),
          _UnderlineField(
            controller: _passwordController,
            label: tr('Password'),
            obscure: _obscurePassword,
            focusNode: _passwordFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AESColors.grey,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(tr(_errorMessage!), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 30),
          PressableScale(
            onTap: _isLoading ? null : _handleLogin,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AESColors.brightGreen, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AESColors.brightGreen),
                        )
                      : Text(
                          tr('LOGIN'),
                          key: const ValueKey('label'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () {},
            child: Text(tr('Forgot Password'), style: const TextStyle(color: AESColors.brightGreen, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Shown instead of the password form when a persisted Firebase session exists and this
  // account has biometric login turned on - fingerprint/Face ID stands in for retyping the
  // username and password.
  Widget _buildBiometricCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            _biometricDisplayName == null ? tr('Welcome back') : 'Welcome back, $_biometricDisplayName',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 22),
          PressableScale(
            onTap: _isLoading ? null : _attemptBiometricUnlock,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AESColors.brightGreen.withValues(alpha: 0.15),
                border: Border.all(color: AESColors.brightGreen, width: 1.5),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AESColors.brightGreen),
                    )
                  : const Icon(Icons.fingerprint, color: AESColors.brightGreen, size: 42),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(_isLoading ? 'Waiting for Fingerprint / Face ID...' : 'Tap to unlock with Fingerprint / Face ID'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AESColors.grey, fontSize: 12),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(tr(_errorMessage!), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          TextButton(
            onPressed: _isLoading ? null : _switchToPasswordLogin,
            child: Text(tr('Use password instead'), style: const TextStyle(color: AESColors.brightGreen, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _UnderlineField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.suffixIcon,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AESColors.grey, fontSize: 14),
        suffixIcon: suffixIcon,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AESColors.brightGreen, width: 1.5)),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AESColors.brightGreen.withValues(alpha: 0.5), width: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: AESColors.grey, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w600)),
    );
  }
}

