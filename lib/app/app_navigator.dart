// lib/app/app_navigator.dart

import 'package:flutter/material.dart';

/// Use this in *all* apps (tenant + HQ) so snack/dialog/nav share one context.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
