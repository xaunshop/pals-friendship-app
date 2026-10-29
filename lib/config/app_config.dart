/// App branding and public Supabase configuration.
/// Rename the app by editing [appName]. Never place a service-role key here.
class AppConfig {
  AppConfig._();
  static const String appName = 'PALS';
  static const String tagline = 'Find your people';
  static const String appVersion = '2.0.0';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get hasBackend => supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
