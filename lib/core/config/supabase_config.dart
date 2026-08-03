/// Supabase connection settings.
///
/// The publishable (anon) key is safe to ship in the client — all access is
/// enforced by Row-Level Security. Values default to the SFMS project but can
/// be overridden at build time, e.g.:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zklyibhpacxzjjttvodp.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3DvlYqi-5CItChxftr3OVQ_O7MMNDCl',
  );
}
