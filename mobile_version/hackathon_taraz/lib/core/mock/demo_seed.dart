import '../models/app_models.dart';

class DemoSeed {
  static AppUser demoUser() {
    return AppUser(
      id: 'user-1',
      name: 'Aruzhan Sadykova',
      email: 'aruzhan@alatau.city',
      phone: '+7 700 555 1188',
      district: 'Alatau Central',
      roles: const [
        UserRole.resident,
        UserRole.emergencyService,
        UserRole.government,
        UserRole.admin,
      ],
      profile: const AccessibilityProfile(
        mobilityType: MobilityType.wheelchair,
        avoidStairs: true,
        avoidSteepSlopes: true,
        avoidBrokenElevators: true,
      ),
      savedPlaces: const [
        'Home - Central Avenue 12',
        'City Hall',
        'Rehab Center',
      ],
    );
  }

  static List<Organization> organizations() {
    return const [
      Organization(
        id: 'org-ems',
        name: 'Alatau EMS',
        type: OrganizationType.emergency,
        districts: ['Alatau Central', 'North Station'],
      ),
      Organization(
        id: 'org-fire',
        name: 'Fire Response Unit',
        type: OrganizationType.emergency,
        districts: ['Alatau Central', 'East River'],
      ),
      Organization(
        id: 'org-akimat',
        name: 'Akimat Infrastructure Desk',
        type: OrganizationType.government,
        districts: ['Alatau Central', 'North Station', 'East River'],
      ),
      Organization(
        id: 'org-admin',
        name: 'Platform Administration',
        type: OrganizationType.admin,
        districts: ['All'],
      ),
    ];
  }

  static List<AppUser> managedUsers() {
    return [
      demoUser(),
      AppUser(
        id: 'user-2',
        name: 'Dauren Mukan',
        email: 'dauren@rescue.kz',
        phone: '+7 707 111 2233',
        district: 'North Station',
        roles: const [UserRole.resident, UserRole.emergencyService],
        profile: const AccessibilityProfile(
          mobilityType: MobilityType.general,
          avoidStairs: false,
          avoidSteepSlopes: false,
          avoidBrokenElevators: false,
        ),
        savedPlaces: const ['Station Depot'],
      ),
      AppUser(
        id: 'user-3',
        name: 'Madina Oraz',
        email: 'madina@akimat.kz',
        phone: '+7 701 222 3344',
        district: 'East River',
        roles: const [UserRole.resident, UserRole.government],
        profile: const AccessibilityProfile(
          mobilityType: MobilityType.general,
          avoidStairs: false,
          avoidSteepSlopes: false,
          avoidBrokenElevators: false,
        ),
        savedPlaces: const ['Akimat Branch'],
      ),
    ];
  }

  static List<CityReport> reports() {
    return const [
      CityReport(
        id: 'report-1',
        title: 'Broken elevator at district clinic',
        category: 'Accessibility barrier',
        description:
            'The main elevator has been out of service since morning, blocking access for wheelchair users.',
        status: ReportStatus.submitted,
        urgency: UrgencyLevel.high,
        reporterName: 'Aruzhan Sadykova',
        district: 'Alatau Central',
        location: 'Clinic No. 4',
        createdAtLabel: '12 min ago',
        accessibilityRelated: true,
        photoLabel: 'elevator_photo.jpg',
      ),
      CityReport(
        id: 'report-2',
        title: 'Flooded underpass near bus stop',
        category: 'Flooding',
        description:
            'Water is covering the entire ramp area, making the underpass unsafe.',
        status: ReportStatus.underReview,
        urgency: UrgencyLevel.critical,
        reporterName: 'Azamat K.',
        district: 'North Station',
        location: 'North Station Ramp',
        createdAtLabel: '28 min ago',
        accessibilityRelated: true,
      ),
      CityReport(
        id: 'report-3',
        title: 'Blocked sidewalk due to construction fence',
        category: 'Blocked sidewalk',
        description:
            'The temporary fence forces pedestrians into the roadway near school crossing.',
        status: ReportStatus.assigned,
        urgency: UrgencyLevel.medium,
        reporterName: 'Madina Oraz',
        district: 'East River',
        location: 'School Street 8',
        createdAtLabel: '1 h ago',
        accessibilityRelated: true,
        assignedOrganizationId: 'org-akimat',
      ),
      CityReport(
        id: 'report-4',
        title: 'Smoke visible from market kiosk',
        category: 'Fire / smoke',
        description:
            'Dark smoke visible from the back of the kiosk. Nearby pedestrians are gathering.',
        status: ReportStatus.validated,
        urgency: UrgencyLevel.critical,
        reporterName: 'Timur S.',
        district: 'Alatau Central',
        location: 'Bazaar Square',
        createdAtLabel: '5 min ago',
        accessibilityRelated: false,
        assignedOrganizationId: 'org-fire',
      ),
    ];
  }

