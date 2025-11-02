# Environment variables and `envied` guidance

This folder contains an example environment file and quick instructions for using typed environment variables with `envied`.

1) Create your local `.env`

- Copy `env/.env.example` to the repository root as `.env` and fill the values.
- Ensure `.env` is listed in `.gitignore`. Do NOT commit your `.env` file.

2) Add `envied` to your project

- In `pubspec.yaml` add:

  dependencies:
    envied: ^2.0.0

  dev_dependencies:
    envied_generator: ^2.0.0
    build_runner: ^2.0.0

 (Adjust versions as appropriate.)

3) Create a typed env class

- Example (create `lib/src/env.dart`):

  ```dart
  import 'package:envied/envied.dart';

  part 'env.g.dart';

  @Envied()
  abstract class Env {
    @EnviedField(varName: 'SUPABASE_URL')
    static const supabaseUrl = '';

    @EnviedField(varName: 'SUPABASE_ANON_KEY')
    static const supabaseAnonKey = '';
  }
  ```

4) Generate code

- Run the build runner to generate the typed classes:

  flutter pub run build_runner build --delete-conflicting-outputs

5) Use in code

- Import your generated env values instead of reading plain strings from `.env` directly. This gives compile-time guarantees and reduces typos.

6) CI and secrets

- Do NOT store production secrets in the repository. Use your CI provider's secret store (GitHub Actions secrets, Azure Key Vault, etc.) and inject them into workflows at build time.
- For GitHub Actions, add required secrets as repository secrets or use OIDC to retrieve them from your vault.

Notes
- If your `.env` already contains real keys (like Supabase keys), verify that it is NOT committed. If it is committed, rotate the secrets immediately and remove them from the repo history.
