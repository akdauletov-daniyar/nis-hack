import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../models/app_models.dart';

final appControllerProvider =
    ChangeNotifierProvider<AppController>((ref) => AppController());

class AppController extends ChangeNotifier {
  AppController() {
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      unawaited(_hydrateSession());
    });
    unawaited(_hydrateSession());
  }

  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  final Random _random = Random();

  bool isHydrating = true;
  bool isBusy = false;
  String? authError;
  String? authMessage;
  String? dataError;

  AppUser? currentUser;
  UserRole? activeRole;

  bool barrierFreeMode = true;
  String districtFilter = 'All districts';

  List<Organization> organizations = const [];
  List<AppUser> managedUsers = const [];
  List<CityReport> reports = const [];
  List<Incident> incidents = const [];
  List<AppNotification> notifications = const [];
  List<Announcement> announcements = const [];

  bool get isAuthenticated => _client.auth.currentSession != null;

  List<UserRole> get availableRoles => currentUser?.roles ?? const [];

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.read).length;

  List<CityReport> get myReports {
    final userId = currentUser?.id;
    if (userId == null) {
      return const [];
    }
    return reports.where((report) => report.reporterUserId == userId).toList();
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

  List<MapObstacle> get obstacles {
    return reports
        .where(
          (report) =>
              report.accessibilityRelated &&
              report.status != ReportStatus.closed &&
              report.status != ReportStatus.rejected &&
              report.status != ReportStatus.spam,
        )
        .map(
          (report) => MapObstacle(
            id: report.id,
            title: report.title,
            description: '${report.category} • ${report.location}',
            affects: _affectedProfiles(report.category),
            active: true,
          ),
        )
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
        warnings: ['Includes stairs near the underpass'],
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
          warnings: ['Temporary detour near North Station ramp'],
        ),
      MobilityType.lowVision => const RoutePreview(
          title: 'High-clarity route to Akimat',
          etaMinutes: 17,
          highlights: [
            'Better lit streets',
            'Fewer unprotected crossings',
          ],
          warnings: ['Street light outage near East River crossing'],
        ),
      MobilityType.elderly => const RoutePreview(
          title: 'Low-stress walking route',
          etaMinutes: 18,
          highlights: [
            'Minimizes stairs and long climbs',
            'Includes rest points near pharmacies',
          ],
          warnings: ['Construction narrows sidewalk on School Street'],
        ),
      MobilityType.stroller => const RoutePreview(
          title: 'Stroller-friendly route to playground',
          etaMinutes: 15,
          highlights: [
            'Smooth curb ramps',
            'Wider pedestrian corridors',
          ],
          warnings: ['Temporary fence blocks direct crossing'],
        ),
      MobilityType.general => const RoutePreview(
          title: 'Balanced route through Alatau Central',
          etaMinutes: 14,
          highlights: [
            'Combines speed and safety',
            'Avoids the busiest hazard cluster',
          ],
          warnings: ['Monitor smoke response near Bazaar Square'],
        ),
    };
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    authError = null;
    authMessage = null;
    notifyListeners();

    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      authMessage = 'Signed in successfully.';
    } on AuthException catch (error) {
      authError = error.message;
    } catch (error) {
      authError = error.toString();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> registerWithEmail({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String district,
  }) async {
    _setBusy(true);
    authError = null;
    authMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'district': district,
          'mobility_type': MobilityType.general.dbValue,
        },
      );

      if (response.session == null) {
        authMessage =
            'Registration successful. Confirm your email, then sign in.';
      } else {
        authMessage = 'Account created successfully.';
      }
    } on AuthException catch (error) {
      authError = error.message;
    } catch (error) {
      authError = error.toString();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _client.auth.signOut();
      currentUser = null;
      activeRole = null;
      organizations = const [];
      managedUsers = const [];
      reports = const [];
      incidents = const [];
      notifications = const [];
      announcements = const [];
      dataError = null;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  void selectRole(UserRole role) {
    activeRole = role;
    notifyListeners();
  }

  void switchRole(UserRole role) {
    activeRole = role;
    notifyListeners();
  }

  void dismissMessage() {
    authError = null;
    authMessage = null;
    dataError = null;
    notifyListeners();
  }

  Future<void> setBarrierFreeMode(bool enabled) async {
    barrierFreeMode = enabled;
    notifyListeners();
  }

  Future<void> setMobilityType(MobilityType mobilityType) async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    _setBusy(true);
    try {
      await _client.from('profiles').update({
        'mobility_type': mobilityType.dbValue,
      }).eq('id', user.id);

      currentUser = user.copyWith(
        profile: user.profile.copyWith(mobilityType: mobilityType),
      );
      authMessage = 'Accessibility profile updated.';
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> submitReport({
    required String category,
    required String description,
    required UrgencyLevel urgency,
    required bool accessibilityRelated,
  }) async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    _setBusy(true);
    try {
      final coords = _coordinatesForDistrict(user.district);
      final insertedReport = await _client
          .from('reports')
          .insert({
            'reporter_user_id': user.id,
            'reporter_name': user.name,
            'reporter_phone': user.phone,
            'title': '$category reported',
            'category': category,
            'description': description,
            'status': ReportStatus.submitted.dbValue,
            'urgency': urgency.dbValue,
            'district': user.district,
            'location_text': 'Submitted from mobile app',
            'latitude': coords.$1,
            'longitude': coords.$2,
            'accessibility_related': accessibilityRelated,
          })
          .select()
          .single();

      await _notifyUser(
        user.id,
        title: 'Report submitted',
        body: '$category has been submitted for review.',
      );

      if (urgency == UrgencyLevel.critical) {
        await _client.from('incidents').insert({
          'report_id': insertedReport['id'],
          'created_by_user_id': user.id,
          'title': category,
          'status': IncidentStatus.newIncident.dbValue,
          'urgency': urgency.dbValue,
          'district': user.district,
          'reporter_name': user.name,
          'reporter_phone': user.phone,
          'assigned_organization_id': AppConstants.emsOrganizationId,
          'latitude': coords.$1,
          'longitude': coords.$2,
        });
      }

      authMessage = 'Report submitted successfully.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> triggerSos() async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    _setBusy(true);
    try {
      final coords = _coordinatesForDistrict(user.district);
      final report = await _client
          .from('reports')
          .insert({
            'reporter_user_id': user.id,
            'reporter_name': user.name,
            'reporter_phone': user.phone,
            'title': 'SOS emergency from mobile user',
            'category': 'SOS',
            'description':
                'Emergency assistance requested through the resident SOS flow.',
            'status': ReportStatus.validated.dbValue,
            'urgency': UrgencyLevel.critical.dbValue,
            'district': user.district,
            'location_text': 'Live GPS pin',
            'latitude': coords.$1,
            'longitude': coords.$2,
            'accessibility_related': false,
            'assigned_organization_id': AppConstants.emsOrganizationId,
          })
          .select()
          .single();

      await _client.from('incidents').insert({
        'report_id': report['id'],
        'created_by_user_id': user.id,
        'title': 'SOS dispatch requested',
        'status': IncidentStatus.newIncident.dbValue,
        'urgency': UrgencyLevel.critical.dbValue,
        'district': user.district,
        'reporter_name': user.name,
        'reporter_phone': user.phone,
        'assigned_organization_id': AppConstants.emsOrganizationId,
        'latitude': coords.$1,
        'longitude': coords.$2,
      });

      await _notifyUser(
        user.id,
        title: 'SOS sent',
        body: 'Emergency services have been notified.',
      );
      authMessage = 'SOS sent successfully.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> progressIncident(String incidentId) async {
    final incident = incidents.where((item) => item.id == incidentId).firstOrNull;
    if (incident == null) {
      return;
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

    _setBusy(true);
    try {
      await _client
          .from('incidents')
          .update({'status': nextStatus.dbValue}).eq('id', incidentId);

      if (incident.relatedReportId != null) {
        final reportStatus = switch (nextStatus) {
          IncidentStatus.assigned ||
          IncidentStatus.crewEnRoute ||
          IncidentStatus.onSite =>
            ReportStatus.inProgress,
          IncidentStatus.resolved => ReportStatus.resolved,
          IncidentStatus.closed => ReportStatus.closed,
          IncidentStatus.transferred => ReportStatus.assigned,
          IncidentStatus.newIncident => ReportStatus.validated,
        };

        await _client.from('reports').update({
          'status': reportStatus.dbValue,
        }).eq('id', incident.relatedReportId!);
      }

      await _notifyReporterForIncident(
        incident,
        'Incident updated',
        'Emergency response moved to ${nextStatus.label.toLowerCase()}.',
      );

      authMessage = 'Incident updated.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> transferIncident(String incidentId) async {
    final incident = incidents.where((item) => item.id == incidentId).firstOrNull;
    if (incident == null) {
      return;
    }

    _setBusy(true);
    try {
      await _client.from('incidents').update({
        'status': IncidentStatus.transferred.dbValue,
        'assigned_organization_id': AppConstants.fireOrganizationId,
      }).eq('id', incidentId);

      if (incident.relatedReportId != null) {
        await _client.from('reports').update({
          'status': ReportStatus.assigned.dbValue,
          'assigned_organization_id': AppConstants.fireOrganizationId,
        }).eq('id', incident.relatedReportId!);
      }

      await _notifyReporterForIncident(
        incident,
        'Incident transferred',
        'The incident has been transferred to another service.',
      );

      authMessage = 'Incident transferred.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> validateReport(String reportId) async {
    await _updateReportStatus(
      reportId,
      ReportStatus.validated,
      organizationId: AppConstants.akimatOrganizationId,
      notificationTitle: 'Report validated',
      notificationBody: 'Your report has been validated by the city team.',
    );
  }

  Future<void> rejectReport(String reportId) async {
    await _updateReportStatus(
      reportId,
      ReportStatus.rejected,
      notificationTitle: 'Report rejected',
      notificationBody: 'Your report was rejected after review.',
    );
  }

  Future<void> assignReport(String reportId, String organizationId) async {
    await _updateReportStatus(
      reportId,
      ReportStatus.assigned,
      organizationId: organizationId,
      notificationTitle: 'Report assigned',
      notificationBody:
          'Your report has been assigned to a responsible organization.',
    );
  }

  Future<void> publishAnnouncement(String title, String body) async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    _setBusy(true);
    try {
      await _client.from('announcements').insert({
        'title': title,
        'body': body,
        'severity': 'Notice',
        'district': districtFilter == 'All districts'
            ? user.district
            : districtFilter,
        'author_user_id': user.id,
      });

      await _notifyUser(
        user.id,
        title: 'Announcement published',
        body: title,
      );
      authMessage = 'Announcement published.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', user.id);
      notifications = notifications
          .map(
            (notification) => notification.id == notificationId
                ? notification.copyWith(read: true)
                : notification,
          )
          .toList();
      notifyListeners();
    } catch (_) {
      // Keep the current state if the notification update fails.
    }
  }

  Future<void> moderateReport(String reportId, ReportStatus status) async {
    await _updateReportStatus(
      reportId,
      status,
      notificationTitle: 'Report moderation update',
      notificationBody: 'A moderator updated the report status to ${status.label}.',
    );
  }

  Future<void> grantRoleToUser(String userId, UserRole role) async {
    _setBusy(true);
    try {
      await _client.from('role_assignments').upsert({
        'user_id': userId,
        'role': role.dbValue,
        'organization_id': _organizationIdForRole(role),
      }, onConflict: 'user_id,role');

      await _notifyUser(
        userId,
        title: 'Role granted',
        body: 'You have been granted ${role.label} access.',
      );
      authMessage = '${role.label} granted successfully.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> refreshData() => _loadData();

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _hydrateSession() async {
    isHydrating = true;
    dataError = null;
    notifyListeners();

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      currentUser = null;
      activeRole = null;
      organizations = const [];
      managedUsers = const [];
      reports = const [];
      incidents = const [];
      notifications = const [];
      announcements = const [];
      isHydrating = false;
      notifyListeners();
      return;
    }

    try {
      await _ensureProfile(authUser);
      await _loadCurrentUser(authUser.id);
      await _loadData();
      if (availableRoles.length == 1) {
        activeRole = availableRoles.first;
      } else if (activeRole != null && !availableRoles.contains(activeRole)) {
        activeRole = null;
      }
    } catch (error) {
      dataError = _friendlyError(error);
      currentUser = null;
      activeRole = null;
    } finally {
      isHydrating = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser(String userId) async {
    final profileRows =
        _asMapList(await _client.from('profiles').select().eq('id', userId));
    if (profileRows.isEmpty) {
      throw StateError(
        'Profile data is missing for this account. '
        'If the database was created from an older schema, rerun the updated '
        'supabase/schema.sql and sign in again.',
      );
    }

    final profile = profileRows.first;
    final roleRows = await _client
        .from('role_assignments')
        .select('role')
        .eq('user_id', userId)
        .eq('active', true);
    final savedPlaceRows = await _client
        .from('saved_places')
        .select('label')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    final roles = _asMapList(roleRows)
        .map((row) => userRoleFromDb(row['role'] as String?))
        .toSet()
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    currentUser = AppUser(
      id: profile['id'].toString(),
      name: profile['full_name'] as String? ?? 'Resident',
      email: profile['email'] as String? ?? '',
      phone: profile['phone'] as String? ?? '',
      district: profile['district'] as String? ?? AppConstants.defaultDistrict,
      roles: roles,
      profile: AccessibilityProfile.fromProfileMap(profile),
      savedPlaces: _asMapList(savedPlaceRows)
          .map((row) => row['label'] as String? ?? '')
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _loadData() async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    final organizationRows = await _client
        .from('organizations')
        .select()
        .order('name', ascending: true);
    final reportRows =
        await _client.from('reports').select().order('created_at', ascending: false);
    final incidentRows = await _client
        .from('incidents')
        .select()
        .order('created_at', ascending: false);
    final announcementRows = await _client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    final notificationRows = await _client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    organizations = _asMapList(organizationRows)
        .map(Organization.fromMap)
        .toList();
    reports = _asMapList(reportRows).map(CityReport.fromMap).toList();
    incidents = _asMapList(incidentRows).map(Incident.fromMap).toList();
    announcements =
        _asMapList(announcementRows).map(Announcement.fromMap).toList();
    notifications =
        _asMapList(notificationRows).map(AppNotification.fromMap).toList();

    if (availableRoles.contains(UserRole.admin)) {
      managedUsers = await _loadManagedUsers();
    } else {
      managedUsers = const [];
    }
  }

  Future<List<AppUser>> _loadManagedUsers() async {
    final profileRows =
        await _client.from('profiles').select().order('created_at', ascending: false);
    final roleRows =
        await _client.from('role_assignments').select().eq('active', true);
    final savedPlaceRows = await _client.from('saved_places').select();

    final rolesByUserId = <String, List<UserRole>>{};
    for (final row in _asMapList(roleRows)) {
      final userId = row['user_id'].toString();
      rolesByUserId.putIfAbsent(userId, () => []);
      rolesByUserId[userId]!.add(userRoleFromDb(row['role'] as String?));
    }

    final savedPlacesByUserId = <String, List<String>>{};
    for (final row in _asMapList(savedPlaceRows)) {
      final userId = row['user_id'].toString();
      savedPlacesByUserId.putIfAbsent(userId, () => []);
      final label = row['label'] as String? ?? '';
      if (label.isNotEmpty) {
        savedPlacesByUserId[userId]!.add(label);
      }
    }

    return _asMapList(profileRows).map((row) {
      final userId = row['id'].toString();
      final roles = (rolesByUserId[userId] ?? const [UserRole.resident]).toSet()
          .toList()
        ..sort((left, right) => left.index.compareTo(right.index));

      return AppUser(
        id: userId,
        name: row['full_name'] as String? ?? 'Resident',
        email: row['email'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        district: row['district'] as String? ?? AppConstants.defaultDistrict,
        roles: roles,
        profile: AccessibilityProfile.fromProfileMap(row),
        savedPlaces: savedPlacesByUserId[userId] ?? const [],
      );
    }).toList();
  }

  Future<void> _ensureProfile(User authUser) async {
    try {
      await _client.from('profiles').upsert({
        'id': authUser.id,
        'email': authUser.email,
        'full_name': authUser.userMetadata?['full_name'] as String? ?? '',
        'phone': authUser.userMetadata?['phone'] as String? ?? '',
        'district': authUser.userMetadata?['district'] as String? ??
            AppConstants.defaultDistrict,
        'mobility_type':
            authUser.userMetadata?['mobility_type'] as String? ?? 'general',
      }, onConflict: 'id');
    } on PostgrestException catch (error) {
      if (_hasLegacyProfilesSchema(error.message)) {
        rethrow;
      }

      // If a trigger already created the profile or RLS blocks a duplicate write,
      // we continue and load the existing row.
    }
  }

  Future<void> _updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? organizationId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    final report = reports.where((item) => item.id == reportId).firstOrNull;
    if (report == null) {
      return;
    }

    _setBusy(true);
    try {
      await _client.from('reports').update({
        'status': status.dbValue,
        if (organizationId != null) 'assigned_organization_id': organizationId,
      }).eq('id', reportId);

      await _notifyUser(
        report.reporterUserId,
        title: notificationTitle,
        body: notificationBody,
      );

      authMessage = 'Report updated.';
      await _loadData();
    } catch (error) {
      authError = _friendlyError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> _notifyReporterForIncident(
    Incident incident,
    String title,
    String body,
  ) async {
    if (incident.relatedReportId == null) {
      return;
    }

    final report = reports.where((item) => item.id == incident.relatedReportId).firstOrNull;
    if (report == null) {
      return;
    }

    await _notifyUser(report.reporterUserId, title: title, body: body);
  }

  Future<void> _notifyUser(
    String userId, {
    required String title,
    required String body,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'is_read': false,
    });
  }

  void _setBusy(bool value) {
    isBusy = value;
  }

  String _organizationIdForRole(UserRole role) {
    return switch (role) {
      UserRole.resident => AppConstants.adminOrganizationId,
      UserRole.emergencyService => AppConstants.emsOrganizationId,
      UserRole.government => AppConstants.akimatOrganizationId,
      UserRole.admin => AppConstants.adminOrganizationId,
    };
  }

  List<Map<String, dynamic>> _asMapList(dynamic rows) {
    if (rows is! List) {
      return const [];
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  List<MobilityType> _affectedProfiles(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('elevator') || normalized.contains('ramp')) {
      return const [
        MobilityType.wheelchair,
        MobilityType.elderly,
        MobilityType.stroller,
      ];
    }
    if (normalized.contains('sidewalk')) {
      return const [
        MobilityType.wheelchair,
        MobilityType.lowVision,
        MobilityType.stroller,
      ];
    }
    return const [MobilityType.general];
  }

  (double, double) _coordinatesForDistrict(String district) {
    final center = switch (district) {
      'North Station' => (43.2435, 76.8883),
      'East River' => (43.2337, 76.8826),
      'South Garden' => (43.2296, 76.8948),
      _ => (43.2389, 76.8897),
    };

    final latOffset = (_random.nextDouble() - 0.5) * 0.003;
    final lngOffset = (_random.nextDouble() - 0.5) * 0.003;
    return (center.$1 + latOffset, center.$2 + lngOffset);
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      final message = error.message;
      if (_hasLegacyProfilesSchema(message)) {
        return 'The connected Supabase project has an older profiles table. '
            'Rerun the updated supabase/schema.sql to add the missing columns.';
      }
      if (message.contains('relation') && message.contains('does not exist')) {
        return 'Supabase tables are not installed yet. Run supabase/schema.sql in the SQL Editor.';
      }
      return message;
    }
    return error.toString();
  }

  bool _hasLegacyProfilesSchema(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('profiles') &&
        (normalized.contains('schema cache') ||
            normalized.contains('column') && normalized.contains('does not exist') ||
            normalized.contains('record') && normalized.contains('has no field'));
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
