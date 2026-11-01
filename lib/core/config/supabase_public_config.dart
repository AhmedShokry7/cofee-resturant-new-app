/// Public Supabase client configuration for this app.
///
/// These values are deliberately public: the publishable key is designed to
/// ship in client apps. Database access must be protected by RLS and grants.
/// Never add a service-role key, access token, or database password here.
class SupabasePublicConfig {
  SupabasePublicConfig._();

  static const String url = 'https://webzzasosevzymftgszn.supabase.co';
  static const String publishableKey =
      'sb_publishable_EsJ6IX8428kZpKqgHX6wfw_1Q1ob1NO';
}
