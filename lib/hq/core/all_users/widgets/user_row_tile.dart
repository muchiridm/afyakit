import 'package:afyakit/hq/core/all_users/all_user_model.dart';
import 'package:flutter/material.dart';

class UserRowTile extends StatefulWidget {
  const UserRowTile({
    super.key,
    required this.user,
    required this.membershipsMap,
    required this.fetchMemberships,
  });

  final AllUser user;
  final Map<String, Map<String, Object?>>? membershipsMap;
  final Future<Map<String, Map<String, Object?>>> Function() fetchMemberships;

  @override
  State<UserRowTile> createState() => _UserRowTileState();
}

class _UserRowTileState extends State<UserRowTile> {
  bool _loadingMems = false;

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

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      onExpansionChanged: (open) => _handleExpansionChanged(open, hasMems),
      leading: CircleAvatar(child: Text(_initial(email))),
      title: _buildTitleRow(email, widget.user.disabled, membershipCount),
      subtitle: _buildSubtitle(name, widget.user.lastLoginAt),
      children: _buildChildren(visibleIds, mems, hasMems),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────────────────
  Future<void> _handleExpansionChanged(bool open, bool hasMems) async {
    if (!open || hasMems || _loadingMems) return;
    setState(() => _loadingMems = true);
    try {
      await widget.fetchMemberships(); // controller shows snack on error
    } finally {
      if (mounted) setState(() => _loadingMems = false);
    }
  }

  // ── Build helpers ────────────────────────────────────────────────────────
  Widget _buildTitleRow(String email, bool disabled, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (disabled)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.block, size: 16, color: Colors.redAccent),
          ),
        const SizedBox(width: 8),
        _countBadge(count),
      ],
    );
  }

  Widget _buildSubtitle(String name, DateTime? lastLoginAt) {
    final parts = <String>[
      if (name.isNotEmpty) name,
      if (lastLoginAt != null) 'last login: ${_fmtDateShort(lastLoginAt)}',
    ];
    return Text(
      parts.join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _buildChildren(
    List<String> visibleIds,
    Map<String, Map<String, Object?>>? mems,
    bool hasMems,
  ) {
    if (_loadingMems) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ];
    }

    if (visibleIds.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            children: [
              Chip(
                label: const Text('no tenants'),
                backgroundColor: Colors.grey.shade200,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: -6,
          children: visibleIds.map((tid) {
            final m = hasMems ? mems![tid] : null;
            final role = (m?['role'] as String?) ?? '—';
            final active = m?['active'] == true;
            return _tenantChip(tid, role, active);
          }).toList(),
        ),
      ),
    ];
  }

  // ── UI atoms ─────────────────────────────────────────────────────────────
  Widget _tenantChip(String tenantId, String role, bool active) {
    return Chip(
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
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers, size: 14),
          const SizedBox(width: 4),
          Text('$count'),
        ],
      ),
    );
  }

  // ── Pure helpers ─────────────────────────────────────────────────────────
  List<String> _visibleTenantIds(
    Map<String, Map<String, Object?>>? mems,
    bool hasMems,
  ) {
    if (widget.user.tenantIds.isNotEmpty) {
      return List<String>.from(widget.user.tenantIds);
    }
    if (hasMems) {
      final ids = List<String>.from(mems!.keys);
      ids.sort();
      return ids;
    }
    return const <String>[];
  }

  String _initial(String s) => (s.trim().isEmpty ? '?' : s[0].toUpperCase());

  String _fmtDateShort(DateTime d) {
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
