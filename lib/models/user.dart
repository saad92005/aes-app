part of '../main.dart';

// ---------------- ROLES & PERMISSIONS ----------------
enum UserRole {
  employee,
  backOffice,
  operationalManager,
  headOfOperations,
  finance,
  ceo,
  vendor,
  storeManager,
  procurement,
  officeStaff,
  bdmHrmAdmin,
  hsse,
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.employee:
        return 'Employee';
      case UserRole.backOffice:
        return 'Back Office';
      case UserRole.operationalManager:
        return 'Operational Manager';
      case UserRole.headOfOperations:
        return 'Head of Operations';
      case UserRole.finance:
        return 'Finance';
      case UserRole.ceo:
        return 'CEO';
      case UserRole.vendor:
        return 'Vendor';
      case UserRole.storeManager:
        return 'Store Manager';
      case UserRole.procurement:
        return 'Procurement';
      case UserRole.officeStaff:
        return 'Office Staff';
      case UserRole.bdmHrmAdmin:
        return 'BDM / HRM / Admin';
      case UserRole.hsse:
        return 'HSSE';
    }
  }
}

class AppUser {
  final String uid; // Firebase Auth user ID
  final String username;
  final UserRole role;
  final String region; // 'Multan', 'Lahore', 'Faisalabad', or 'All' for HQ-level roles
  // One-off exception, not a role - e.g. a specific Back Office person who also needs store
  // visibility without making every Back Office account able to see inventory. Toggled per
  // employee from Add Employee's edit dialog.
  final bool extraInventoryAccess;

  const AppUser({
    required this.uid,
    required this.username,
    required this.role,
    required this.region,
    this.extraInventoryAccess = false,
  });
}

// Temporary hardcoded accounts - kept only as reference, no longer used for login
const List<Map<String, String>> tempAccountsReference = [
  {'username': 'admin', 'role': 'CEO', 'region': 'All'},
  {'username': 'employee1', 'role': 'Employee', 'region': 'Lahore'},
  {'username': 'backoffice1', 'role': 'Back Office', 'region': 'All'},
  {'username': 'manager1', 'role': 'Operational Manager', 'region': 'All'},
  {'username': 'finance1', 'role': 'Finance', 'region': 'All'},
];

UserRole roleFromString(String s) {
  switch (s) {
    case 'employee':
      return UserRole.employee;
    case 'backOffice':
      return UserRole.backOffice;
    case 'operationalManager':
      return UserRole.operationalManager;
    case 'headOfOperations':
      return UserRole.headOfOperations;
    case 'finance':
      return UserRole.finance;
    case 'ceo':
      return UserRole.ceo;
    case 'vendor':
      return UserRole.vendor;
    case 'storeManager':
      return UserRole.storeManager;
    case 'procurement':
      return UserRole.procurement;
    case 'officeStaff':
      return UserRole.officeStaff;
    case 'bdmHrmAdmin':
      return UserRole.bdmHrmAdmin;
    case 'hsse':
      return UserRole.hsse;
    default:
      return UserRole.employee;
  }
}

String roleToStringKey(UserRole role) => role.toString().split('.').last;

