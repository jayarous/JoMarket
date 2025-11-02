# jo_market

A multivendor shopping app.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase setup

This project uses Supabase for backend services. The app expects an anon
key (and optionally a URL) to be provided at runtime. There are three
recommended ways to provide the values:

1) Provide at build/run time (recommended for CI and production):

```powershell
flutter run --dart-define=SUPABASE_KEY="your_anon_key_here"
# Optionally override URL:
flutter run --dart-define=SUPABASE_URL="https://your.supabase.co" --dart-define=SUPABASE_KEY="your_anon_key_here"
```

2) Local developer convenience with a local `.env` file:

```powershell
Copy-Item .env.example .env
# Edit .env and put your SUPABASE_KEY (and optional SUPABASE_URL).
flutter run
```

3) Use an OS environment variable (works with VS Code launch config):

```powershell
$env:SUPABASE_KEY = "your_anon_key_here"; flutter run
```

Notes:
- Do NOT commit your `.env` file. This repo ignores `.env` by default.
- The app will throw and refuse to start if no `SUPABASE_KEY` is provided.
- For CI, store the anon key in your CI secrets and pass it with `--dart-define`.

