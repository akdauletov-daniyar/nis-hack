enum UserRole { resident, emergencyService, government, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.resident => 'Resident',
        UserRole.emergencyService => 'Emergency Service',
        UserRole.government => 'Government / Akimat',
        UserRole.admin => 'Admin',
      };

  String get shortLabel => switch (this) {
        UserRole.resident => 'Resident',
        UserRole.emergencyService => 'Emergency',
        UserRole.government => 'Government',
        UserRole.admin => 'Admin',
      };

  String get description => switch (this) {
        UserRole.resident =>
          'Report problems, track safety, use barrier-free routing.',
        UserRole.emergencyService =>
          'Manage urgent incidents, field response, and responder status.',
        UserRole.government =>
          'Review city issues, assign services, and publish alerts.',
        UserRole.admin =>
          'Manage users, organizations, moderation, and categories.',
      };
}

enum OrganizationType { emergency, government, admin }

enum MobilityType { wheelchair, lowVision, elderly, stroller, general }

extension MobilityTypeX on MobilityType {
  String get label => switch (this) {
        MobilityType.wheelchair => 'Wheelchair',
        MobilityType.lowVision => 'Low vision',
        MobilityType.elderly => 'Elderly',
        MobilityType.stroller => 'Stroller',
        MobilityType.general => 'General',
      };
}

enum UrgencyLevel { low, medium, high, critical }

extension UrgencyLevelX on UrgencyLevel {
  String get label => switch (this) {
        UrgencyLevel.low => 'Low',
        UrgencyLevel.medium => 'Medium',
        UrgencyLevel.high => 'High',
        UrgencyLevel.critical => 'Critical',
      };
}

enum ReportStatus {
  draft,
  submitted,
  underReview,
  validated,
  assigned,
  inProgress,
  resolved,
  closed,
  rejected,
  duplicate,
  spam,
}

extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
        ReportStatus.draft => 'Draft',
        ReportStatus.submitted => 'Submitted',
        ReportStatus.underReview => 'Under review',
        ReportStatus.validated => 'Validated',
        ReportStatus.assigned => 'Assigned',
        ReportStatus.inProgress => 'In progress',
        ReportStatus.resolved => 'Resolved',
        ReportStatus.closed => 'Closed',
        ReportStatus.rejected => 'Rejected',
        ReportStatus.duplicate => 'Duplicate',
        ReportStatus.spam => 'Spam',
      };
}

enum IncidentStatus {
  newIncident,
  assigned,
  crewEnRoute,
  onSite,
  resolved,
  transferred,
  closed,
}

extension IncidentStatusX on IncidentStatus {
  String get label => switch (this) {
        IncidentStatus.newIncident => 'New',
        IncidentStatus.assigned => 'Assigned',
        IncidentStatus.crewEnRoute => 'Crew en route',
        IncidentStatus.onSite => 'On site',
        IncidentStatus.resolved => 'Resolved',
        IncidentStatus.transferred => 'Transferred',
        IncidentStatus.closed => 'Closed',
      };
}

class AccessibilityProfile {
  const AccessibilityProfile({
    required this.mobilityType,
    required this.avoidStairs,
    required this.avoidSteepSlopes,
    required this.avoidBrokenElevators,
  });

  final MobilityType mobilityType;
  final bool avoidStairs;
  final bool avoidSteepSlopes;
  final bool avoidBrokenElevators;

  AccessibilityProfile copyWith({
    MobilityType? mobilityType,
    bool? avoidStairs,
    bool? avoidSteepSlopes,
    bool? avoidBrokenElevators,
  }) {
    return AccessibilityProfile(
      mobilityType: mobilityType ?? this.mobilityType,
      avoidStairs: avoidStairs ?? this.avoidStairs,
      avoidSteepSlopes: avoidSteepSlopes ?? this.avoidSteepSlopes,
      avoidBrokenElevators:
          avoidBrokenElevators ?? this.avoidBrokenElevators,
    );
  }
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.districts,
  });

  final String id;
  final String name;
  final OrganizationType type;
  final List<String> districts;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.district,
    required this.roles,
    required this.profile,
    required this.savedPlaces,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String district;
  final List<UserRole> roles;
  final AccessibilityProfile profile;
  final List<String> savedPlaces;

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? district,
    List<UserRole>? roles,
    AccessibilityProfile? profile,
    List<String>? savedPlaces,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      district: district ?? this.district,
      roles: roles ?? this.roles,
      profile: profile ?? this.profile,
      savedPlaces: savedPlaces ?? this.savedPlaces,
    );
  }
}

class CityReport {
  const CityReport({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.urgency,
    required this.reporterName,
    required this.district,
    required this.location,
    required this.createdAtLabel,
    required this.accessibilityRelated,
    this.assignedOrganizationId,
    this.photoLabel,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final ReportStatus status;
  final UrgencyLevel urgency;
  final String reporterName;
  final String district;
  final String location;
  final String createdAtLabel;
  final bool accessibilityRelated;
  final String? assignedOrganizationId;
  final String? photoLabel;

  CityReport copyWith({
    String? title,
    String? category,
    String? description,
    ReportStatus? status,
    UrgencyLevel? urgency,
    String? reporterName,
    String? district,
    String? location,
    String? createdAtLabel,
    bool? accessibilityRelated,
    String? assignedOrganizationId,
    String? photoLabel,
  }) {
    return CityReport(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      reporterName: reporterName ?? this.reporterName,
      district: district ?? this.district,
      location: location ?? this.location,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      accessibilityRelated:
          accessibilityRelated ?? this.accessibilityRelated,
      assignedOrganizationId:
          assignedOrganizationId ?? this.assignedOrganizationId,
      photoLabel: photoLabel ?? this.photoLabel,
    );
  }
}

class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.status,
    required this.urgency,
    required this.district,
    required this.reporterName,
    required this.assignedOrganizationId,
    required this.createdAtLabel,
    this.relatedReportId,
  });

  final String id;
  final String title;
  final IncidentStatus status;
  final UrgencyLevel urgency;
  final String district;
  final String reporterName;
  final String assignedOrganizationId;
  final String createdAtLabel;
  final String? relatedReportId;

  Incident copyWith({
    String? title,
    IncidentStatus? status,
    UrgencyLevel? urgency,
    String? district,
    String? reporterName,
    String? assignedOrganizationId,
    String? createdAtLabel,
    String? relatedReportId,
  }) {
    return Incident(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      district: district ?? this.district,
      reporterName: reporterName ?? this.reporterName,
      assignedOrganizationId:
          assignedOrganizationId ?? this.assignedOrganizationId,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      relatedReportId: relatedReportId ?? this.relatedReportId,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAtLabel,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String createdAtLabel;
  final bool read;

  AppNotification copyWith({
    String? title,
    String? body,
    String? createdAtLabel,
    bool? read,
  }) {
    return AppNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      read: read ?? this.read,
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.district,
    required this.createdAtLabel,
  });

  final String id;
  final String title;
  final String body;
  final String severity;
  final String district;
  final String createdAtLabel;
}

class MapObstacle {
  const MapObstacle({
    required this.id,
    required this.title,
    required this.description,
    required this.affects,
    required this.active,
  });

  final String id;
  final String title;
  final String description;
  final List<MobilityType> affects;
  final bool active;
}

class RoutePreview {
  const RoutePreview({
    required this.title,
    required this.etaMinutes,
    required this.highlights,
    required this.warnings,
  });

  final String title;
  final int etaMinutes;
  final List<String> highlights;
  final List<String> warnings;
}
