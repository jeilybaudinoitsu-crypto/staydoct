import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://tohowxjztirxddwnxtgw.supabase.co',
    publishableKey: 'sb_publishable_-jUjU9zFRWw-tHuyReHR1g_LK1hL43Q',
  );
  runApp(const StaydoctApp());
}