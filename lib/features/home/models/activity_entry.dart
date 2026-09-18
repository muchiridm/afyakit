// lib/core/home/models/activity_entry.dart

import 'package:flutter/material.dart';

class ActivityEntry {
  const ActivityEntry({required this.date, required this.widget});

  /// Sorting date for the activity feed.
  ///
  /// Prefer updatedAt/modifiedAt when present, otherwise createdAt.
  final DateTime date;

  final Widget widget;
}
