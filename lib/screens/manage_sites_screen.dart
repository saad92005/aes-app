part of '../main.dart';

class ManageSitesScreen extends StatefulWidget {
  final AppUser currentUser;
  final Permissions perms;
  const ManageSitesScreen({super.key, required this.currentUser, required this.perms});

  @override
  State<ManageSitesScreen> createState() => _ManageSitesScreenState();
}

class _ManageSitesScreenState extends State<ManageSitesScreen> {
  final List<String> _regionOptions = const ['Multan', 'Lahore', 'Faisalabad'];

  // Handles both create and edit - SiteEntry's fields are all final, so "editing" means
  // building a new instance with the same id and overwriting the Firestore doc, same
  // approach used for editing a WorkOrder/ExpenseClaim elsewhere in this app.
  Future<void> _showSiteDialog({SiteEntry? existing}) async {
    final nameController = TextEditingController(text: existing?.siteName ?? '');
    String region = existing?.region ?? (widget.perms.seesAllRegions ? 'Lahore' : widget.currentUser.region);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Site' : 'Edit Site'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Site Name', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: region,
                    decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                    items: _regionOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setDialogState(() => region = v ?? region),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final site = SiteEntry(
                      id: existing?.id ?? 'SITE-${_siteCounter++}',
                      siteName: nameController.text.trim().toUpperCase(),
                      region: region,
                    );
                    try {
                      await DataService.saveSite(site);
                      setState(() {
                        if (existing != null) {
                          final idx = sampleSites.indexWhere((s) => s.id == existing.id);
                          if (idx != -1) sampleSites[idx] = site;
                        } else {
                          sampleSites.add(site);
                        }
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save site: $e'), backgroundColor: Colors.redAccent),
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
      },
    );
  }

  Future<void> _deleteSite(SiteEntry site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete Site')),
        content: Text('Delete "${site.siteName}"? This cannot be undone.'),
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
      await DataService.deleteSite(site.id);
      setState(() => sampleSites.removeWhere((s) => s.id == site.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete site: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sites = (widget.perms.seesAllRegions
            ? sampleSites
            : sampleSites.where((s) => s.region == widget.currentUser.region))
        .toList()
        .reversed
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Sites', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
              ElevatedButton.icon(
                onPressed: () => _showSiteDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Add Site')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AESColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.perms.seesAllRegions
                ? 'All regions · ${sites.length} site${sites.length == 1 ? '' : 's'}'
                : '${widget.currentUser.region} · ${sites.length} site${sites.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AESColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (sites.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(tr('No sites added yet'), style: TextStyle(color: AESColors.grey))),
            )
          else
            ...sites.map((s) => Container(
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
                        child: Text(s.siteName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AESColors.darkGrey)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AESColors.lightGreen, borderRadius: BorderRadius.circular(20)),
                        child: Text(s.region, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AESColors.primaryGreen)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AESColors.grey),
                        tooltip: 'Edit',
                        onPressed: () => _showSiteDialog(existing: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete',
                        onPressed: () => _deleteSite(s),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

