enum UserRole { resident, emergencyService, government, admin }

class ActionResult {
  const ActionResult._({
    required this.success,
    required this.message,
  });

  const ActionResult.success(String message)
    : this._(success: true, message: message);

  const ActionResult.failure(String message)
    : this._(success: false, message: message);

  final bool success;
  final String message;
}

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

  String get dbValue => switch (this) {
    UserRole.resident => 'resident',
    UserRole.emergencyService => 'emergency_service',
    UserRole.government => 'government',
    UserRole.admin => 'admin',
  };
}

UserRole userRoleFromDb(String? value) {
  return switch (value) {
    'resident' => UserRole.resident,
    'emergency_service' => UserRole.emergencyService,
    'government' => UserRole.government,
    'admin' => UserRole.admin,
    _ => UserRole.resident,
  };
}

enum OrganizationType { emergency, government, admin }

extension OrganizationTypeX on OrganizationType {
  String get dbValue => switch (this) {
    OrganizationType.emergency => 'emergency',
    OrganizationType.government => 'government',
    OrganizationType.admin => 'admin',
  };
}

OrganizationType organizationTypeFromDb(String? value) {
  return switch (value) {
    'emergency' => OrganizationType.emergency,
    'government' => OrganizationType.government,
    'admin' => OrganizationType.admin,
    _ => OrganizationType.government,
  };
}

enum MobilityType { wheelchair, lowVision, elderly, stroller, general }

extension MobilityTypeX on MobilityType {
  String get label => switch (this) {
    MobilityType.wheelchair => 'Wheelchair',
    MobilityType.lowVision => 'Low vision',
    MobilityType.elderly => 'Elderly',
    MobilityType.stroller => 'Stroller',
    MobilityType.general => 'General',
  };

  String get dbValue => switch (this) {
    MobilityType.wheelchair => 'wheelchair',
    MobilityType.lowVision => 'low_vision',
    MobilityType.elderly => 'elderly',
    MobilityType.stroller => 'stroller',
    MobilityType.general => 'general',
  };
}

enum SosType { medical, fire, accident, safety, accessibility }

extension SosTypeX on SosType {
  String get label => switch (this) {
    SosType.medical => 'Medical',
    SosType.fire => 'Fire / Smoke',
    SosType.accident => 'Accident',
    SosType.safety => 'Suspicious situation',
    SosType.accessibility => 'Accessibility emergency',
  };
}

enum MapLayer { reports, incidents, barriers }

