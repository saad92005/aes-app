part of '../main.dart';

// ---------------- WORK ORDER DETAIL SCREEN ----------------
class WorkOrderDetailScreen extends StatefulWidget {
  final WorkOrder workOrder;
  final Permissions perms;

  const WorkOrderDetailScreen({super.key, required this.workOrder, required this.perms});

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  List<String> _employeePhotos = [];
  List<String> _afterPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final employee = await DataService.loadWorkOrderPhotos(widget.workOrder.id, 'employee');
    final after = await DataService.loadWorkOrderPhotos(widget.workOrder.id, 'after');
    if (mounted) {
      setState(() {
      _employeePhotos = employee;
      _afterPhotos = after;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workOrder = widget.workOrder;
    final perms = widget.perms;

    return Scaffold(
      backgroundColor: AESColors.background,
      appBar: AppBar(
        backgroundColor: AESColors.primaryGreen,
        foregroundColor: Colors.white,
        // Explicit rather than relying on AppBar's automatic back-arrow detection, which
        // depends on Navigator.canPop() correctly reading the route stack - guarantees a
        // working way back to the previous screen regardless of platform quirks.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('WO #${workOrder.id}'),
        actions: [
          if (perms.canEditWorkOrder)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Work Order',
              onPressed: () => _showEditWorkOrderDialog(context, workOrder),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(workOrder.siteName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                  ),
                  _StatusBadge(status: workOrder.status),
                ],
              ),
              if (workOrder.rejectionNote != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sent back by ${workOrder.rejectedByRole ?? 'Reviewer'}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
                            const SizedBox(height: 4),
                            Text(workOrder.rejectionNote!, style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _DetailSection(
                title: 'Work Order Details',
                rows: [
                  _DetailRow('Work Order #', workOrder.id),
                  if (workOrder.workType != null) _DetailRow('Work Type', workOrder.workType!),
                  _DetailRow('Priority', workOrder.priority.toString()),
                  _DetailRow('Description', workOrder.description),
                  _DetailRow('Reported Date', workOrder.reportedDate),
                  _DetailRow('Target Finish', workOrder.targetDate),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Location',
                rows: [
                  _DetailRow('Site', workOrder.siteName),
                  _DetailRow('Address', workOrder.address),
                  _DetailRow('Region', workOrder.region),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr('Assigned Worker'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                        if (perms.user.role == UserRole.backOffice)
                          TextButton.icon(
                            onPressed: () => _showAssignWorkerSheet(context, workOrder),
                            icon: const Icon(Icons.person_add_alt, size: 16, color: AESColors.primaryGreen),
                            label: Text(workOrder.assignedEmployeeUsername == null ? 'Assign' : 'Reassign', style: const TextStyle(color: AESColors.primaryGreen)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      workOrder.assignedEmployeeUsername ?? 'No worker assigned yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: workOrder.assignedEmployeeUsername == null ? AESColors.grey : AESColors.darkGrey,
                        fontWeight: workOrder.assignedEmployeeUsername == null ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    if (workOrder.employeeNotes != null) ...[
                      const SizedBox(height: 12),
                      Text(tr('Site Details from Worker'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AESColors.grey)),
                      const SizedBox(height: 4),
                      Text(workOrder.employeeNotes!, style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                    ],
                    if (_employeePhotos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _PhotoGallery(title: 'Site Photos from Worker', photos: _employeePhotos),
                    ],
                    if (workOrder.startedAt != null || workOrder.completedAt != null) ...[
                      const SizedBox(height: 12),
                      Text(tr('Job Timing'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AESColors.grey)),
                      const SizedBox(height: 4),
                      if (workOrder.startedAt != null)
                        Text('Started: ${_formatDateTimeDisplay(DateTime.parse(workOrder.startedAt!))}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                      if (workOrder.completedAt != null)
                        Text('Completed: ${_formatDateTimeDisplay(DateTime.parse(workOrder.completedAt!))}', style: const TextStyle(fontSize: 13, color: AESColors.darkGrey)),
                      if (workOrder.jobDuration != null)
                        Text('Time on job: ${_formatDuration(workOrder.jobDuration!)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AESColors.darkGreen)),
                      if (workOrder.metSla != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              workOrder.metSla! ? Icons.check_circle : Icons.error,
                              size: 16,
                              color: workOrder.metSla! ? AESColors.primaryGreen : const Color(0xFFE34948),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              workOrder.metSla! ? 'Within SLA' : 'Non SLA (missed deadline)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: workOrder.metSla! ? AESColors.primaryGreen : const Color(0xFFE34948),
                              ),
                            ),
                          ],
                        ),
                      ] else if (workOrder.completedAt != null) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'No SLA deadline was set for this work order, so SLA status cannot be calculated.',
                          style: TextStyle(fontSize: 12, color: AESColors.grey, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr('Assigned Vendor'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AESColors.darkGreen)),
                        if (perms.user.role == UserRole.backOffice)
                          TextButton.icon(
                            onPressed: () => _showAssignVendorSheet(context, workOrder),
                            icon: const Icon(Icons.storefront_outlined, size: 16, color: AESColors.primaryGreen),
                            label: Text(workOrder.assignedVendorUsername == null ? 'Assign' : 'Reassign', style: const TextStyle(color: AESColors.primaryGreen)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      workOrder.assignedVendorUsername ?? 'No vendor assigned yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: workOrder.assignedVendorUsername == null ? AESColors.grey : AESColors.darkGrey,
                        fontWeight: workOrder.assignedVendorUsername == null ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (workOrder.quotation != null) ...[
                const SizedBox(height: 16),
                _QuotationSummary(quotation: workOrder.quotation!, workOrder: workOrder, showInternalCosting: widget.perms.canViewInternalCosting),
                if (perms.user.role == UserRole.backOffice || perms.user.role == UserRole.ceo || perms.user.role == UserRole.headOfOperations) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => shareQuotationOnWhatsApp(workOrder, workOrder.quotation!),
                      icon: const Icon(Icons.share, size: 18, color: Color(0xFF25D366)),
                      label: Text(tr('Share Quotation on WhatsApp'), style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF25D366), width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSendEmailDialog(context, workOrder, workOrder.quotation!),
                      icon: const Icon(Icons.email_outlined, size: 18, color: AESColors.primaryGreen),
                      label: Text(tr('Send Quotation via Email'), style: TextStyle(color: AESColors.primaryGreen, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AESColors.primaryGreen, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
              if (workOrder.quotation != null && workOrder.quotation!.beforePhotoUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PhotoGallery(title: 'Before Photos', photos: workOrder.quotation!.beforePhotoUrls),
              ],
              if (_afterPhotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PhotoGallery(title: 'After Photos (Completed Work)', photos: _afterPhotos),
              ],
              if (workOrder.completionRemarks != null && workOrder.completionRemarks!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(title: 'Completion Remarks', rows: [_DetailRow('Remarks', workOrder.completionRemarks!)]),
              ],
              const SizedBox(height: 24),
              ..._buildActionButtons(context, workOrder, perms),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, WorkOrder workOrder, Permissions perms) {
    final buttons = <Widget>[];
    final canEditQuotation = perms.user.role == UserRole.backOffice;
    final quotationLocked = workOrder.status == WorkOrderStatus.managerApproval ||
        workOrder.status == WorkOrderStatus.approved ||
        workOrder.status == WorkOrderStatus.completed;

    // Employee: fill in site details - description and photos of the work found on site.
    // This feeds straight into the quotation Back Office builds next, so photos don't
    // need to be retaken and the description doesn't need to be retyped.
    if (perms.user.role == UserRole.employee &&
        workOrder.assignedEmployeeUsername == perms.user.username &&
        workOrder.status == WorkOrderStatus.pending) {
      buttons.add(_ActionButton(
        label: workOrder.employeeNotes == null ? 'Fill Site Details' : 'Edit Site Details',
        outlined: workOrder.employeeNotes != null,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => SiteDetailsScreen(workOrder: workOrder, currentUsername: perms.user.username)));
          await _loadPhotos();
          setState(() {});
        },
      ));
    }

    // Create quotation - Back Office only, while pending, only if no quotation exists yet
    if (workOrder.status == WorkOrderStatus.pending && workOrder.quotation == null && canEditQuotation) {
      buttons.add(_ActionButton(
        label: 'Fill Details & Create Quotation',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => QuotationFormScreen(workOrder: workOrder)));
          setState(() {});
        },
      ));
    }

    // Edit quotation - Back Office only, until it's sent for manager approval
    if (workOrder.quotation != null && !quotationLocked && canEditQuotation) {
      buttons.add(_ActionButton(
        label: 'Edit Quotation',
        outlined: true,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QuotationFormScreen(workOrder: workOrder, existingQuotation: workOrder.quotation)),
          );
          setState(() {});
        },
      ));
      // Deleting clears the quotation and reverts the work order back to pending (as if a
      // quotation was never created) rather than deleting the work order itself - same lock
      // window as Edit, so a quotation already sent up for approval can't be pulled out from
      // under a manager mid-review.
      buttons.add(_ActionButton(
        label: 'Delete Quotation',
        outlined: true,
        color: Colors.redAccent,
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr('Delete Quotation')),
              content: Text(tr('Delete this quotation and revert the work order back to pending? This cannot be undone.')),
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
          final previousQuotation = workOrder.quotation;
          final previousStatus = workOrder.status;
          setState(() {
            workOrder.quotation = null;
            workOrder.status = WorkOrderStatus.pending;
          });
          try {
            await DataService.saveWorkOrder(workOrder);
          } catch (e) {
            setState(() {
              workOrder.quotation = previousQuotation;
              workOrder.status = previousStatus;
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete quotation: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ));
    }

    if (workOrder.status == WorkOrderStatus.quotationReady && perms.user.role == UserRole.backOffice) {
      buttons.add(_ActionButton(
        label: 'Send to Manager for Approval',
        onPressed: () async {
          final previousStatus = workOrder.status;
          setState(() {
            workOrder.status = WorkOrderStatus.managerApproval;
            workOrder.rejectionNote = null;
            workOrder.rejectedByRole = null;
          });
          try {
            await DataService.saveWorkOrder(workOrder);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Sent to Operational Manager for approval')), backgroundColor: AESColors.darkGreen),
              );
            }
          } catch (e) {
            setState(() => workOrder.status = previousStatus);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ));
      buttons.add(_ActionButton(
        label: 'Reject & Send Back to Employee',
        outlined: true,
        color: Colors.redAccent,
        onPressed: () async {
          final note = await _showRejectDialog(context, 'Reason for sending back to employee');
          if (note == null) return;
          setState(() {
            workOrder.status = WorkOrderStatus.pending;
            workOrder.rejectionNote = note;
            workOrder.rejectedByRole = 'Back Office';
          });
          try {
            await DataService.saveWorkOrder(workOrder);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Sent back to employee with a note')), backgroundColor: Colors.redAccent),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ));
    }

    if (workOrder.status == WorkOrderStatus.managerApproval && perms.canApproveWorkOrders) {
      buttons.add(_ActionButton(
        label: 'Approve Work Order',
        onPressed: () async {
          final previousStatus = workOrder.status;
          setState(() => workOrder.status = WorkOrderStatus.approved);
          try {
            await DataService.saveWorkOrder(workOrder);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Work order approved')), backgroundColor: AESColors.darkGreen),
              );
            }
          } catch (e) {
            setState(() => workOrder.status = previousStatus);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ));
      buttons.add(_ActionButton(
        label: 'Reject & Send Back to Back Office',
        outlined: true,
        color: Colors.redAccent,
        onPressed: () async {
          final note = await _showRejectDialog(context, 'Reason for sending back to Back Office');
          if (note == null) return;
          setState(() {
            workOrder.status = WorkOrderStatus.quotationReady;
            workOrder.rejectionNote = note;
            workOrder.rejectedByRole = 'Operational Manager';
          });
          try {
            await DataService.saveWorkOrder(workOrder);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Sent back to Back Office with a note')), backgroundColor: Colors.redAccent),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ));
    }

    // Start Job is available as soon as the work order is assigned - the employee or vendor
    // may start on-site work (or the site survey) well before the quotation is approved, and
    // the SLA clock should reflect when they actually started, not when approval finished.
    {
      final isAssignedEmployee = perms.user.role == UserRole.employee && workOrder.assignedEmployeeUsername == perms.user.username;
      final isAssignedVendor = perms.user.role == UserRole.vendor && workOrder.assignedVendorUsername == perms.user.username;
      final noOneAssignedFallback = workOrder.assignedEmployeeUsername == null && perms.user.role == UserRole.backOffice;

      final assignedToMe = isAssignedEmployee || isAssignedVendor || noOneAssignedFallback;

      if (assignedToMe && workOrder.status != WorkOrderStatus.completed && workOrder.startedAt == null) {
        buttons.add(_ActionButton(
          label: 'Start Job',
          outlined: true,
          onPressed: () async {
            // Opens a picker rather than stamping "now" - they may be logging this after
            // the fact and need to enter the time work actually started.
            final picked = await _pickDateTime(context, initial: DateTime.now());
            if (picked == null) return;
            final previous = workOrder.startedAt;
            setState(() => workOrder.startedAt = picked.toIso8601String());
            try {
              await DataService.saveWorkOrder(workOrder);
            } catch (e) {
              setState(() => workOrder.startedAt = previous);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
                );
              }
            }
          },
        ));
      }

      // A quick, no-friction way to log the finish time - separate from "Mark as Completed"
      // below, which still requires after-photos and only unlocks once approved.
      if (assignedToMe &&
          workOrder.status != WorkOrderStatus.completed &&
          workOrder.startedAt != null &&
          workOrder.completedAt == null) {
        buttons.add(_ActionButton(
          label: 'End Job',
          outlined: true,
          color: Colors.deepOrange,
          onPressed: () async {
            final picked = await _pickDateTime(context, initial: DateTime.now());
            if (picked == null) return;
            final previous = workOrder.completedAt;
            setState(() => workOrder.completedAt = picked.toIso8601String());
            try {
              await DataService.saveWorkOrder(workOrder);
            } catch (e) {
              setState(() => workOrder.completedAt = previous);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
                );
              }
            }
          },
        ));
      }
    }

    if (workOrder.status == WorkOrderStatus.approved) {
      final isAssignedEmployee = perms.user.role == UserRole.employee && workOrder.assignedEmployeeUsername == perms.user.username;
      final isAssignedVendor = perms.user.role == UserRole.vendor && workOrder.assignedVendorUsername == perms.user.username;
      final noOneAssignedFallback = workOrder.assignedEmployeeUsername == null && perms.user.role == UserRole.backOffice;

      if (isAssignedEmployee || isAssignedVendor || noOneAssignedFallback) {
        buttons.add(_ActionButton(
          label: 'Mark as Completed',
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => CompletionPhotosScreen(workOrder: workOrder, currentUsername: perms.user.username)));
            await _loadPhotos();
            setState(() {});
          },
        ));
      }
    }

    // CEO-only: permanently delete a work order (e.g. removing test data). Cannot be undone.
    if (perms.user.role == UserRole.ceo) {
      buttons.add(_ActionButton(
        label: 'Delete Work Order',
        outlined: true,
        color: Colors.redAccent,
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr('Delete Work Order?')),
              content: Text('This will permanently delete WO #${workOrder.id} ("${workOrder.siteName}") and its quotation. This cannot be undone.'),
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
            await DataService.deleteWorkOrder(workOrder.id);
            sampleWorkOrders.removeWhere((w) => w.id == workOrder.id);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('WO #${workOrder.id} deleted'), backgroundColor: AESColors.darkGrey),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ));
    }

    return buttons;
  }

  Future<String?> _showRejectDialog(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Explain what needs to be fixed...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: Text(tr('Send Back')),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendEmailDialog(BuildContext context, WorkOrder workOrder, QuotationData quotation) async {
    if (!GmailService.isConnected) {
      final restored = await GmailService.tryRestoreSession();
      if (!restored && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Connect Gmail first (Gmail Sync in the sidebar) before sending quotation emails.')),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;

    final emailController = TextEditingController();
    final ccController = TextEditingController();
    final subjectController = TextEditingController(text: 'Quotation ${quotation.id} - ${quotation.siteName}');
    final messageController = TextEditingController(
      text: 'Dear ${quotation.clientName.isNotEmpty ? quotation.clientName : 'Sir/Madam'},\n\n'
          'Please find our quotation below/attached for your review.\n\n'
          'Regards,\n$vendorName',
    );
    String format = 'pdf';

    final result = await showDialog<(String to, String? cc, String format, String subject, String message)>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(tr('Send Quotation via Email'), style: TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quotation ${quotation.id} for ${quotation.siteName}', style: const TextStyle(fontSize: 13, color: AESColors.grey)),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Recipient email address',
                    hintText: 'e.g. client@company.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ccController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'CC (optional)',
                    hintText: 'e.g. backoffice@company.com, comma-separated for more than one',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  maxLines: 6,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message to client',
                    hintText: 'Write anything you want above the quotation table...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(tr('Attach as'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AESColors.darkGreen)),
                RadioListTile<String>(
                  value: 'pdf',
                  groupValue: format,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('PDF'),
                  onChanged: (v) => setDialogState(() => format = v!),
                ),
                RadioListTile<String>(
                  value: 'excel',
                  groupValue: format,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Excel (.xlsx)')),
                  onChanged: (v) => setDialogState(() => format = v!),
                ),
                RadioListTile<String>(
                  value: 'image',
                  groupValue: format,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Image (PNG)')),
                  onChanged: (v) => setDialogState(() => format = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AESColors.primaryGreen, foregroundColor: Colors.white),
              onPressed: () {
                final value = emailController.text.trim();
                if (value.isEmpty || !value.contains('@')) return;
                final cc = ccController.text.trim();
                final subject = subjectController.text.trim();
                Navigator.pop(context, (value, cc.isEmpty ? null : cc, format, subject, messageController.text));
              },
              child: Text(tr('Send Email')),
            ),
          ],
        );
      }),
    );

    if (result == null || !context.mounted) return;
    final (email, cc, chosenFormat, subject, message) = result;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text(tr('Sending email...')),
          ],
        ),
      ),
    );

    try {
      final EmailAttachment attachment;
      switch (chosenFormat) {
        case 'excel':
          attachment = EmailAttachment(
            filename: 'Quotation-${quotation.id}.xlsx',
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            bytes: ExportService.quotationExcelBytes(workOrder, quotation),
          );
          break;
        case 'image':
          attachment = EmailAttachment(
            filename: 'Quotation-${quotation.id}.png',
            mimeType: 'image/png',
            bytes: await ExportService.quotationImageBytes(context, workOrder, quotation),
          );
          break;
        default:
          attachment = EmailAttachment(
            filename: 'Quotation-${quotation.id}.pdf',
            mimeType: 'application/pdf',
            bytes: await ExportService.quotationPdfBytes(workOrder, quotation),
          );
      }
      await sendQuotationViaEmail(
        workOrder,
        quotation,
        email,
        ccEmail: cc,
        subject: subject.isEmpty ? 'Quotation ${quotation.id} - ${quotation.siteName}' : subject,
        customMessage: message,
        attachment: attachment,
      );
      quotation.sentAt = DateTime.now().toIso8601String();
      quotation.sentToEmail = email;
      quotation.sentCc = cc;
      await DataService.saveWorkOrder(workOrder);
      if (context.mounted) {
        Navigator.pop(context); // close the "Sending..." dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quotation sent to $email${cc != null ? ' (cc: $cc)' : ''}'), backgroundColor: AESColors.darkGreen),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close the "Sending..." dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Back Office (and the other coordination roles - see Permissions.canEditWorkOrder) editing
  // the work order's own facts directly - site name, address, region, priority, description,
  // work type, target finish. Deliberately does not touch status, assignment, quotation, or
  // completion data - those already have their own dedicated flows elsewhere on this screen.
  Future<void> _showEditWorkOrderDialog(BuildContext context, WorkOrder workOrder) async {
    final siteNameController = TextEditingController(text: workOrder.siteName);
    final addressController = TextEditingController(text: workOrder.address);
    final descriptionController = TextEditingController(text: workOrder.description);
    final workTypeController = TextEditingController(text: workOrder.workType ?? '');
    int priority = workOrder.priority;
    String region = workOrder.region;
    DateTime? targetFinish = workOrder.targetDateIso != null ? DateTime.tryParse(workOrder.targetDateIso!) : null;
    bool isSubmitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Work Order'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: siteNameController,
                        autofocus: true,
                        decoration: InputDecoration(labelText: 'Site Name', border: const OutlineInputBorder(), isDense: true, errorText: error),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: region,
                        decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder(), isDense: true),
                        items: const ['Multan', 'Lahore', 'Faisalabad'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setDialogState(() => region = v ?? region),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder(), isDense: true),
                        items: [
                          DropdownMenuItem(value: 1, child: Text(tr('1 - High'))),
                          DropdownMenuItem(value: 2, child: Text(tr('2 - Medium'))),
                          DropdownMenuItem(value: 3, child: Text(tr('3 - Low'))),
                        ],
                        onChanged: (v) => setDialogState(() => priority = v ?? priority),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: workTypeController,
                        decoration: const InputDecoration(labelText: 'Work Type (optional)', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final picked = await _pickDateTime(context, initial: targetFinish ?? DateTime.now().add(const Duration(days: 3)));
                          if (picked != null) setDialogState(() => targetFinish = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Target Finish (SLA deadline)', border: OutlineInputBorder(), isDense: true),
                          child: Text(
                            targetFinish == null ? 'Tap to set' : _formatDateTimeDisplay(targetFinish!),
                            style: TextStyle(color: targetFinish == null ? AESColors.grey : AESColors.darkGrey, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
                      ),
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
                          if (siteNameController.text.trim().isEmpty) {
                            setDialogState(() => error = 'Enter a site name');
                            return;
                          }
                          setDialogState(() {
                            error = null;
                            isSubmitting = true;
                          });

                          final previousSiteName = workOrder.siteName;
                          final previousAddress = workOrder.address;
                          final previousRegion = workOrder.region;
                          final previousPriority = workOrder.priority;
                          final previousDescription = workOrder.description;
                          final previousWorkType = workOrder.workType;
                          final previousTargetDate = workOrder.targetDate;
                          final previousTargetDateIso = workOrder.targetDateIso;

                          setState(() {
                            workOrder.siteName = siteNameController.text.trim().toUpperCase();
                            workOrder.address = addressController.text.trim();
                            workOrder.region = region;
                            workOrder.priority = priority;
                            workOrder.description = descriptionController.text.trim();
                            workOrder.workType = workTypeController.text.trim().isEmpty ? null : workTypeController.text.trim();
                            if (targetFinish != null) {
                              workOrder.targetDate = _formatDateTimeDisplay(targetFinish!);
                              workOrder.targetDateIso = targetFinish!.toIso8601String();
                            }
                          });

                          try {
                            await DataService.saveWorkOrder(workOrder);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Work order updated'), backgroundColor: AESColors.primaryGreen),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              workOrder.siteName = previousSiteName;
                              workOrder.address = previousAddress;
                              workOrder.region = previousRegion;
                              workOrder.priority = previousPriority;
                              workOrder.description = previousDescription;
                              workOrder.workType = previousWorkType;
                              workOrder.targetDate = previousTargetDate;
                              workOrder.targetDateIso = previousTargetDateIso;
                            });
                            if (context.mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save changes: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignWorkerSheet(BuildContext context, WorkOrder workOrder) async {
    final allEmployees = await AuthService.listEmployees();
    final eligible = allEmployees
        .where((e) =>
            roleFromString(e['role']) == UserRole.employee &&
            (e['region'] == workOrder.region || e['region'] == 'All') &&
            e['active'] == true)
        .toList();

    if (!context.mounted) return;

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active employees found for ${workOrder.region}'), backgroundColor: AESColors.darkGrey),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Assign Worker'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                const SizedBox(height: 4),
                Text('Employees in ${workOrder.region}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                const SizedBox(height: 14),
                ...eligible.map((e) => ListTile(
                      leading: const CircleAvatar(backgroundColor: AESColors.lightGreen, child: Icon(Icons.person, color: AESColors.primaryGreen)),
                      title: Text(e['username'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, e['username'] as String),
                    )),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      final previous = workOrder.assignedEmployeeUsername;
      setState(() => workOrder.assignedEmployeeUsername = selected);
      try {
        await DataService.saveWorkOrder(workOrder);
        _sendAssignmentNotification(recipient: selected, workOrder: workOrder);
      } catch (e) {
        setState(() => workOrder.assignedEmployeeUsername = previous);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save assignment: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _showAssignVendorSheet(BuildContext context, WorkOrder workOrder) async {
    final allEmployees = await AuthService.listEmployees();
    final eligible = allEmployees
        .where((e) =>
            roleFromString(e['role']) == UserRole.vendor &&
            (e['region'] == workOrder.region || e['region'] == 'All') &&
            e['active'] == true)
        .toList();

    if (!context.mounted) return;

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active vendors found for ${workOrder.region}'), backgroundColor: AESColors.darkGrey),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Assign Vendor'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                const SizedBox(height: 4),
                Text('Vendors in ${workOrder.region}', style: const TextStyle(fontSize: 12, color: AESColors.grey)),
                const SizedBox(height: 14),
                ...eligible.map((e) => ListTile(
                      leading: const CircleAvatar(backgroundColor: AESColors.lightGreen, child: Icon(Icons.storefront, color: AESColors.primaryGreen)),
                      title: Text(e['username'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, e['username'] as String),
                    )),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      final previous = workOrder.assignedVendorUsername;
      setState(() => workOrder.assignedVendorUsername = selected);
      try {
        await DataService.saveWorkOrder(workOrder);
        _sendAssignmentNotification(recipient: selected, workOrder: workOrder);
      } catch (e) {
        setState(() => workOrder.assignedVendorUsername = previous);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save assignment: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _sendAssignmentNotification({required String recipient, required WorkOrder workOrder}) {
    final now = DateTime.now();
    final timestamp = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final notification = AppNotification(
      id: 'NOTIF-${_notificationCounter++}',
      recipientUsername: recipient,
      title: 'New Work Order Assigned',
      message: 'You\'ve been assigned WO #${workOrder.id} - ${workOrder.siteName}',
      workOrderId: workOrder.id,
      timestamp: timestamp,
    );
    DataService.saveNotification(notification);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool outlined;
  final Color? color;
  const _ActionButton({required this.label, required this.onPressed, this.outlined = false, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AESColors.primaryGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: outlined
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: effectiveColor, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label, style: TextStyle(color: effectiveColor)),
              )
            : ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label),
              ),
      ),
    );
  }
}

class _QuotationSummary extends StatelessWidget {
  final QuotationData quotation;
  final WorkOrder workOrder;
  final bool showInternalCosting;
  const _QuotationSummary({required this.quotation, required this.workOrder, this.showInternalCosting = false});

  static const Color gold = Color(0xFFF3B41B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AESColors.lightGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: gold,
            child: Row(
              children: [
                Expanded(
                  child: Text(vendorName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const Text('QUOTATION', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Vendor Details'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AESColors.grey)),
                          const SizedBox(height: 4),
                          Text('NTN: $vendorNTN', style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                          Text('STRN: $vendorSTRN', style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                          Text(vendorAddress, style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Client Information'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AESColors.grey)),
                          const SizedBox(height: 4),
                          Text(quotation.clientName, style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                          Text(quotation.clientCompany, style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _miniField('Date', quotation.date),
                    _miniField('WO#', workOrder.id, highlight: true),
                    _miniField('Quotation#', quotation.id, highlight: true),
                    _miniField('Site Name', quotation.siteName),
                  ],
                ),
                const SizedBox(height: 8),
                _miniField('Description of Work Order', quotation.descriptionOfWorkOrder, fullWidth: true),
              ],
            ),
          ),
          // Line items table
          Container(
            width: double.infinity,
            color: gold,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 24, child: Text('Sr#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                Expanded(flex: 3, child: Text(tr('Description'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                Expanded(child: Text(tr('Units'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                Expanded(child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                Expanded(child: Text(tr('Rate'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                Expanded(child: Text(tr('Amount'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                Expanded(child: Text('CMEP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
              ],
            ),
          ),
          for (int i = 0; i < quotation.lineItems.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AESColors.lightGrey))),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 3, child: Text(quotation.lineItems[i].description, style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(quotation.lineItems[i].unit, style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(quotation.lineItems[i].qty.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(quotation.lineItems[i].rate.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(quotation.lineItems[i].amount.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(quotation.lineItems[i].cmepStatus, style: const TextStyle(fontSize: 11, color: AESColors.grey))),
                ],
              ),
            ),
          Container(
            color: gold,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(tr('Quote Total: '), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Rs ${quotation.quoteTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          if (quotation.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Notes / Terms'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AESColors.grey)),
                  const SizedBox(height: 4),
                  Text(quotation.notes, style: const TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                ],
              ),
            ),
          // Internal-only - never included in the emailed/WhatsApp'd quotation, and only
          // rendered here at all when the viewing role is allowed to see it (Back
          // Office/CEO/Finance/Head of Operations - not employees or vendors).
          if (showInternalCosting)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AESColors.lightGrey,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AESColors.lightGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Internal Only (not shown to client)'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AESColors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Total Internal Cost'), style: TextStyle(fontSize: 12, color: AESColors.darkGrey)),
                      Text('Rs ${quotation.totalInternalCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AESColors.darkGrey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Profit Margin'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                      Text('Rs ${quotation.profitMargin.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AESColors.darkGreen)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniField(String label, String value, {bool highlight = false, bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AESColors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize: 12,
                color: highlight ? AESColors.darkGreen : AESColors.darkGrey,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}

