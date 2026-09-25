part of '../main.dart';

// ---------------- MANAGE CLIENTS SCREEN ----------------
// Clients are normally added inline (typed once on a quotation, auto-saved - see
// quotation_form_screen.dart's _ensureClientSaved) - this screen is where a typo gets fixed
// or a stale/duplicate client gets removed, same relationship ManageSitesScreen has to the
// sites that get auto-registered from Gmail sync.
class ManageClientsScreen extends StatefulWidget {
  const ManageClientsScreen({super.key});

  @override
  State<ManageClientsScreen> createState() => _ManageClientsScreenState();
}

class _ManageClientsScreenState extends State<ManageClientsScreen> {
  Future<void> _showClientDialog({ClientEntry? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final companyController = TextEditingController(text: existing?.company ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Client' : 'Edit Client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Client contact name', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Client company', border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final client = ClientEntry(
                  id: existing?.id ?? 'CLIENT-${_clientCounter++}',
                  name: nameController.text.trim(),
                  company: companyController.text.trim(),
                );
                try {
                  await DataService.saveClient(client);
                  setState(() {
                    if (existing != null) {
                      final idx = sampleClients.indexWhere((c) => c.id == existing.id);
                      if (idx != -1) sampleClients[idx] = client;
                    } else {
                      sampleClients.add(client);
                    }
                  });
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save client: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteClient(ClientEntry client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Client')),
        content: Text('Delete "${client.name}"? This only removes it from the quotation autocomplete list - existing quotations keep their client name/company as typed.'),
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
      await DataService.deleteClient(client.id);
      setState(() => sampleClients.removeWhere((c) => c.id == client.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete client: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = sampleClients.toList().reversed.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Clients', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: () => _showClientDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Add Client')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${clients.length} client${clients.length == 1 ? '' : 's'}', style: const TextStyle(color: AESColors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          if (clients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No clients saved yet - they\'re also added automatically the first time you type a new one on a quotation', style: TextStyle(color: AESColors.grey))),
            )
          else
            ...clients.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                            if (c.company.isNotEmpty) Text(c.company, style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AESColors.grey),
                        tooltip: 'Edit',
                        onPressed: () => _showClientDialog(existing: c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete',
                        onPressed: () => _deleteClient(c),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
