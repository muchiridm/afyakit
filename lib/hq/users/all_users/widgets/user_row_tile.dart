// lib/hq/users/all_users/widgets/user_row_tile.dart

import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class UserRowTile extends StatefulWidget {
  const UserRowTile({
    super.key,
    required this.user,
    required this.membershipsMap,
    required this.fetchMemberships,
    required this.onUpdateMembership,
    required this.onRemoveMembership,
  });

  final AllUser user;
  final Map<String, Map<String, Object?>>? membershipsMap;
  final Future<Map<String, Map<String, Object?>>> Function() fetchMemberships;

  // HQ membership management callbacks
  final Future<void> Function(String tenantId, String role, bool active)
  onUpdateMembership;
  final Future<void> Function(String tenantId) onRemoveMembership;

  @override
  State<UserRowTile> createState() => _UserRowTileState();
}

class _UserRowTileState extends State<UserRowTile> {
  bool _loadingMems = false;
  bool _prefetched = false;

  @override
  void initState() {
    super.initState();

    // If we *know* this user has tenants (tenantCount > 0) but we have
    // no membershipsMap yet, prefetch memberships once after first frame
    if (!_prefetched &&
        widget.membershipsMap == null &&
        (widget.user.tenantCount > 0)) {
      _prefetched = true;
      _loadingMems = true;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        try {
          await widget.fetchMemberships();
        } finally {
          if (mounted) {
            setState(() {
              _loadingMems = false;
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email ?? widget.user.emailLower;
    final name = (widget.user.displayName ?? '').trim();
    final mems = widget.membershipsMap; // may be null until fetched
    final hasMems = mems != null && mems.isNotEmpty;

    // Prefer fetched memberships → tenantIds → stored aggregate
    final membershipCount = hasMems
        ? mems.length
        : (widget.user.tenantIds.isNotEmpty
              ? widget.user.tenantIds.length
              : widget.user.tenantCount);

    final visibleIds = _visibleTenantIds(mems, hasMems);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        child: Text(_initial(name.isNotEmpty ? name : email)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name.isNotEmpty ? '$name • $email' : email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          if (membershipCount > 0) _countBadge(membershipCount),
          if (widget.user.disabled)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.block, size: 14, color: Colors.redAccent),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildMembershipRow(
          visibleIds: visibleIds,
          mems: mems,
          hasMems: hasMems,
          membershipCount: membershipCount,
        ),
      ),
    );
  }

  // ── Membership row ────────────────────────────────────────────────
  Widget _buildMembershipRow({
    required List<String> visibleIds,
    required Map<String, Map<String, Object?>>? mems,
    required bool hasMems,
    required int membershipCount,
  }) {
    if (_loadingMems) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (membershipCount == 0) {
      // No tenants yet → show a "no tenants" chip + Add button
      return Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 6,
          runSpacing: -4,
          alignment: WrapAlignment.end,
          children: [
            Chip(
              label: const Text('no tenants'),
              backgroundColor: Colors.grey.shade200,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            ActionChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add tenant'),
              onPressed: _showAddMembershipDialog,
            ),
          ],
        ),
      );
    }

    if (visibleIds.isEmpty) {
      // We know they have tenants (count > 0), but we don't yet
      // know which ones. Show a generic badge + Add.
      final label = membershipCount == 1
          ? '1 tenant'
          : '$membershipCount tenants';
      return Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 6,
          runSpacing: -4,
          alignment: WrapAlignment.end,
          children: [
            Chip(
              label: Text(label),
              backgroundColor: Colors.grey.shade100,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            ActionChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add tenant'),
              onPressed: _showAddMembershipDialog,
            ),
          ],
        ),
      );
    }

    // We know exact tenant IDs → show them as chips + Add button
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 6,
        runSpacing: -4,
        alignment: WrapAlignment.end,
        children: [
          ...visibleIds.map((tid) {
            final m = hasMems ? mems![tid] : null;
            final role = (m?['role'] as String?) ?? '—';
            final active = m?['active'] == true;
            return _tenantChip(tid, role, active);
          }),
          ActionChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Add tenant'),
            onPressed: _showAddMembershipDialog,
          ),
        ],
      ),
    );
  }

  // ── UI atoms ─────────────────────────────────────────────────────
  Widget _tenantChip(String tenantId, String role, bool active) {
    return InkWell(
      onTap: () => _showManageMembershipDialog(
        tenantId: tenantId,
        currentRole: role,
        currentActive: active,
      ),
      child: Chip(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$tenantId: $role'),
            const SizedBox(width: 6),
            Icon(
              active ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: active ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.blue.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers, size: 12),
          const SizedBox(width: 3),
          Text('$count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ── Pure helpers ────────────────────────────────────────────────
  List<String> _visibleTenantIds(
    Map<String, Map<String, Object?>>? mems,
    bool hasMems,
  ) {
    // Prefer live memberships (authoritative)
    if (hasMems) {
      final ids = List<String>.from(mems!.keys);
      ids.sort();
      return ids;
    }

    // Fallback to denormalized tenantIds on the directory doc
    if (widget.user.tenantIds.isNotEmpty) {
      final ids = List<String>.from(widget.user.tenantIds);
      ids.sort();
      return ids;
    }

    return const <String>[];
  }

  String _initial(String s) {
    final v = s.trim();
    if (v.isEmpty) return '?';
    return v[0].toUpperCase();
  }

  // ── Dialogs ─────────────────────────────────────────────────────

  /// Add a brand-new tenant membership for this user.
  Future<void> _showAddMembershipDialog() async {
    final tenantCtl = TextEditingController();
    final roleCtl = TextEditingController(text: 'staff');
    bool active = true;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: const Text('Add tenant membership'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tenantCtl,
                      decoration: const InputDecoration(
                        labelText: 'Tenant ID',
                        hintText: 'e.g. afyakit, danabtmc',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: roleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Role (e.g. admin, staff)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final tenantId = tenantCtl.text.trim();
                      if (tenantId.isEmpty) {
                        // silently ignore; you can add a SnackBar if you want
                        return;
                      }
                      final role = roleCtl.text.trim().isEmpty
                          ? 'staff'
                          : roleCtl.text.trim();

                      await widget.onUpdateMembership(tenantId, role, active);
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    tenantCtl.dispose();
    roleCtl.dispose();
    if (!confirmed) return;

    // No extra work needed: the controller already patches membershipsByUid
    // on success, so this tile will rebuild with the new tenant chip.
  }

  Future<void> _showManageMembershipDialog({
    required String tenantId,
    required String currentRole,
    required bool currentActive,
  }) async {
    final roleCtl = TextEditingController(
      text: currentRole == '—' ? '' : currentRole,
    );
    bool active = currentActive;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: Text('Manage $tenantId membership'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: roleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Role (e.g. admin, staff)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final sure = await _confirmRemove(ctx, tenantId);
                      if (sure == true) {
                        await widget.onRemoveMembership(tenantId);
                        if (context.mounted) Navigator.of(ctx).pop(true);
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Remove access'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final role = roleCtl.text.trim().isEmpty
                          ? 'staff'
                          : roleCtl.text.trim();
                      await widget.onUpdateMembership(tenantId, role, active);
                      if (context.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    roleCtl.dispose();
    if (!confirmed) return;
  }

  Future<bool?> _confirmRemove(BuildContext ctx, String tenantId) {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Remove access'),
        content: Text('Remove this user\'s access to "$tenantId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