MobilityType mobilityTypeFromDb(String? value) {
  return switch (value) {
    'wheelchair' => MobilityType.wheelchair,
    'low_vision' => MobilityType.lowVision,
    'elderly' => MobilityType.elderly,
    'stroller' => MobilityType.stroller,
    'general' => MobilityType.general,
    _ => MobilityType.general,
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

  String get dbValue => name;
}

UrgencyLevel urgencyLevelFromDb(String? value) {
  return switch (value) {
    'low' => UrgencyLevel.low,
    'medium' => UrgencyLevel.medium,
    'high' => UrgencyLevel.high,
    'critical' => UrgencyLevel.critical,
    _ => UrgencyLevel.medium,
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

  String get dbValue => switch (this) {
    ReportStatus.draft => 'draft',
    ReportStatus.submitted => 'submitted',
    ReportStatus.underReview => 'under_review',
    ReportStatus.validated => 'validated',
    ReportStatus.assigned => 'assigned',
    ReportStatus.inProgress => 'in_progress',
    ReportStatus.resolved => 'resolved',
    ReportStatus.closed => 'closed',
    ReportStatus.rejected => 'rejected',
    ReportStatus.duplicate => 'duplicate',
    ReportStatus.spam => 'spam',
  };

  bool get isOperationallyOpen => switch (this) {
    ReportStatus.submitted ||
    ReportStatus.underReview ||
    ReportStatus.validated ||
    ReportStatus.assigned ||
    ReportStatus.inProgress => true,
    ReportStatus.draft ||
    ReportStatus.resolved ||
    ReportStatus.closed ||
    ReportStatus.rejected ||
    ReportStatus.duplicate ||
    ReportStatus.spam => false,
  };
}

ReportStatus reportStatusFromDb(String? value) {
  return switch (value) {
    'draft' => ReportStatus.draft,
    'submitted' => ReportStatus.submitted,
    'under_review' => ReportStatus.underReview,
    'validated' => ReportStatus.validated,
    'assigned' => ReportStatus.assigned,
    'in_progress' => ReportStatus.inProgress,
    'resolved' => ReportStatus.resolved,
    'closed' => ReportStatus.closed,
    'rejected' => ReportStatus.rejected,
    'duplicate' => ReportStatus.duplicate,
    'spam' => ReportStatus.spam,
    _ => ReportStatus.submitted,
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

  String get dbValue => switch (this) {
    IncidentStatus.newIncident => 'new',
    IncidentStatus.assigned => 'assigned',
    IncidentStatus.crewEnRoute => 'crew_en_route',
    IncidentStatus.onSite => 'on_site',
    IncidentStatus.resolved => 'resolved',
    IncidentStatus.transferred => 'transferred',
    IncidentStatus.closed => 'closed',
  };
}

IncidentStatus incidentStatusFromDb(String? value) {
  return switch (value) {
    'new' => IncidentStatus.newIncident,
    'assigned' => IncidentStatus.assigned,
    'crew_en_route' => IncidentStatus.crewEnRoute,
    'on_site' => IncidentStatus.onSite,
    'resolved' => IncidentStatus.resolved,
    'transferred' => IncidentStatus.transferred,
    'closed' => IncidentStatus.closed,
    _ => IncidentStatus.newIncident,
  };
}

class AccessibilityProfile {
  const AccessibilityProfile({
    required this.mobilityType,
    required this.avoidStairs,
    required this.avoidSteepSlopes,
    required this.avoidBrokenElevators,
  });

  factory AccessibilityProfile.fromProfileMap(Map<String, dynamic> map) {
    return AccessibilityProfile(
      mobilityType: mobilityTypeFromDb(map['mobility_type'] as String?),
      avoidStairs: map['avoid_stairs'] as bool? ?? true,
      avoidSteepSlopes: map['avoid_steep_slopes'] as bool? ?? true,
      avoidBrokenElevators: map['avoid_broken_elevators'] as bool? ?? true,
    );
  }

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
      avoidBrokenElevators: avoidBrokenElevators ?? this.avoidBrokenElevators,
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

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'].toString(),
      name: map['name'] as String? ?? 'Organization',
      type: organizationTypeFromDb(map['type'] as String?),
      districts: List<String>.from(map['districts'] as List? ?? const []),
    );
  }

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
    required this.reporterUserId,
    required this.reporterName,
    required this.reporterPhone,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.urgency,
    required this.district,
    required this.location,
    required this.createdAtLabel,
    required this.accessibilityRelated,
    this.assignedOrganizationId,
    this.photoLabel,
    this.latitude,
    this.longitude,
  });

  factory CityReport.fromMap(Map<String, dynamic> map) {
    return CityReport(
      id: map['id'].toString(),
      reporterUserId: map['reporter_user_id'].toString(),
      reporterName: map['reporter_name'] as String? ?? 'Resident',
      reporterPhone: map['reporter_phone'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled report',
      category: map['category'] as String? ?? 'General',
      description: map['description'] as String? ?? '',
      status: reportStatusFromDb(map['status'] as String?),
      urgency: urgencyLevelFromDb(map['urgency'] as String?),
      district: map['district'] as String? ?? '',
      location: map['location_text'] as String? ?? 'Unknown location',
      createdAtLabel: formatRelativeTime(map['created_at']),
      accessibilityRelated: map['accessibility_related'] as bool? ?? false,
      assignedOrganizationId: map['assigned_organization_id']?.toString(),
      photoLabel: map['photo_url'] as String?,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
    );
  }

  final String id;
  final String reporterUserId;
  final String reporterName;
  final String reporterPhone;
  final String title;
  final String category;
  final String description;
  final ReportStatus status;
  final UrgencyLevel urgency;
  final String district;
  final String location;
  final String createdAtLabel;
  final bool accessibilityRelated;
  final String? assignedOrganizationId;
  final String? photoLabel;
  final double? latitude;
  final double? longitude;

  CityReport copyWith({
    String? title,
    String? category,
    String? description,
    ReportStatus? status,
    UrgencyLevel? urgency,
    String? reporterName,
    String? reporterPhone,
    String? district,
    String? location,
    String? createdAtLabel,
    bool? accessibilityRelated,
    String? assignedOrganizationId,
    String? photoLabel,
    double? latitude,
    double? longitude,
  }) {
    return CityReport(
      id: id,
      reporterUserId: reporterUserId,
      reporterName: reporterName ?? this.reporterName,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      district: district ?? this.district,
      location: location ?? this.location,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      accessibilityRelated: accessibilityRelated ?? this.accessibilityRelated,
      assignedOrganizationId:
          assignedOrganizationId ?? this.assignedOrganizationId,
      photoLabel: photoLabel ?? this.photoLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
    required this.reporterPhone,
    required this.assignedOrganizationId,
    required this.createdAtLabel,
    this.relatedReportId,
    this.latitude,
    this.longitude,
  });

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'].toString(),
      title: map['title'] as String? ?? 'Untitled incident',
      status: incidentStatusFromDb(map['status'] as String?),
      urgency: urgencyLevelFromDb(map['urgency'] as String?),
      district: map['district'] as String? ?? '',
      reporterName: map['reporter_name'] as String? ?? 'Resident',
      reporterPhone: map['reporter_phone'] as String? ?? '',
      assignedOrganizationId: map['assigned_organization_id']?.toString() ?? '',
      createdAtLabel: formatRelativeTime(map['created_at']),
      relatedReportId: map['report_id']?.toString(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
    );
  }

  final String id;
  final String title;
  final IncidentStatus status;
  final UrgencyLevel urgency;
  final String district;
  final String reporterName;
  final String reporterPhone;
  final String assignedOrganizationId;
  final String createdAtLabel;
  final String? relatedReportId;
  final double? latitude;
  final double? longitude;

  Incident copyWith({
    String? title,
    IncidentStatus? status,
    UrgencyLevel? urgency,
    String? district,
    String? reporterName,
    String? reporterPhone,
    String? assignedOrganizationId,
    String? createdAtLabel,
    String? relatedReportId,
    double? latitude,
    double? longitude,
  }) {
    return Incident(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      district: district ?? this.district,
      reporterName: reporterName ?? this.reporterName,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      assignedOrganizationId:
          assignedOrganizationId ?? this.assignedOrganizationId,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      relatedReportId: relatedReportId ?? this.relatedReportId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'].toString(),
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      createdAtLabel: formatRelativeTime(map['created_at']),
      read: map['is_read'] as bool? ?? false,
    );
  }

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

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'].toString(),
      title: map['title'] as String? ?? 'Announcement',
      body: map['body'] as String? ?? '',
      severity: map['severity'] as String? ?? 'Notice',
      district: map['district'] as String? ?? '',
      createdAtLabel: formatRelativeTime(map['created_at']),
    );
  }

  final String id;
  final String title;
  final String body;
  final String severity;
  final String district;
  final String createdAtLabel;
}

class CityLandmark {
  const CityLandmark({
    required this.label,
    required this.district,
    required this.description,
  });

  final String label;
  final String district;
  final String description;
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

class RouteLeg {
  const RouteLeg({
    required this.title,
    required this.etaMinutes,
    required this.highlights,
    required this.warnings,
    required this.district,
  });

  final String title;
  final int etaMinutes;
  final List<String> highlights;
  final List<String> warnings;
  final String district;
}

class RoutePlan {
  const RoutePlan({
    required this.primaryRoute,
    this.alternativeRoute,
    required this.safetyHint,
    required this.dataConfidence,
    this.fallbackMessage,
  });

  final RouteLeg primaryRoute;
  final RouteLeg? alternativeRoute;
  final String safetyHint;
  final String dataConfidence;
  final String? fallbackMessage;
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

String formatRelativeTime(dynamic rawTimestamp) {
  if (rawTimestamp == null) {
    return 'Just now';
  }

  final timestamp = DateTime.tryParse(rawTimestamp.toString());
  if (timestamp == null) {
    return 'Just now';
  }

  final diff = DateTime.now().difference(timestamp.toLocal());
  if (diff.inSeconds < 60) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} h ago';
  }
  return '${diff.inDays} d ago';
}
