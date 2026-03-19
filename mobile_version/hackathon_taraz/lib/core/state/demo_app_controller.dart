import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/demo_seed.dart';
import '../models/app_models.dart';

final appControllerProvider =
    ChangeNotifierProvider<DemoAppController>((ref) => DemoAppController());

class DemoAppController extends ChangeNotifier {
  bool isAuthenticated = false;
  AppUser? currentUser;
  UserRole? activeRole;

  bool barrierFreeMode = true;
  String districtFilter = 'All districts';

  late List<Organization> organizations;
  late List<AppUser> managedUsers;
  late List<CityReport> reports;
  late List<Incident> incidents;
  late List<AppNotification> notifications;
  late List<Announcement> announcements;
  late List<MapObstacle> obstacles;

  DemoAppController() {
    organizations = DemoSeed.organizations();
    managedUsers = DemoSeed.managedUsers();
    reports = DemoSeed.reports();
    incidents = DemoSeed.incidents();
    notifications = DemoSeed.notifications();
    announcements = DemoSeed.announcements();
    obstacles = DemoSeed.obstacles();
  }

  List<UserRole> get availableRoles => currentUser?.roles ?? const [];

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.read).length;

  List<CityReport> get myReports {
    final userName = currentUser?.name;
    if (userName == null) {
      return const [];
    }
    return reports.where((report) => report.reporterName == userName).toList();
  }

  List<CityReport> get governmentFeed {
    return reports
        .where(
          (report) =>
              report.status != ReportStatus.closed &&
              report.status != ReportStatus.spam,
        )
        .toList();
  }

  List<CityReport> get moderationQueue {
    return reports
        .where(
          (report) =>
              report.status == ReportStatus.submitted ||
              report.status == ReportStatus.duplicate,
        )
        .toList();
  }

  List<Incident> get emergencyQueue {
    return incidents
        .where((incident) => incident.status != IncidentStatus.closed)
        .toList();
  }

  RoutePreview get activeRoutePreview {
    final profile = currentUser?.profile.mobilityType ?? MobilityType.general;

    if (!barrierFreeMode) {
      return const RoutePreview(
        title: 'Fastest route to City Hall',
        etaMinutes: 16,
        highlights: [
          'Shortest corridor through Central Avenue',
          'Main crossings prioritized',
        ],
        warnings: [
          'Includes stairs near the underpass',
        ],
      );
    }

    return switch (profile) {
      MobilityType.wheelchair => const RoutePreview(
          title: 'Barrier-free route to Clinic No. 4',
          etaMinutes: 19,
          highlights: [
            'Avoids stairs and steep slopes',
            'Uses curb-cut crossings',
            'Reroutes around broken clinic elevator',
          ],
          warnings: [
            'Temporary detour near North Station ramp',
          ],
        ),
      MobilityType.lowVision => const RoutePreview(
          title: 'High-clarity route to Akimat',
          etaMinutes: 17,
          highlights: [
            'Better lit streets',
            'Fewer unprotected crossings',
          ],
          warnings: [
            'Street light outage near East River crossing',
          ],
        ),
      MobilityType.elderly => const RoutePreview(
          title: 'Low-stress walking route',
          etaMinutes: 18,
          highlights: [
            'Minimizes stairs and long climbs',
            'Includes rest points near pharmacies',
          ],
          warnings: [
            'Construction narrows sidewalk on School Street',
          ],
        ),
      MobilityType.stroller => const RoutePreview(
          title: 'Stroller-friendly route to playground',
          etaMinutes: 15,
          highlights: [
            'Smooth curb ramps',
            'Wider pedestrian corridors',
          ],
          warnings: [
            'Temporary fence blocks direct crossing',
          ],
        ),
      MobilityType.general => const RoutePreview(
          title: 'Balanced route through Alatau Central',
          etaMinutes: 14,
          highlights: [
            'Combines speed and safety',
            'Avoids the busiest hazard cluster',
          ],
          warnings: [
            'Monitor smoke response near Bazaar Square',
          ],
        ),
    };
  }

  void signInDemo() {
    currentUser = DemoSeed.demoUser();
    isAuthenticated = true;
    activeRole = null;
    notifyListeners();
  }

  void signOut() {
    isAuthenticated = false;
    currentUser = null;
    activeRole = null;
    notifyListeners();
  }

  void selectRole(UserRole role) {
    activeRole = role;
    notifyListeners();
  }

  void switchRole(UserRole role) {
    activeRole = role;
    notifyListeners();
  }

  void setBarrierFreeMode(bool enabled) {
    barrierFreeMode = enabled;
    notifyListeners();
  }

  void setMobilityType(MobilityType mobilityType) {
    final user = currentUser;
    if (user == null) {
      return;
    }

    currentUser = user.copyWith(
      profile: user.profile.copyWith(mobilityType: mobilityType),
    );
    notifyListeners();
  }

  void submitReport({
    required String category,
    required String description,
    required UrgencyLevel urgency,
    required bool accessibilityRelated,
  }) {
    final user = currentUser;
    if (user == null) {
      return;
    }

    final reportId = 'report-${DateTime.now().millisecondsSinceEpoch}';
    final report = CityReport(
      id: reportId,
      title: '$category reported',
      category: category,
      description: description,
      status: ReportStatus.submitted,
      urgency: urgency,
      reporterName: user.name,
      district: user.district,
      location: 'Pinned from mobile app',
      createdAtLabel: 'Just now',
      accessibilityRelated: accessibilityRelated,
      photoLabel: 'camera_upload.jpg',
    );

    reports = [report, ...reports];

    if (urgency == UrgencyLevel.critical) {
      final incident = Incident(
        id: 'incident-${DateTime.now().microsecondsSinceEpoch}',
        title: category,
        status: IncidentStatus.newIncident,
        urgency: urgency,
        district: user.district,
        reporterName: user.name,
        assignedOrganizationId: 'org-ems',
        createdAtLabel: 'Just now',
        relatedReportId: report.id,
      );
      incidents = [incident, ...incidents];
    }

    _addNotification(
      title: 'Report submitted',
      body: '$category has been submitted and is awaiting review.',
    );
    notifyListeners();
  }

  void triggerSos() {
    final user = currentUser;
    if (user == null) {
      return;
    }

    final report = CityReport(
      id: 'report-sos-${DateTime.now().microsecondsSinceEpoch}',
      title: 'SOS emergency from mobile user',
      category: 'SOS',
      description:
          'Emergency assistance requested through the resident SOS flow.',
      status: ReportStatus.validated,
      urgency: UrgencyLevel.critical,
      reporterName: user.name,
      district: user.district,
      location: 'Live GPS pin',
      createdAtLabel: 'Just now',
      accessibilityRelated: false,
      assignedOrganizationId: 'org-ems',
    );

    final incident = Incident(
      id: 'incident-sos-${DateTime.now().microsecondsSinceEpoch}',
      title: 'SOS dispatch requested',
      status: IncidentStatus.newIncident,
      urgency: UrgencyLevel.critical,
      district: user.district,
      reporterName: user.name,
      assignedOrganizationId: 'org-ems',
      createdAtLabel: 'Just now',
      relatedReportId: report.id,
    );

    reports = [report, ...reports];
    incidents = [incident, ...incidents];
    _addNotification(
      title: 'SOS sent',
      body: 'Emergency services have been notified and can accept the incident.',
    );
    notifyListeners();
  }

  void progressIncident(String incidentId) {
    incidents = incidents.map((incident) {
      if (incident.id != incidentId) {
        return incident;
      }

      final nextStatus = switch (incident.status) {
        IncidentStatus.newIncident => IncidentStatus.assigned,
        IncidentStatus.assigned => IncidentStatus.crewEnRoute,
        IncidentStatus.crewEnRoute => IncidentStatus.onSite,
        IncidentStatus.onSite => IncidentStatus.resolved,
        IncidentStatus.resolved => IncidentStatus.closed,
        IncidentStatus.transferred => IncidentStatus.assigned,
        IncidentStatus.closed => IncidentStatus.closed,
      };

      return incident.copyWith(status: nextStatus);
    }).toList();

    _addNotification(
      title: 'Incident updated',
      body: 'Emergency incident workflow has advanced to the next status.',
    );
    notifyListeners();
  }

  void transferIncident(String incidentId) {
    incidents = incidents.map((incident) {
      if (incident.id != incidentId) {
        return incident;
      }

      return incident.copyWith(
        status: IncidentStatus.transferred,
        assignedOrganizationId: 'org-fire',
      );
    }).toList();
    _addNotification(
      title: 'Incident transferred',
      body: 'The incident has been reassigned to another emergency service.',
    );
    notifyListeners();
  }

  void validateReport(String reportId) {
    reports = _updateReportStatus(
      reportId,
      ReportStatus.validated,
      assignedOrganizationId: 'org-akimat',
    );
    _addNotification(
      title: 'Report validated',
      body: 'Government review confirmed the report and prepared assignment.',
    );
    notifyListeners();
  }

  void rejectReport(String reportId) {
    reports = _updateReportStatus(reportId, ReportStatus.rejected);
    _addNotification(
      title: 'Report rejected',
      body: 'The report was marked invalid or lacking enough evidence.',
    );
    notifyListeners();
  }

  void assignReport(String reportId, String organizationId) {
    reports = _updateReportStatus(
      reportId,
      ReportStatus.assigned,
      assignedOrganizationId: organizationId,
    );
    _addNotification(
      title: 'Report assigned',
      body: 'The city issue has been assigned to the responsible service.',
    );
    notifyListeners();
  }

  void publishAnnouncement(String title, String body) {
    final announcement = Announcement(
      id: 'ann-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      severity: 'Notice',
      district: districtFilter == 'All districts'
          ? currentUser?.district ?? 'Alatau Central'
          : districtFilter,
      createdAtLabel: 'Just now',
    );

    announcements = [announcement, ...announcements];
    _addNotification(
      title: 'Public announcement published',
      body: title,
    );
    notifyListeners();
  }

  void markNotificationRead(String notificationId) {
    notifications = notifications
        .map(
          (notification) => notification.id == notificationId
              ? notification.copyWith(read: true)
              : notification,
        )
        .toList();
    notifyListeners();
  }

  void moderateReport(String reportId, ReportStatus status) {
    reports = _updateReportStatus(reportId, status);
    _addNotification(
      title: 'Moderation update',
      body: 'A report has been marked as ${status.label.toLowerCase()}.',
    );
    notifyListeners();
  }

  void grantRoleToUser(String userId, UserRole role) {
    managedUsers = managedUsers.map((user) {
      if (user.id != userId || user.roles.contains(role)) {
        return user;
      }

      return user.copyWith(roles: [...user.roles, role]);
    }).toList();
    notifyListeners();
  }

  List<CityReport> _updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? assignedOrganizationId,
  }) {
    return reports.map((report) {
      if (report.id != reportId) {
        return report;
      }

      return report.copyWith(
        status: status,
        assignedOrganizationId:
            assignedOrganizationId ?? report.assignedOrganizationId,
      );
    }).toList();
  }

  void _addNotification({
    required String title,
    required String body,
  }) {
    notifications = [
      AppNotification(
        id: 'notif-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        body: body,
        createdAtLabel: 'Just now',
      ),
      ...notifications,
    ];
  }
}
