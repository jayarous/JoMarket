library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_repository.dart';
import '../profile/profile_models.dart';
import '../profile/profile_repository.dart';
import '../profile/profile_screen.dart';
import 'admin/admin_analytics_screen.dart';
import 'delivery/delivery_job_screen.dart';
import 'favorites_screen.dart';
import 'offline_cache_service.dart';
import 'product_detail_screen.dart';
import 'product_search_screen.dart';
import 'shopping_cart_screen.dart';
import 'vendor/product_edit_screen.dart';
import 'vendor/shipment_edit_screen.dart';
import 'package:jo_market/app/widgets/profile_avatar.dart';
import 'package:jo_market/app/widgets/profile_widgets.dart';

part 'role_aware_home/role_aware_home_shell.dart';
part 'role_aware_home/role_dashboard.dart';
part 'role_aware_home/profile_summary_card.dart';
part 'role_aware_home/dashboards/shopper_dashboard.dart';
part 'role_aware_home/dashboards/vendor_dashboard.dart';
part 'role_aware_home/dashboards/delivery_dashboard.dart';
part 'role_aware_home/dashboards/admin_dashboard.dart';
part 'role_aware_home/shared_widgets.dart';
