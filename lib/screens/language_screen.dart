part of '../main.dart';

// ---------------- REPORTS SCREEN (Excel-style table) ----------------
// ---------------- ADD EMPLOYEE SCREEN ----------------
// ---------------- LANGUAGE SCREEN ----------------
class LanguageScreen extends StatelessWidget {
  final AppUser? currentUser;
  const LanguageScreen({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, currentLang, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Language'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                const SizedBox(height: 4),
                Text(tr('Switch app language'), style: const TextStyle(color: AESColors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                _LanguageOption(
                  title: 'English',
                  subtitle: 'Use the app in English',
                  selected: currentLang == AppLanguage.english,
                  onTap: () => appLanguage.value = AppLanguage.english,
                ),
                const SizedBox(height: 12),
                _LanguageOption(
                  title: 'اردو',
                  subtitle: 'ایپ کو اردو میں استعمال کریں',
                  selected: currentLang == AppLanguage.urdu,
                  onTap: () => appLanguage.value = AppLanguage.urdu,
                ),
                if (currentUser != null) ...[
                  const SizedBox(height: 32),
                  Text(tr('Security'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                  const SizedBox(height: 4),
                  Text(tr('Sign in faster without typing your password'), style: const TextStyle(color: AESColors.grey, fontSize: 13)),
                  const SizedBox(height: 14),
                  _BiometricLoginToggle(user: currentUser!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BiometricLoginToggle extends StatefulWidget {
  final AppUser user;
  const _BiometricLoginToggle({required this.user});

  @override
  State<_BiometricLoginToggle> createState() => _BiometricLoginToggleState();
}

class _BiometricLoginToggleState extends State<_BiometricLoginToggle> {
  bool _loading = true;
  bool _available = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable;
    final enabled = available && await BiometricService.isEnabledFor(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final confirmed = await BiometricService.authenticate(reason: 'Confirm to enable Fingerprint/Face ID login');
      if (!confirmed) return;
    }
    await BiometricService.setEnabledFor(widget.user.uid, value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AESColors.primaryGreen)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AESColors.lightGrey),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AESColors.primaryGreen,
        title: Text(tr('Fingerprint / Face ID login'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
        subtitle: Text(
          _available ? tr('Unlock the app instead of typing your username and password') : tr('Not supported on this device'),
          style: const TextStyle(fontSize: 12, color: AESColors.grey),
        ),
        value: _enabled,
        onChanged: _available ? _toggle : null,
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AESColors.primaryGreen : AESColors.lightGrey, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AESColors.primaryGreen : AESColors.grey,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

