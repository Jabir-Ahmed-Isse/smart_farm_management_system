import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/offline/local_store.dart';
import 'core/offline/outbox.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local-first storage comes up before anything reads data, so the first
  // frame can render cached records even with no connection.
  await LocalStore.init();
  await Outbox.init();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    // Field is named `anonKey` for continuity but holds a publishable key.
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: SfmsApp()));
}
