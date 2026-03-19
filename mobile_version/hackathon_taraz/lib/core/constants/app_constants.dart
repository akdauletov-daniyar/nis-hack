import 'package:flutter/material.dart';

import '../models/app_models.dart';

class AppConstants {
  static const defaultDistrict = 'Alatau Central';

  static const districts = [
    'Alatau Central',
    'North Station',
    'East River',
    'South Garden',
  ];

  static const emsOrganizationId = '11111111-1111-4111-8111-111111111111';
  static const fireOrganizationId = '22222222-2222-4222-8222-222222222222';
  static const akimatOrganizationId = '33333333-3333-4333-8333-333333333333';
  static const adminOrganizationId = '44444444-4444-4444-8444-444444444444';

  static const reportCategories = [
    'Blocked sidewalk',
    'Broken elevator',
    'Missing ramp',
    'Unsafe crossing',
    'Dangerous road',
    'Broken traffic light',
    'Construction problem',
    'Fire / smoke',
    'Flooding',
    'Accident',
    'Broken street light',
    'Suspicious situation',
    'Other infrastructure issue',
  ];

  static const accessibilityCategories = [
    'Blocked sidewalk',
    'Broken elevator',
    'Missing ramp',
    'Unsafe crossing',
  ];

  static const rejectReasons = [
    'Duplicate issue',
    'Insufficient details',
    'Outside district scope',
    'Could not verify the report',
  ];

  static const demoAttachmentLabels = [
    'ramp-photo.jpg',
    'crossing-photo.jpg',
    'streetlight-photo.jpg',
    'sidewalk-photo.jpg',
  ];

  static const routeLandmarks = [
    CityLandmark(
      label: 'Home',
      district: 'Alatau Central',
      description: 'Default resident starting point.',
    ),
    CityLandmark(
      label: 'Akimat',
      district: 'Alatau Central',
      description: 'Government services center.',
    ),
    CityLandmark(
      label: 'Clinic No. 4',
      district: 'North Station',
      description: 'Medical destination with accessibility-sensitive routing.',
    ),
    CityLandmark(
      label: 'North Station',
      district: 'North Station',
      description: 'Transit hub with heavy pedestrian movement.',
    ),
    CityLandmark(
      label: 'Bazaar Square',
      district: 'East River',
      description: 'Dense commercial area with changing obstacle pressure.',
    ),
    CityLandmark(
      label: 'South Garden Playground',
      district: 'South Garden',
      description: 'Family destination used in stroller-friendly routes.',
    ),
  ];

  static const mainColor = Color(0xFFFFFFFF);
  static const mainTextColor = Color(0xFF080808);
  static const mainAccentColor = Color(0xFF5308CE);
  static const secondaryAccentColor = Color(0xFF3558F3);
  static const accent2Color = Color(0xFFF56029);
}

IconData iconForReportCategory(String category) {
  return switch (category) {
    'Blocked sidewalk' => Icons.block_outlined,
    'Broken elevator' => Icons.elevator_outlined,
    'Missing ramp' => Icons.accessible_forward_outlined,
    'Unsafe crossing' => Icons.directions_walk_outlined,
    'Dangerous road' => Icons.warning_amber_outlined,
    'Broken traffic light' => Icons.traffic_outlined,
    'Construction problem' => Icons.construction_outlined,
    'Fire / smoke' => Icons.local_fire_department_outlined,
    'Flooding' => Icons.water_drop_outlined,
    'Accident' => Icons.car_crash_outlined,
    'Broken street light' => Icons.lightbulb_outline,
    'Suspicious situation' => Icons.policy_outlined,
    _ => Icons.domain_verification_outlined,
  };
}
