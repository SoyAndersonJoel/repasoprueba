import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool showIcon;
  final double? fontSize;

  const RoleBadge({
    super.key,
    required this.role,
    this.showIcon = true,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRoleColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getRoleColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getRoleIcon(),
              size: fontSize != null ? fontSize! + 2 : 14,
              color: _getRoleColor(),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            role.displayName,
            style: TextStyle(
              color: _getRoleColor(),
              fontWeight: FontWeight.w600,
              fontSize: fontSize ?? 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (role) {
      case UserRole.visitante:
        return Colors.blue;
      case UserRole.publicador:
        return Colors.green;
    }
  }

  IconData _getRoleIcon() {
    switch (role) {
      case UserRole.visitante:
        return Icons.visibility;
      case UserRole.publicador:
        return Icons.edit;
    }
  }
}

class PermissionWidget extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final bool Function() hasPermission;

  const PermissionWidget({
    super.key,
    required this.permission,
    required this.child,
    required this.hasPermission,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return hasPermission() 
        ? child 
        : fallback ?? const SizedBox.shrink();
  }
}

class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final Function(UserRole) onRoleChanged;
  final bool enabled;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Usuario',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...UserRole.values.map((role) => 
          RadioListTile<UserRole>(
            title: Row(
              children: [
                RoleBadge(role: role),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getRoleDescription(role),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            value: role,
            groupValue: selectedRole,
            onChanged: enabled ? (value) {
              if (value != null) onRoleChanged(value);
            } : null,
            activeColor: _getRoleColor(role),
          ),
        ).toList(),
      ],
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.visitante:
        return 'Puede visualizar contenido y reseñas';
      case UserRole.publicador:
        return 'Puede publicar, subir fotos y gestionar reseñas';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.visitante:
        return Colors.blue;
      case UserRole.publicador:
        return Colors.green;
    }
  }
}
