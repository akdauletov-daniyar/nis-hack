import '../models/app_models.dart';

class RolePermissions {
  static bool canReviewReports(UserRole role) {
    return role == UserRole.government || role == UserRole.admin;
  }

  static bool canManageIncidents(UserRole role) {
    return role == UserRole.emergencyService;
  }

  static bool canManageUsers(UserRole role) {
    return role == UserRole.admin;
  }

  static bool canPublishAnnouncements(UserRole role) {
    return role == UserRole.government || role == UserRole.emergencyService;
  }

  static bool canModerateReports(UserRole role) {
    return role == UserRole.admin;
  }
}
