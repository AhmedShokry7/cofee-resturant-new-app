import 'package:flutter/material.dart';

class AdminDestination {
  const AdminDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.permission,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? permission;
}

const List<AdminDestination> adminDestinations = <AdminDestination>[
  AdminDestination(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
  ),
  AdminDestination(
    id: 'orders',
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    permission: 'orders.read',
  ),
  AdminDestination(
    id: 'products',
    label: 'Products',
    icon: Icons.local_cafe_outlined,
    permission: 'catalog.product.write',
  ),
  AdminDestination(
    id: 'categories',
    label: 'Categories',
    icon: Icons.category_outlined,
    permission: 'catalog.category.write',
  ),
  AdminDestination(
    id: 'inventory',
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    permission: 'inventory.read',
  ),
  AdminDestination(
    id: 'customers',
    label: 'Customers',
    icon: Icons.people_outline,
    permission: 'customers.read',
  ),
  AdminDestination(
    id: 'staff',
    label: 'Staff',
    icon: Icons.badge_outlined,
    permission: 'admin.staff.read',
  ),
  AdminDestination(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    permission: 'settings.write',
  ),
];
