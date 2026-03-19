import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../models/app_models.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => AppController(),
);

class AppController extends ChangeNotifier {
  AppController() {
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      unawaited(_hydrateSession());
    });
    unawaited(_hydrateSession());
  }

  static const _activeRolePrefsKey = 'active_role';

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
  bool showReportLayer = true;
  bool showIncidentLayer = true;
  bool showBarrierLayer = true;
  bool _checkedDemoSeed = false;
  String routeStartLabel = AppConstants.routeLandmarks.first.label;
  String routeDestinationLabel = AppConstants.routeLandmarks[1].label;

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

  List<CityLandmark> get routeLandmarks {
    final savedPlaceLandmarks = (currentUser?.savedPlaces ?? const [])
        .map(
          (place) => CityLandmark(
            label: place,
            district: currentUser?.district ?? AppConstants.defaultDistrict,
            description: 'Saved place from the resident profile.',
          ),
        )
        .toList();

    final merged = [...AppConstants.routeLandmarks];
    for (final landmark in savedPlaceLandmarks) {
      final alreadyExists = merged.any((item) => item.label == landmark.label);
      if (!alreadyExists) {
        merged.add(landmark);
      }
    }
    return merged;
  }

  CityLandmark get selectedRouteStart => _landmarkForLabel(routeStartLabel);

  CityLandmark get selectedRouteDestination =>
      _landmarkForLabel(routeDestinationLabel);

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

  RoutePlan get activeRoutePlan {
    final profile = currentUser?.profile.mobilityType ?? MobilityType.general;
    final destination = selectedRouteDestination;
    final relevantReports = reports
        .where(
          (report) =>
              report.district == destination.district &&
              report.status != ReportStatus.closed &&
              report.status != ReportStatus.rejected &&
              report.status != ReportStatus.spam,
        )
        .toList();
    final relevantObstacles = relevantReports
        .where((report) => report.accessibilityRelated)
        .toList();
    final obstaclePressure = relevantObstacles.length;
    final liveSignals = relevantReports.length;
    final routePrefix = barrierFreeMode ? 'Barrier-free' : 'Fastest';

    final generalHighlights = <String>[
      'Starts from ${selectedRouteStart.label}',
      'Destination: ${destination.label}',
      if (barrierFreeMode) 'Uses accessibility-aware detours when needed',
      if (!barrierFreeMode) 'Optimizes travel time over accessibility detours',
    ];
    final mobilityHighlights = switch (profile) {
      MobilityType.wheelchair => [
        'Avoids stairs and broken elevator corridors when possible',
        'Prefers curb-cut crossings and smoother surfaces',
      ],
      MobilityType.lowVision => [
        'Prefers clearer crossings and simpler turns',
        'Keeps route instructions short and legible',
      ],
      MobilityType.elderly => [
        'Reduces long climbs and sharp slope changes',
        'Keeps rest-stop friendly corridors in view',
      ],
      MobilityType.stroller => [
        'Prefers wider sidewalks and ramps',
        'Avoids chokepoints and tight detours',
      ],
      MobilityType.general => [
        'Balances speed, safety, and live city conditions',
        'Avoids the busiest issue clusters when possible',
      ],
    };
    final warnings = <String>[
      if (obstaclePressure > 0)
        ...relevantObstacles.take(2).map(
          (obstacle) => '${obstacle.category} near ${obstacle.location}',
        )
      else
        'Limited live accessibility data, using profile defaults.',
      if (!barrierFreeMode) 'Barrier-free filters are currently turned off.',
    ];
    final etaBase = switch (profile) {
      MobilityType.wheelchair => 18,
      MobilityType.lowVision => 17,
      MobilityType.elderly => 19,
      MobilityType.stroller => 16,
      MobilityType.general => 14,
    };
    final etaMinutes = etaBase + (barrierFreeMode ? obstaclePressure : 0);
    final alternativeRoute = barrierFreeMode && obstaclePressure >= 2
        ? RouteLeg(
            title:
                'Fallback route via ${destination.district} service corridor',
            etaMinutes: etaMinutes + 3,
            district: destination.district,
            highlights: const [
              'Trades a few minutes for a calmer path',
              'Avoids the densest live barrier cluster',
            ],
            warnings: const [
              'Fewer live confirmations are available on this alternative',
            ],
          )
        : null;

    return RoutePlan(
      primaryRoute: RouteLeg(
        title:
            '$routePrefix route to ${destination.label}',
        etaMinutes: etaMinutes,
        district: destination.district,
        highlights: [...generalHighlights, ...mobilityHighlights],
        warnings: warnings,
      ),
      alternativeRoute: alternativeRoute,
      safetyHint: obstaclePressure >= 2
          ? 'High obstacle pressure detected near the destination. Keep extra time for detours.'
          : 'No major blocker cluster detected on the active route.',
      dataConfidence: liveSignals == 0
          ? 'Low confidence: using profile defaults and district heuristics.'
          : 'Moderate confidence: using $liveSignals live city update(s) in ${destination.district}.',
      fallbackMessage: liveSignals == 0
          ? 'Limited live accessibility data, using profile defaults.'
          : null,
    );
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
      notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _client.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeRolePrefsKey);
      currentUser = null;
      activeRole = null;
      organizations = const [];
      managedUsers = const [];
      reports = const [];
      incidents = const [];
      notifications = const [];
      announcements = const [];
      dataError = null;
      _checkedDemoSeed = false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  void selectRole(UserRole role) {
    activeRole = role;
    unawaited(_persistActiveRole(role));
    notifyListeners();
  }

  void switchRole(UserRole role) {
    activeRole = role;
    unawaited(_persistActiveRole(role));
    notifyListeners();
  }

  void dismissMessage() {
    authError = null;
    authMessage = null;
    dataError = null;
    notifyListeners();
  }

  Future<ActionResult> setBarrierFreeMode(bool enabled) async {
    barrierFreeMode = enabled;
    notifyListeners();
    return ActionResult.success(
      enabled
          ? 'Barrier-free routing enabled.'
          : 'Barrier-free routing disabled.',
    );
  }

  void setRouteStart(String label) {
    routeStartLabel = label;
    notifyListeners();
  }

  void setRouteDestination(String label) {
    routeDestinationLabel = label;
    notifyListeners();
  }

  void toggleMapLayer(MapLayer layer) {
    if (layer == MapLayer.reports) {
      showReportLayer = !showReportLayer;
    } else if (layer == MapLayer.incidents) {
      showIncidentLayer = !showIncidentLayer;
    } else {
      showBarrierLayer = !showBarrierLayer;
    }
    notifyListeners();
  }

  Future<ActionResult> setMobilityType(MobilityType mobilityType) async {
    final user = currentUser;
    if (user == null) {
      return const ActionResult.failure('Sign in again to update your profile.');
    }

    _setBusy(true);
    try {
      await _client
          .from('profiles')
          .update({'mobility_type': mobilityType.dbValue})
          .eq('id', user.id);

      currentUser = user.copyWith(
        profile: user.profile.copyWith(mobilityType: mobilityType),
      );
      authMessage = 'Accessibility profile updated.';
      return const ActionResult.success('Accessibility profile updated.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> submitReport({
    required String category,
    required String description,
    required String district,
    required String locationDetails,
    required UrgencyLevel urgency,
    required bool accessibilityRelated,
    String? attachmentLabel,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const ActionResult.failure('Sign in again to submit a report.');
    }

    _setBusy(true);
    try {
      final coords = _coordinatesForDistrict(district);
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
            'district': district,
            'location_text': locationDetails,
            'latitude': coords.$1,
            'longitude': coords.$2,
            'accessibility_related': accessibilityRelated,
            if (attachmentLabel != null && attachmentLabel.isNotEmpty)
              'photo_url': attachmentLabel,
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
          'district': district,
          'reporter_name': user.name,
          'reporter_phone': user.phone,
          'assigned_organization_id': AppConstants.emsOrganizationId,
          'latitude': coords.$1,
          'longitude': coords.$2,
        });
      }

      authMessage = 'Report submitted successfully.';
      await _loadData();
      return const ActionResult.success('Report submitted successfully.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> triggerSos({
    required SosType sosType,
    required String district,
    required String locationDetails,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const ActionResult.failure('Sign in again to send SOS.');
    }

    _setBusy(true);
    try {
      final coords = _coordinatesForDistrict(district);
      final report = await _client
          .from('reports')
          .insert({
            'reporter_user_id': user.id,
            'reporter_name': user.name,
            'reporter_phone': user.phone,
            'title': 'SOS emergency from mobile user',
            'category': sosType.label,
            'description':
                'Emergency assistance requested through the resident SOS flow. Type: ${sosType.label}.',
            'status': ReportStatus.validated.dbValue,
            'urgency': UrgencyLevel.critical.dbValue,
            'district': district,
            'location_text': locationDetails,
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
        'title': 'SOS dispatch requested: ${sosType.label}',
        'status': IncidentStatus.newIncident.dbValue,
        'urgency': UrgencyLevel.critical.dbValue,
        'district': district,
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
      return const ActionResult.success('SOS sent successfully.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> progressIncident(String incidentId) async {
    final incident = incidents
        .where((item) => item.id == incidentId)
        .firstOrNull;
    if (incident == null) {
      return const ActionResult.failure('Incident not found.');
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
          .update({'status': nextStatus.dbValue})
          .eq('id', incidentId);

      if (incident.relatedReportId != null) {
        final reportStatus = switch (nextStatus) {
          IncidentStatus.assigned ||
          IncidentStatus.crewEnRoute ||
          IncidentStatus.onSite => ReportStatus.inProgress,
          IncidentStatus.resolved => ReportStatus.resolved,
          IncidentStatus.closed => ReportStatus.closed,
          IncidentStatus.transferred => ReportStatus.assigned,
          IncidentStatus.newIncident => ReportStatus.validated,
        };

        await _client
            .from('reports')
            .update({'status': reportStatus.dbValue})
            .eq('id', incident.relatedReportId!);
      }

      await _notifyReporterForIncident(
        incident,
        'Incident updated',
        'Emergency response moved to ${nextStatus.label.toLowerCase()}.',
      );

      authMessage = 'Incident updated.';
      await _loadData();
      return ActionResult.success(
        'Incident moved to ${nextStatus.label.toLowerCase()}.',
      );
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> transferIncident(String incidentId) async {
    final incident = incidents
        .where((item) => item.id == incidentId)
        .firstOrNull;
    if (incident == null) {
      return const ActionResult.failure('Incident not found.');
    }

    _setBusy(true);
    try {
      await _client
          .from('incidents')
          .update({
            'status': IncidentStatus.transferred.dbValue,
            'assigned_organization_id': AppConstants.fireOrganizationId,
          })
          .eq('id', incidentId);

      if (incident.relatedReportId != null) {
        await _client
            .from('reports')
            .update({
              'status': ReportStatus.assigned.dbValue,
              'assigned_organization_id': AppConstants.fireOrganizationId,
            })
            .eq('id', incident.relatedReportId!);
      }

      await _notifyReporterForIncident(
        incident,
        'Incident transferred',
        'The incident has been transferred to another service.',
      );

      authMessage = 'Incident transferred.';
      await _loadData();
      return const ActionResult.success('Incident transferred.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> validateReport(String reportId) async {
    return _updateReportStatus(
      reportId,
      ReportStatus.validated,
      organizationId: AppConstants.akimatOrganizationId,
      notificationTitle: 'Report validated',
      notificationBody: 'Your report has been validated by the city team.',
    );
  }

  Future<ActionResult> rejectReport(
    String reportId, {
    required String reason,
  }) async {
    return _updateReportStatus(
      reportId,
      ReportStatus.rejected,
      notificationTitle: 'Report rejected',
      notificationBody: 'Your report was rejected after review. Reason: $reason',
    );
  }

  Future<ActionResult> assignReport(
    String reportId,
    String organizationId,
  ) async {
    return _updateReportStatus(
      reportId,
      ReportStatus.assigned,
      organizationId: organizationId,
      notificationTitle: 'Report assigned',
      notificationBody:
          'Your report has been assigned to a responsible organization.',
    );
  }

  Future<ActionResult> publishAnnouncement({
    required String title,
    required String body,
    required String district,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const ActionResult.failure('Sign in again to publish an alert.');
    }

    _setBusy(true);
    try {
      await _client.from('announcements').insert({
        'title': title,
        'body': body,
        'severity': 'Notice',
        'district': district,
        'author_user_id': user.id,
      });

      await _notifyUser(user.id, title: 'Announcement published', body: title);
      authMessage = 'Announcement published.';
      await _loadData();
      return const ActionResult.success('Announcement published.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
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

  Future<ActionResult> moderateReport(
    String reportId,
    ReportStatus status,
  ) async {
    return _updateReportStatus(
      reportId,
      status,
      notificationTitle: 'Report moderation update',
      notificationBody:
          'A moderator updated the report status to ${status.label}.',
    );
  }

  Future<ActionResult> grantRoleToUser(String userId, UserRole role) async {
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
      return ActionResult.success('${role.label} granted successfully.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> removeRoleFromUser(String userId, UserRole role) async {
    final managedUser = managedUsers.where((user) => user.id == userId).firstOrNull;
    if (managedUser != null && managedUser.roles.length <= 1) {
      return const ActionResult.failure(
        'Each account must keep at least one active role.',
      );
    }

    _setBusy(true);
    try {
      await _client
          .from('role_assignments')
          .delete()
          .eq('user_id', userId)
          .eq('role', role.dbValue);

      if (currentUser?.id == userId && activeRole == role) {
        final remainingRoles = (currentUser?.roles ?? const [])
            .where((item) => item != role)
            .toList();
        activeRole = remainingRoles.isEmpty ? null : remainingRoles.first;
        if (activeRole == null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_activeRolePrefsKey);
        } else {
          await _persistActiveRole(activeRole!);
        }
      }

      authMessage = '${role.label} removed successfully.';
      if (currentUser?.id == userId) {
        await _loadCurrentUser(userId);
      }
      await _loadData();
      return ActionResult.success('${role.label} removed successfully.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<ActionResult> createOrganization({
    required String name,
    required OrganizationType type,
    required List<String> districts,
  }) async {
    _setBusy(true);
    try {
      await _client.from('organizations').insert({
        'name': name.trim(),
        'type': type.dbValue,
        'districts': districts,
      });

      authMessage = 'Organization created successfully.';
      await _loadData();
      return const ActionResult.success('Organization created successfully.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
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
      showReportLayer = true;
      showIncidentLayer = true;
      showBarrierLayer = true;
      routeStartLabel = AppConstants.routeLandmarks.first.label;
      routeDestinationLabel = AppConstants.routeLandmarks[1].label;
      isHydrating = false;
      notifyListeners();
      return;
    }

    try {
      await _ensureProfile(authUser);
      await _loadCurrentUser(authUser.id);
      await _loadData();
      if (!_checkedDemoSeed) {
        final seeded = await _seedDemoDataIfNeeded();
        _checkedDemoSeed = true;
        if (seeded) {
          await _loadCurrentUser(authUser.id);
          await _loadData();
        }
      }

      final persistedRole = await _readPersistedActiveRole();
      if (persistedRole != null && availableRoles.contains(persistedRole)) {
        activeRole = persistedRole;
      } else if (availableRoles.length == 1) {
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
    final profileRows = _asMapList(
      await _client.from('profiles').select().eq('id', userId),
    );
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

    final roles =
        _asMapList(roleRows)
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
    final reportRows = await _client
        .from('reports')
        .select()
        .order('created_at', ascending: false);
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

    organizations = _asMapList(
      organizationRows,
    ).map(Organization.fromMap).toList();
    reports = _asMapList(reportRows).map(CityReport.fromMap).toList();
    incidents = _asMapList(incidentRows).map(Incident.fromMap).toList();
    announcements = _asMapList(
      announcementRows,
    ).map(Announcement.fromMap).toList();
    notifications = _asMapList(
      notificationRows,
    ).map(AppNotification.fromMap).toList();

    if (availableRoles.contains(UserRole.admin)) {
      managedUsers = await _loadManagedUsers();
    } else {
      managedUsers = const [];
    }
  }

  Future<List<AppUser>> _loadManagedUsers() async {
    final profileRows = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    final roleRows = await _client
        .from('role_assignments')
        .select()
        .eq('active', true);
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
      final roles =
          (rolesByUserId[userId] ?? const [UserRole.resident]).toSet().toList()
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
        'district':
            authUser.userMetadata?['district'] as String? ??
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

  Future<ActionResult> _updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? organizationId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    final report = reports.where((item) => item.id == reportId).firstOrNull;
    if (report == null) {
      return const ActionResult.failure('Report not found.');
    }

    _setBusy(true);
    try {
      await _client
          .from('reports')
          .update({
            'status': status.dbValue,
            if (organizationId != null)
              'assigned_organization_id': organizationId,
          })
          .eq('id', reportId);

      await _notifyUser(
        report.reporterUserId,
        title: notificationTitle,
        body: notificationBody,
      );

      authMessage = 'Report updated.';
      await _loadData();
      return ActionResult.success('Report moved to ${status.label}.');
    } catch (error) {
      authError = _friendlyError(error);
      return ActionResult.failure(authError!);
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

    final report = reports
        .where((item) => item.id == incident.relatedReportId)
        .firstOrNull;
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

  Future<void> _persistActiveRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeRolePrefsKey, role.dbValue);
  }

  Future<UserRole?> _readPersistedActiveRole() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_activeRolePrefsKey);
    if (value == null) {
      return null;
    }
    return userRoleFromDb(value);
  }

  Future<bool> _seedDemoDataIfNeeded() async {
    final user = currentUser;
    if (user == null) {
      return false;
    }

    var seeded = false;

    if (user.savedPlaces.isEmpty) {
      await _client.from('saved_places').insert([
        {
          'user_id': user.id,
          'label': 'Home',
        },
        {
          'user_id': user.id,
          'label': 'Clinic No. 4',
        },
        {
          'user_id': user.id,
          'label': 'Akimat',
        },
      ]);
      seeded = true;
    }

    if (reports.isEmpty) {
      final sampleReports = await _client
          .from('reports')
          .insert([
            {
              'reporter_user_id': user.id,
              'reporter_name': user.name,
              'reporter_phone': user.phone,
              'title': 'Blocked sidewalk near Bazaar Square',
              'category': 'Blocked sidewalk',
              'description':
                  'Construction fencing narrows the sidewalk and blocks wheelchair access.',
              'status': ReportStatus.submitted.dbValue,
              'urgency': UrgencyLevel.high.dbValue,
              'district': 'East River',
              'location_text': 'Bazaar Square north crossing',
              'latitude': 43.2337,
              'longitude': 76.8826,
              'accessibility_related': true,
              'photo_url': 'sidewalk-photo.jpg',
            },
            {
              'reporter_user_id': user.id,
              'reporter_name': user.name,
              'reporter_phone': user.phone,
              'title': 'Broken elevator at Clinic No. 4',
              'category': 'Broken elevator',
              'description':
                  'Elevator is out of service, forcing patients onto stairs.',
              'status': ReportStatus.assigned.dbValue,
              'urgency': UrgencyLevel.critical.dbValue,
              'district': 'North Station',
              'location_text': 'Clinic No. 4 main entrance',
              'latitude': 43.2435,
              'longitude': 76.8883,
              'accessibility_related': true,
              'assigned_organization_id': AppConstants.akimatOrganizationId,
              'photo_url': 'ramp-photo.jpg',
            },
            {
              'reporter_user_id': user.id,
              'reporter_name': user.name,
              'reporter_phone': user.phone,
              'title': 'Broken traffic light on Central Avenue',
              'category': 'Broken traffic light',
              'description':
                  'Traffic light is dark during peak hours and creates a dangerous crossing.',
              'status': ReportStatus.validated.dbValue,
              'urgency': UrgencyLevel.high.dbValue,
              'district': 'Alatau Central',
              'location_text': 'Central Avenue and School Street',
              'latitude': 43.2389,
              'longitude': 76.8897,
              'accessibility_related': false,
              'assigned_organization_id': AppConstants.akimatOrganizationId,
            },
          ])
          .select();

      final reportMaps = _asMapList(sampleReports);
      final criticalReport = reportMaps
          .where((report) => report['category'] == 'Broken elevator')
          .firstOrNull;
      if (criticalReport != null) {
        await _client.from('incidents').insert({
          'report_id': criticalReport['id'],
          'created_by_user_id': user.id,
          'title': 'Critical elevator outage at Clinic No. 4',
          'status': IncidentStatus.assigned.dbValue,
          'urgency': UrgencyLevel.critical.dbValue,
          'district': 'North Station',
          'reporter_name': user.name,
          'reporter_phone': user.phone,
          'assigned_organization_id': AppConstants.emsOrganizationId,
          'latitude': 43.2435,
          'longitude': 76.8883,
        });
      }
      seeded = true;
    }

    if (announcements.isEmpty &&
        (availableRoles.contains(UserRole.government) ||
            availableRoles.contains(UserRole.admin) ||
            availableRoles.contains(UserRole.emergencyService))) {
      await _client.from('announcements').insert([
        {
          'author_user_id': user.id,
          'title': 'Barrier-Free Alatau advisory',
          'body':
              'City teams are rerouting pedestrians around a blocked sidewalk near Bazaar Square.',
          'severity': 'Notice',
          'district': 'East River',
        },
        {
          'author_user_id': user.id,
          'title': 'Clinic elevator response in progress',
          'body':
              'Emergency and Akimat teams are coordinating around the elevator outage at Clinic No. 4.',
          'severity': 'Notice',
          'district': 'North Station',
        },
      ]);
      seeded = true;
    }

    return seeded;
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

  CityLandmark _landmarkForLabel(String label) {
    return routeLandmarks
            .where((landmark) => landmark.label == label)
            .firstOrNull ??
        routeLandmarks.first;
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
            normalized.contains('column') &&
                normalized.contains('does not exist') ||
            normalized.contains('record') &&
                normalized.contains('has no field'));
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
