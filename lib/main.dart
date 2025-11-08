import 'package:flutter/material.dart';

import 'app/app.dart';
import 'bootstrap/supabase_bootstrap.dart';

export 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const MyApp());
}
