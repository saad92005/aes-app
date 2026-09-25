part of '../main.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  UserRole _selectedRole = UserRole.employee;
  String _selectedRegion = 'Lahore';
  bool _extraInventoryAccess = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  List<Map<String, dynamic>> _employees = [];
  bool _loadingEmployees = true;

  final List<String> _regionOptions = const ['Multan', 'Lahore', 'Faisalabad', 'All'];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    final list = await AuthService.listEmployees();
    setState(() {
      _employees = list;
      _loadingEmployees = false;
    });
  }

  Future<void> _toggleAccess(String uid, bool newValue) async {
    await AuthService.setEmployeeActive(uid, newValue);
    _loadEmployees();
  }

  Future<void> _deleteEmployee(Map<String, dynamic> emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete this account?')),
        content: Text('"${emp['username']}" will no longer be able to log in. Their past work order/expense/attendance history is kept, just no longer linked to an active account. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService.deleteEmployee(emp['uid']);
      _loadEmployees();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // Role/region are edited in place. Username/password go through delete-and-recreate behind
  // the scenes (see AuthService.resetEmployeeCredentials) since Firebase Auth has no client-side
  // way to overwrite another account's credentials - left blank, they stay unchanged.
  Future<void> _editEmployee(Map<String, dynamic> emp) async {
    UserRole role = roleFromString(emp['role']);
    String region = emp['region'] ?? 'All';
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final designationController = TextEditingController(text: emp['designation'] ?? '');
    bool extraInventoryAccess = emp['extraInventoryAccess'] == true;
    bool isSaving = false;
    String? error;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${emp['username']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<UserRole>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(), isDense: true),
                      items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                      onChanged: (v) => setDialogState(() => role = v ?? role),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: region,
                      decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                      items: _regionOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setDialogState(() => region = v ?? region),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: designationController,
                      decoration: const InputDecoration(
                        labelText: 'Designation (optional)',
                        hintText: 'e.g. Senior Technician, Site Supervisor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: extraInventoryAccess,
                      onChanged: (v) => setDialogState(() => extraInventoryAccess = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(tr('Grant Inventory access'), style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                      subtitle: Text(
                        tr('One-off exception for a role that normally can\'t see it'),
                        style: const TextStyle(fontSize: 11, color: AESColors.grey),
                      ),
                    ),
                    const Divider(height: 32),
                    Text(tr('Change username / password (optional)'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                    const SizedBox(height: 4),
                    Text(tr('Leave both blank to keep the current login as-is.'), style: TextStyle(fontSize: 12, color: AESColors.grey)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(labelText: 'New username', hintText: 'currently "${emp['username']}"', border: const OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New password (min 6 characters)', border: OutlineInputBorder(), isDense: true),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newUsername = usernameController.text.trim();
                          final newPassword = passwordController.text.trim();
                          if (newUsername.isNotEmpty || newPassword.isNotEmpty) {
                            if (newUsername.isEmpty || newPassword.isEmpty) {
                              setDialogState(() => error = 'Fill in both the new username and new password, or leave both blank.');
                              return;
                            }
                            if (newPassword.length < 6) {
                              setDialogState(() => error = 'Password must be at least 6 characters');
                              return;
                            }
                          }
                          setDialogState(() {
                            isSaving = true;
                            error = null;
                          });
                          try {
                            final designation = designationController.text.trim();
                            if (newUsername.isNotEmpty && newPassword.isNotEmpty) {
                              await AuthService.resetEmployeeCredentials(
                                emp['uid'],
                                newUsername: newUsername,
                                newPassword: newPassword,
                                role: role,
                                region: region,
                                designation: designation,
                                extraInventoryAccess: extraInventoryAccess,
                              );
                            } else {
                              await AuthService.updateEmployee(
                                emp['uid'],
                                role: role,
                                region: region,
                                designation: designation,
                                extraInventoryAccess: extraInventoryAccess,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                            _loadEmployees();
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              error = 'Failed to save: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in both username and password');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await AuthService.createEmployee(
        username: username,
        password: password,
        role: _selectedRole,
        region: _selectedRegion,
        designation: _designationController.text.trim(),
        extraInventoryAccess: _extraInventoryAccess,
      );
      setState(() {
        _isSubmitting = false;
        _successMessage = 'Account created for "$username" successfully';
        _usernameController.clear();
        _passwordController.clear();
        _designationController.clear();
        _extraInventoryAccess = false;
      });
      _loadEmployees();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.code == 'email-already-in-use'
            ? 'That username is already taken'
            : 'Could not create account: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Employee', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 4),
            Text(tr('Create a new login account for a team member'), style: TextStyle(color: AESColors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password (min 6 characters)', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _designationController,
                    decoration: const InputDecoration(
                      labelText: 'Designation (optional)',
                      hintText: 'e.g. Senior Technician, Site Supervisor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder(), isDense: true),
                    items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                    onChanged: (v) => setState(() => _selectedRole = v ?? UserRole.employee),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRegion,
                    decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                    items: _regionOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _selectedRegion = v ?? 'Lahore'),
                  ),
                  CheckboxListTile(
                    value: _extraInventoryAccess,
                    onChanged: (v) => setState(() => _extraInventoryAccess = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(tr('Grant Inventory access'), style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                    subtitle: Text(
                      tr('One-off exception for a role that normally can\'t see it (e.g. a specific Back Office person)'),
                      style: const TextStyle(fontSize: 11, color: AESColors.grey),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(_successMessage!, style: const TextStyle(color: AESColors.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AESColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Account'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(tr('Manage Access'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
            const SizedBox(height: 4),
            Text(tr('Turn access on or off for existing team members'), style: TextStyle(color: AESColors.grey, fontSize: 13)),
            const SizedBox(height: 14),
            if (_loadingEmployees)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AESColors.primaryGreen)),
              )
            else if (_employees.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(tr('No employee accounts yet'), style: TextStyle(color: AESColors.grey))),
              )
            else
              ..._employees.map((emp) {
                final active = emp['active'] == true;
                final role = roleFromString(emp['role']).label;
                final designation = (emp['designation'] as String?)?.trim() ?? '';
                final hasExtraInventoryAccess = emp['extraInventoryAccess'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(emp['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                            const SizedBox(height: 2),
                            Text(
                              designation.isNotEmpty ? '$role · $designation · ${emp['region']}' : '$role · ${emp['region']}',
                              style: const TextStyle(fontSize: 12, color: AESColors.grey),
                            ),
                            if (hasExtraInventoryAccess) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 12, color: AESColors.primaryGreen),
                                  const SizedBox(width: 4),
                                  Text(tr('Inventory access granted'), style: const TextStyle(fontSize: 11, color: AESColors.primaryGreen, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AESColors.grey),
                        tooltip: 'Edit role/region/username/password',
                        onPressed: () => _editEmployee(emp),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete account',
                        onPressed: () => _deleteEmployee(emp),
                      ),
                      Text(active ? 'Active' : 'Deactivated', style: TextStyle(fontSize: 12, color: active ? AESColors.primaryGreen : Colors.redAccent)),
                      Switch(
                        value: active,
                        activeThumbColor: AESColors.primaryGreen,
                        onChanged: (v) => _toggleAccess(emp['uid'], v),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

