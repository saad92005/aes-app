part of '../main.dart';

// ---------------- CHART OF ACCOUNTS SCREEN ----------------
class ChartOfAccountsScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const ChartOfAccountsScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AccountType? _typeFilter;
  final Set<String> _expanded = {};
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _seedDefaults() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final defaults = buildDefaultChartOfAccounts();
      for (final account in defaults) {
        await DataService.saveAccount(account);
      }
      setState(() => sampleAccounts.addAll(defaults));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${defaults.length} accounts created'), backgroundColor: AESColors.primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to seed Chart of Accounts: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showAccountDialog({Account? existing, String? defaultParentCode}) async {
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final bankNameController = TextEditingController(text: existing?.bankName ?? '');
    final bankAccountNumberController = TextEditingController(text: existing?.bankAccountNumber ?? '');
    // A child added under a parent inherits that parent's statement type by default (a child
    // of a Liability account should start as a Liability, not silently default to Asset) -
    // still changeable via the dropdown before saving.
    AccountType type = existing?.type ?? (defaultParentCode != null ? accountByCode(defaultParentCode)?.type ?? AccountType.asset : AccountType.asset);
    String? parentCode = existing?.parentCode ?? defaultParentCode;
    NormalBalance normalBalance = existing?.normalBalance ?? type.defaultNormalBalance;
    bool normalBalanceManuallySet = existing != null;
    String? codeError;
    bool isSubmitting = false;

    // Every other account except this one (can't be its own parent) and none of its own
    // descendants (would create a cycle in the hierarchy).
    List<Account> validParents() {
      if (existing == null) return List.of(sampleAccounts)..sort((a, b) => a.code.compareTo(b.code));
      final descendantCodes = <String>{};
      void collect(String code) {
        for (final child in childAccountsOf(code)) {
          descendantCodes.add(child.code);
          collect(child.code);
        }
      }
      collect(existing.code);
      return sampleAccounts.where((a) => a.code != existing.code && !descendantCodes.contains(a.code)).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isBankLeaf = parentCode == '1120';
            return AlertDialog(
              title: Text(existing == null ? 'Add Account' : 'Edit Account'),
              // maxWidth (not a fixed width) so this shrinks to fit on a phone-width screen
              // instead of forcing 460 logical pixels and overflowing past the viewport edge.
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: codeController,
                              enabled: existing == null,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Account Code',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: codeError,
                                helperText: codeController.text.trim().isEmpty ? null : accountCodeRangeWarning(codeController.text.trim(), type),
                                helperMaxLines: 2,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: nameController,
                              autofocus: existing == null,
                              decoration: const InputDecoration(labelText: 'Account Name', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<AccountType>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Account Type', border: OutlineInputBorder(), isDense: true),
                        items: AccountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                        onChanged: existing != null
                            ? null // Changing an existing account's type after it has history would misclassify every past journal line - create a new account instead.
                            : (v) => setDialogState(() {
                                  type = v ?? type;
                                  if (!normalBalanceManuallySet) normalBalance = type.defaultNormalBalance;
                                }),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue: validParents().any((a) => a.code == parentCode) ? parentCode : null,
                        decoration: const InputDecoration(labelText: 'Parent Account (optional)', border: OutlineInputBorder(), isDense: true),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None - top-level account')),
                          ...validParents().map((a) => DropdownMenuItem<String?>(value: a.code, child: Text('${a.code} - ${a.name}', overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setDialogState(() => parentCode = v),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(labelText: 'Account Category', hintText: 'e.g. Current Assets, Fixed Assets', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<NormalBalance>(
                        initialValue: normalBalance,
                        decoration: const InputDecoration(labelText: 'Normal Balance', border: OutlineInputBorder(), isDense: true),
                        items: NormalBalance.values.map((n) => DropdownMenuItem(value: n, child: Text(n.label))).toList(),
                        onChanged: (v) => setDialogState(() {
                          normalBalance = v ?? normalBalance;
                          normalBalanceManuallySet = true;
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder(), isDense: true),
                      ),
                      if (isBankLeaf) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 4),
                        Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bankNameController,
                          decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: bankAccountNumberController,
                          decoration: const InputDecoration(labelText: 'Account Number / IBAN', border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          final name = nameController.text.trim();
                          if (code.isEmpty || int.tryParse(code) == null) {
                            setDialogState(() => codeError = 'Enter a numeric account code');
                            return;
                          }
                          if (existing == null && accountByCode(code) != null) {
                            setDialogState(() => codeError = 'An account with this code already exists');
                            return;
                          }
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter an account name'), backgroundColor: Colors.redAccent),
                            );
                            return;
                          }
                          setDialogState(() {
                            codeError = null;
                            isSubmitting = true;
                          });
                          final account = Account(
                            code: code,
                            name: name,
                            type: type,
                            parentCode: parentCode,
                            category: categoryController.text.trim(),
                            normalBalance: normalBalance,
                            description: descController.text.trim(),
                            isActive: existing?.isActive ?? true,
                            createdAt: existing?.createdAt,
                            updatedAt: DateTime.now().toIso8601String(),
                            bankName: parentCode == '1120' && bankNameController.text.trim().isNotEmpty ? bankNameController.text.trim() : null,
                            bankAccountNumber: parentCode == '1120' && bankAccountNumberController.text.trim().isNotEmpty ? bankAccountNumberController.text.trim() : null,
                          );
                          try {
                            await DataService.saveAccount(account);
                            setState(() {
                              if (existing != null) {
                                final idx = sampleAccounts.indexWhere((a) => a.code == existing.code);
                                if (idx != -1) sampleAccounts[idx] = account;
                              } else {
                                sampleAccounts.add(account);
                              }
                            });
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save account: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(existing == null ? 'Add Account' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActive(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account.isActive ? 'Deactivate Account' : 'Activate Account'),
        content: Text(
          account.isActive
              ? '"${account.code} - ${account.name}" will no longer be selectable for new journal entries. Existing history is unaffected.'
              : '"${account.code} - ${account.name}" will become selectable for new journal entries again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final previous = account.isActive;
    setState(() => account.isActive = !account.isActive);
    account.updatedAt = DateTime.now().toIso8601String();
    try {
      await DataService.saveAccount(account);
    } catch (e) {
      setState(() => account.isActive = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _deleteAccount(Account account) async {
    final hasChildren = childAccountsOf(account.code).isNotEmpty;
    final hasTransactions = sampleJournalEntries.any((e) => e.lines.any((l) => l.accountCode == account.code));
    if (hasChildren || hasTransactions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasTransactions
              ? 'This account already has journal transactions posted - deactivate it instead of deleting.'
              : 'This account has child accounts - remove or reassign them first.'),
          backgroundColor: AESColors.darkGrey,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Delete "${account.code} - ${account.name}"? This account has no transactions, so this cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.deleteAccount(account.code);
      setState(() => sampleAccounts.removeWhere((a) => a.code == account.code));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _openDetail(Account account) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AccountDetailScreen(account: account, currentUser: widget.currentUser)))
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    if (sampleAccounts.isEmpty) {
      return Material(
        color: AESColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_tree_outlined, size: 56, color: AESColors.grey),
                const SizedBox(height: 16),
                const Text('No Chart of Accounts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                const SizedBox(height: 8),
                const Text(
                  'Seed the standard Chart of Accounts to get started - every account it creates can be edited, renamed, or deactivated afterward.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AESColors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _seedDefaults,
                  icon: _busy
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Icon(Icons.playlist_add),
                  label: Text(_busy ? 'Seeding...' : 'Seed Default Chart of Accounts'),
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _searchQuery.trim().toLowerCase();
    final searching = q.isNotEmpty;
    List<Account> matching = sampleAccounts.where((a) => _typeFilter == null || a.type == _typeFilter).toList();
    if (searching) {
      matching = matching.where((a) => a.code.toLowerCase().contains(q) || a.name.toLowerCase().contains(q)).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
    }

    return Material(
      color: AESColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chart of Accounts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                ElevatedButton.icon(
                  onPressed: () => _showAccountDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('Add Account')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AESColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${sampleAccounts.length} accounts', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            ListSearchField(
              controller: _searchController,
              hintText: 'Search by account code or name...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Types'),
                  selected: _typeFilter == null,
                  onSelected: (_) => setState(() => _typeFilter = null),
                ),
                for (final t in AccountType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _typeFilter == t,
                    onSelected: (_) => setState(() => _typeFilter = t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (searching)
              if (matching.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text(tr('No accounts match this search'), style: TextStyle(color: AESColors.grey.withValues(alpha: 0.8)))),
                )
              else
                ...matching.map((a) => _AccountRow(
                      account: a,
                      depth: 0,
                      breadcrumb: accountAncestors(a).reversed.map((x) => x.name).join(' > '),
                      hasChildren: false,
                      expanded: false,
                      onToggleExpand: null,
                      onTap: () => _openDetail(a),
                      onEdit: () => _showAccountDialog(existing: a),
                      onToggleActive: () => _toggleActive(a),
                      onDelete: () => _deleteAccount(a),
                      onAddChild: () => _showAccountDialog(defaultParentCode: a.code),
                    ))
            else
              ..._buildTree(null, 0, matching.toSet()),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTree(String? parentCode, int depth, Set<Account> allowed) {
    final children = childAccountsOf(parentCode).where(allowed.contains).toList();
    final widgets = <Widget>[];
    for (final account in children) {
      final hasChildren = childAccountsOf(account.code).isNotEmpty;
      final isExpanded = _expanded.contains(account.code);
      widgets.add(_AccountRow(
        account: account,
        depth: depth,
        breadcrumb: null,
        hasChildren: hasChildren,
        expanded: isExpanded,
        onToggleExpand: hasChildren
            ? () => setState(() {
                  if (isExpanded) {
                    _expanded.remove(account.code);
                  } else {
                    _expanded.add(account.code);
                  }
                })
            : null,
        onTap: () => _openDetail(account),
        onEdit: () => _showAccountDialog(existing: account),
        onToggleActive: () => _toggleActive(account),
        onDelete: () => _deleteAccount(account),
        onAddChild: () => _showAccountDialog(defaultParentCode: account.code),
      ));
      if (hasChildren && isExpanded) {
        widgets.addAll(_buildTree(account.code, depth + 1, allowed));
      }
    }
    return widgets;
  }
}

class _AccountRow extends StatelessWidget {
  final Account account;
  final int depth;
  final String? breadcrumb;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onAddChild;

  const _AccountRow({
    required this.account,
    required this.depth,
    required this.breadcrumb,
    required this.hasChildren,
    required this.expanded,
    required this.onToggleExpand,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    final balance = rollupAccountMovement(account.code);
    return Container(
      margin: EdgeInsets.only(left: depth * 20.0, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AESColors.lightGrey),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: onToggleExpand != null
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20, color: AESColors.grey),
                        onPressed: onToggleExpand,
                      )
                    : null,
              ),
              SizedBox(
                width: 52,
                child: Text(account.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: account.isActive ? AESColors.darkGrey : AESColors.grey,
                        decoration: account.isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    if (breadcrumb != null && breadcrumb!.isNotEmpty)
                      Text(breadcrumb!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AESColors.grey))
                    else if (account.category.isNotEmpty)
                      Text(account.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AESColors.grey)),
                  ],
                ),
              ),
              if (!account.isActive)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AESColors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Inactive', style: TextStyle(fontSize: 10, color: AESColors.grey, fontWeight: FontWeight.w600)),
                ),
              Text(
                'Rs ${balance.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balance < 0 ? Colors.redAccent : AESColors.darkGrey),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AESColors.grey),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'toggle':
                      onToggleActive();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                    case 'addChild':
                      onAddChild();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Account')),
                  const PopupMenuItem(value: 'addChild', child: Text('Add Child Account')),
                  PopupMenuItem(value: 'toggle', child: Text(account.isActive ? 'Deactivate' : 'Activate')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete Account')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
