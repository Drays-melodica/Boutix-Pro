import '../models/app_user.dart';

class SessionContext {
  SessionContext._();

  static AppUser? currentUser;

  static bool get isAdmin => currentUser?.isAdmin ?? false;
}

class Permissions {
  Permissions._();

  static bool get isAdmin => SessionContext.isAdmin;
  static bool get canEditProducts => isAdmin;
  static bool get canDeleteProducts => isAdmin;
  static bool get canAdjustStock => isAdmin;
  static bool get canExport => isAdmin;
  static bool get canManageUsers => isAdmin;
  static bool get canManageDatabase => isAdmin;
  static bool get canPos => true;
}
