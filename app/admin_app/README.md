# admin_app

Separate Flutter Web admin application for the coffee platform.

## Build and test

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web
```

## Configuration

Supabase URL and publishable key are resolved from `lib/core/config/supabase_public_config.dart`
and can be overridden at build time:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Only the publishable (anon) key may be used. Never embed a service-role key.
```