  static List<Incident> incidents() {
    return const [
      Incident(
        id: 'incident-1',
        title: 'Smoke at Bazaar Square',
        status: IncidentStatus.assigned,
        urgency: UrgencyLevel.critical,
        district: 'Alatau Central',
        reporterName: 'Timur S.',
        assignedOrganizationId: 'org-fire',
        createdAtLabel: '5 min ago',
        relatedReportId: 'report-4',
      ),
      Incident(
        id: 'incident-2',
        title: 'Flooded ramp at North Station',
        status: IncidentStatus.newIncident,
        urgency: UrgencyLevel.critical,
        district: 'North Station',
        reporterName: 'Azamat K.',
        assignedOrganizationId: 'org-ems',
        createdAtLabel: '28 min ago',
        relatedReportId: 'report-2',
      ),
    ];
  }

  static List<AppNotification> notifications() {
    return const [
      AppNotification(
        id: 'notif-1',
        title: 'Report status updated',
        body: 'Broken elevator at district clinic is now under review.',
        createdAtLabel: '3 min ago',
      ),
      AppNotification(
        id: 'notif-2',
        title: 'Emergency alert',
        body: 'Avoid Bazaar Square while fire crews respond.',
        createdAtLabel: '7 min ago',
      ),
      AppNotification(
        id: 'notif-3',
        title: 'Route warning',
        body: 'North Station ramp is temporarily inaccessible.',
        createdAtLabel: '25 min ago',
        read: true,
      ),
    ];
  }

  static List<Announcement> announcements() {
    return const [
      Announcement(
        id: 'ann-1',
        title: 'Temporary access change near clinic',
        body: 'Use the west-side entrance while elevator repairs are underway.',
        severity: 'Advisory',
        district: 'Alatau Central',
        createdAtLabel: '18 min ago',
      ),
      Announcement(
        id: 'ann-2',
        title: 'Construction detour near school crossing',
        body: 'Pedestrians are advised to use the temporary protected crossing.',
        severity: 'Notice',
        district: 'East River',
        createdAtLabel: '1 h ago',
      ),
    ];
  }

  static List<MapObstacle> obstacles() {
    return const [
      MapObstacle(
        id: 'obs-1',
        title: 'Broken elevator',
        description: 'Clinic No. 4 vertical lift unavailable',
        affects: [MobilityType.wheelchair, MobilityType.elderly],
        active: true,
      ),
      MapObstacle(
        id: 'obs-2',
        title: 'Steep temporary ramp',
        description: 'Underpass access exceeds recommended slope',
        affects: [MobilityType.wheelchair, MobilityType.stroller],
        active: true,
      ),
      MapObstacle(
        id: 'obs-3',
        title: 'Low light crossing',
        description: 'Street light outage reduces visibility after sunset',
        affects: [MobilityType.lowVision],
        active: true,
      ),
    ];
  }
}
