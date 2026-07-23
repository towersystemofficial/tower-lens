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

Tower Lens uses the local mock AI service unless a remote credential is supplied
at build time. For private development against Anthropic:

```sh
flutter run --dart-define=ANTHROPIC_API_KEY=your-development-key
```

An API key compiled into an APK can be extracted. Do not commit the key or use
this direct configuration for an APK distributed to testers.

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
