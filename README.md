# tower_lens

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development workflow

- Changes are made through branches and pull requests.
- Automated agents must not commit directly to main.
- Pull requests require human review before merging.
- Automated review results must be evaluated before any agent-generated pull request is merged.

Agent-generated changes must remain narrowly scoped to their assigned issue.

## AI service configuration

Tower Lens uses the local mock AI service unless a remote credential is supplied.
For private development, a user can tap the key icon on Home or ToS and enter
their own Anthropic API key. The key is stored in the app's private preferences
on that device and can be removed from the same dialog. This is a temporary
development path, not the production credential architecture.

A build-time key remains available for local development:

```sh
flutter run --dart-define=ANTHROPIC_API_KEY=your-development-key
```

An API key compiled into an APK can be extracted. A key stored in app preferences
can also be recovered from a rooted device or device backup. Do not commit keys,
share configured APKs or backups, or use direct Anthropic credentials for a
public release.

The remote endpoint and model are configurable so the same client can later use
an Anthropic-compatible Tower Lens proxy:

```sh
flutter run \
  --dart-define=TOWER_LENS_AI_ENDPOINT=https://your-server.example/v1/messages \
  --dart-define=TOWER_LENS_AI_BEARER_TOKEN=your-app-token \
  --dart-define=TOWER_LENS_AI_MODEL=your-server-model
```

The proxy remains responsible for securely storing the Anthropic API key. If no
Anthropic key or proxy bearer token is configured, the app stays on the mock
service and makes no AI network requests.
