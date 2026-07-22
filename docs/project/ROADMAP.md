# Tower Lens — Roadmap

## 1. What Tower Lens is

Tower Lens is a privacy-first, local-first Flutter Android app (initially targeting a Pixel 9a) that lets a user scan or paste dense real-world text -- books, ingredient labels, Terms of Service, manuals, warnings -- and ask an AI to summarize, explain, define, or report on it. Camera scanning with on-device OCR is the intended primary input method; manual paste/type is a fully supported secondary path.

Intended users: people dealing with dense or high-friction text -- students, people reading academic/technical material, people checking ToS/privacy policies, people with allergies or dietary restrictions checking ingredient labels, and generally anyone who wants a fast plain-language read on text in front of them.

Core non-negotiable principles: offline-first/local-by-default storage, user-controlled deletion, no ads (unless explicitly revisited later), no forced subscriptions, and no provider API secrets ever shipped inside a production client.

## 2. Current architecture and dependencies (verified against `origin/main`, commit `07ed09e`)

**Framework:** Flutter, Android-first. iOS/other platforms are untouched `flutter create` scaffolding only.

**Dependencies (`pubspec.yaml`, verified):**
- `file_picker: 10.3.8` -- exact pin; the previously blocking Android compatibility regression is fixed on `main`.
- `permission_handler: ^12.0.3`
- `path: ^1.9.1`
- `camera: ^0.12.0+2`
- `google_mlkit_text_recognition: ^0.16.0`
- `intl: ^0.20.3`
- `shared_preferences: ^2.5.5`
- `cupertino_icons: ^1.0.8`

No HTTP/networking or Anthropic SDK dependency exists yet -- real API integration has not started.

**Storage architecture:** Local library entries are saved as real files (not app-sandboxed) at a user-chosen folder location, using `permission_handler`'s `MANAGE_EXTERNAL_STORAGE` + `file_picker`'s directory chooser, written via plain `dart:io` file operations as Markdown files with YAML-style frontmatter (fields: id, type, folder, timestamp) and Markdown body sections (Source Text / Instruction / Output). Auto-organized into `TowerLens/General`, `TowerLens/ToS`, `TowerLens/Ingredient`, plus user-created custom folders. A local search/sort/filter index is expected to scan the directory live rather than maintain a separate cache (per design decision; not independently re-verified against current `library_service.dart` contents in this pass).

**Android manifest (verified, current `main`):** declares `MANAGE_EXTERNAL_STORAGE`, `CAMERA`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, and `<uses-feature android:name="android.hardware.camera" android:required="false">` (deliberately `false` so the app installs on camera-less devices; the manual-paste path is expected to remain usable there -- **UNKNOWN — VERIFY**: whether the camera entry point degrades gracefully on such a device, this has not been tested).

**App structure (per file tree + commit history, not independently re-diffed line-by-line this pass):**
- `lib/main.dart` -- root shell with bottom navigation across Home, Library, ToS, Watchlist tabs.
- `lib/screens/home_screen.dart` -- primary text-in/instruction-in/output screen, routes through `TextAiService`.
- `lib/screens/tos_screen.dart` -- ToS/privacy-policy summarization, routes through `TextAiService`.
- `lib/screens/watchlist_screen.dart` -- local ingredient/allergen watchlist management + text check (local substring matching only, not an AI call).
- `lib/screens/camera_scan_screen.dart` -- live camera preview, on-device ML Kit OCR, freeze-frame with pre-selected editable text.
- `lib/screens/library_screen.dart`, `lib/screens/library_detail_screen.dart` -- local file library browse/search/sort/filter/delete.
- `lib/services/library_service.dart` -- storage layer described above.
- `lib/services/watchlist_service.dart` -- local watchlist persistence via `shared_preferences`.
- `lib/services/text_ai_service.dart` -- abstraction introduced in issue #20/PR #21: `TextAiTaskType` enum (`general`, `tosSummary`), abstract `TextAiService`, and a `MockTextAiService` implementation. This is the seam real API integration should plug into.
- `lib/models/library_entry.dart` -- library entry data model.
- `test/library_service_test.dart`, `test/text_ai_service_test.dart`, `test/widget_test.dart` -- existing automated tests.
- `.github/workflows/android-ci.yml` -- Android test/build workflow added on `main`; its successful execution still needs to be confirmed from GitHub Actions.

## 3. Feature status

| Feature | Status |
|---|---|
| Home screen: text/instruction input, mocked run, save to library | Implemented (mocked AI) |
| Local library: save/browse/search/sort/filter/delete, real files, survives uninstall | Implemented |
| ToS/privacy mode: paste, mocked structured summary, save | Implemented (mocked AI) |
| Ingredient/allergy watchlist: manage list, check text against it | Implemented (real logic, not AI-based) |
| Camera + on-device OCR: live preview, live recognition, freeze, editable pre-selected text | Implemented |
| Dark theme (forced default) | Implemented |
| `TextAiService` abstraction (mock only) | Implemented |
| Real Anthropic API integration | **Not started** |
| Backend/proxy for production API key handling | Not started (correctly deferred per scope) |
| Credits / metered billing | Not started (correctly deferred per scope) |
| Accounts / authentication | Not started (correctly deferred per scope) |
| Payments (Google Play Billing) | Not started (correctly deferred per scope) |
| Ads | Not implemented, not planned unless explicitly revisited |
| Price-check / marketplace estimate mode | Not started, explicitly deferred, speculative |
| iOS support | Not started, explicitly deferred |
| PDF/Obsidian export beyond native Markdown | Not started |
| Loading UI state for `TextAiService` calls | **Implemented** -- Home and ToS disable in-flight controls, show progress indicators, and surface a retry-safe error message |
| On-device verification of everything since the last confirmed working build | **Not done** -- see Known Bugs |

## 4. Current milestone and next milestone

**Current milestone:** The full local vertical-slice feature set (Home, Library, ToS, Watchlist, Camera/OCR) is implemented against mocked AI responses behind a swappable `TextAiService` interface. Permissions and dark theme issues found during development have been fixed and merged. The blocking `file_picker` pin, AI-call loading/error state, library refresh notifications, initial `LibraryService` tests, and an Android CI workflow are also merged.

**Next milestone:** Confirm the restored Android build in GitHub Actions and on a physical device, re-verify the entire feature set against the current `main`, then begin real Claude API integration behind the existing `TextAiService` seam.

## 5–6. Prioritized backlog

### P0 — Blocking, completed

**Task: Pin `file_picker` to `10.3.8` — COMPLETE (merged in PR #24)**
- Objective: fix a confirmed Android build failure so `main` can produce a working APK at all.
- Acceptance criteria: `pubspec.yaml` pins `file_picker: 10.3.8` exactly (no caret); `flutter analyze` passes; `flutter build apk --debug` completes without the `GeneratedPluginRegistrant`/`FilePickerPlugin` compile error (manual, requires Android SDK).
- Files: `pubspec.yaml`, `pubspec.lock`.
- Dependencies: none -- must land before any other Dart/Android work is attempted, since nothing else is buildable until this lands.
- Tests: `flutter analyze`, `flutter test`; APK build is manual-verification-only in a sandbox without an Android SDK.
- Risks: low. This is a version-pin revert to a previously-confirmed-working state, not new code.
- Completion evidence: `pubspec.yaml` and `pubspec.lock` on `main` resolve `file_picker` to exactly `10.3.8`; merged commit `07ed09e`. Local Flutter/Android execution was unavailable during this reconciliation, so build success remains covered by the CI/on-device verification gates rather than assumed.

### P0.5 — Gate, not an agent task

**Human on-device verification pass.** Before any further feature work, a physical device build should be run against `main` (post file_picker fix) and every implemented feature manually re-checked: permissions flow (one-tap `MANAGE_EXTERNAL_STORAGE` grant → folder picker), dark theme rendering across all four tabs, Home/ToS output readability, Library save/browse/search/sort/filter/delete, Watchlist add/remove/check, Camera live-preview/freeze/select flow. Nothing since the very first successful local build has been confirmed working on-device.

### P1 — Real API integration

**Task: Implement real Anthropic API-backed `TextAiService`**
- Objective: add a concrete `TextAiService` implementation that calls the real Claude API, without breaking the existing mock path.
- Acceptance criteria: new class (e.g. `AnthropicTextAiService`) implements the existing `TextAiService` interface; uses model `claude-sonnet-5`; API key supplied via `--dart-define` at build time, never committed to the repo or hardcoded; `MockTextAiService` remains available/used for tests; Home and ToS screens can be pointed at either implementation via constructor injection (already the established pattern).
- Files: likely a new `lib/services/anthropic_text_ai_service.dart`; `pubspec.yaml` (new HTTP or Anthropic SDK dependency -- **UNKNOWN — VERIFY** which package, not yet decided); `lib/main.dart` (which implementation gets constructed).
- Dependencies: requires P0 (working build) and ideally P0.5 (confirmed-working baseline) first.
- Tests: unit test(s) mocking the HTTP layer; existing `MockTextAiService`-based tests should be unaffected.
- Risks: API key handling is the primary risk -- must not leak into version control or client-side production builds; error handling for network failures/rate limits is currently entirely unaddressed and needs design.

**Task: Loading state for AI calls — COMPLETE (merged in PR #23)**
- Objective: Home and ToS screens currently have no loading indicator despite `TextAiService.runTask` being genuinely async (mock includes an artificial delay specifically to surface this gap).
- Acceptance criteria: a loading indicator shows between tapping Run/Summarize and the output appearing; Run/Summarize button disabled while in flight.
- Files: `lib/screens/home_screen.dart`, `lib/screens/tos_screen.dart`.
- Dependencies: should land after P1 to avoid two agents editing the same two screens concurrently; could alternatively land just before P1 against the mock service, then simply keep working once P1 swaps the implementation.
- Risks: low, pure UI state.
- Completion evidence: both screens maintain an in-flight flag, disable relevant controls, render a progress indicator, and restore controls after success or failure (`30ef426`).

### P2 — Product completeness

**Task: Route Watchlist ingredient-ambiguity explanations through real AI**
- Objective: per original product scope, AI should be able to explain ambiguous ingredients on request -- currently Watchlist only does local substring matching.
- Acceptance criteria: **UNKNOWN — VERIFY** exact UX (not yet designed); depends on P1 being complete.
- Files: `lib/screens/watchlist_screen.dart`, `lib/services/text_ai_service.dart` (likely a new `TextAiTaskType`).
- Dependencies: P1.

### P3 — Process/tooling fix (independent, can run anytime)

**Task: Fix issue-closing logic so an issue isn't marked complete unless its linked PR actually merged**
- Objective: issue #5 was historically closed as `completed` before its linked PR #6 merged. The required README sentence is now present on `main` through later commit `9822806`, but that repairs the missing deliverable rather than proving the issue-closing logic itself was fixed. Preserve and audit this process-integrity task.
- Acceptance criteria: **UNKNOWN — VERIFY** -- this is a workflow/CI change (`.github/workflows/run-orchestrator.yml`), not a Flutter app change; exact fix depends on how issue-closing is currently triggered (not established in this pass).
- Files: `.github/workflows/run-orchestrator.yml`, possibly orchestrator prompt/config (not in this repo's tracked files -- **UNKNOWN — VERIFY** where the orchestrator's actual logic lives).
- Dependencies: none, safe to run in parallel with app-code tasks since it doesn't touch `lib/`.
- Risks: low technically, but low-confidence on exact fix location without more inspection.

### Deferred / explicitly out of scope for now (per product principles, not forgotten)

- Backend/proxy for production API key custody.
- Credits, metered billing, Google Play Billing integration.
- Accounts/authentication.
- Price-check/marketplace estimate mode.
- iOS support.
- Ads (not planned unless explicitly revisited).
- PDF/Obsidian export beyond the existing native Markdown format.

## 7. Known bugs, technical debt, security/privacy concerns, unresolved decisions

**Known bugs:**
- **Resolved in PR #24:** the confirmed `file_picker` Android regression was addressed by pinning `file_picker: 10.3.8` exactly. CI and physical-device confirmation remain required before treating the full app as verified.
- Issue #5 was closed as `completed` before its PR (#6) merged. Its required README sentence is now present on `main` via later commit `9822806`, but the historical process-integrity gap still needs the P3 workflow audit.

**Technical debt:**
- No automated integration/widget test coverage for Library, ToS, Watchlist, or Camera screens. `LibraryService` has notification-focused unit tests, alongside the `TextAiService` mock unit test and the default Flutter widget smoke test.
- Home/ToS loading and basic error states are implemented; broader real-network error design remains part of P1 API integration.
- Storage/search-filter approach (live directory scan, no cache) has not been stress-tested at scale; fine for the expected personal-use volume (dozens to low hundreds of entries) but unverified beyond that.

**Security/privacy concerns:**
- `MANAGE_EXTERNAL_STORAGE` is a broad, Google-Play-scrutinized permission. Acceptable for local sideloaded development; **unresolved decision** for eventual public release -- may need to migrate to per-folder Storage Access Framework access, or provide Play Console justification, before store submission.
- Real API integration must supply the key via `--dart-define` or equivalent, never committed or hardcoded. Longer-term, per original product scope, production API keys must never ship inside the client at all -- a backend/proxy is required before any public release, and is explicitly not yet started.

**Unresolved product decisions:**
- Whether/how the camera entry point should degrade on a device with no camera hardware (manifest currently allows install via `android:required="false"`, but the resulting UX on such a device is untested).
- Exact backend/proxy architecture and timing for production API key custody.
- Exact HTTP/SDK dependency choice for real Anthropic API integration (not yet selected).

## 8. Release and monetization phases

**MVP (current phase):** fully local, no accounts, no payments, no backend, mocked AI responses swappable for real ones behind `TextAiService`. No monetization infrastructure exists or is needed yet.

**Post-MVP, pre-commercial:** real Claude API integration via direct client calls with a dev-supplied key (`--dart-define`), acceptable only for continued local/sideloaded development -- not viable for public release per the no-client-side-secrets principle.

**Commercial phase (not started, no work should begin here until MVP + real API integration are solid):** backend/proxy holding the real API key server-side, credit-based metering (or subscription -- undecided), Google Play Billing integration for Android, no ads, no forced subscription, fair pay-as-you-go framing per original product principles.

## 9. Recommended execution order

1. **P0 — Pin `file_picker` to `10.3.8`. COMPLETE.** Merged in PR #24; retain this step as completion history.
2. **P0.5 — Human on-device verification pass** against the fixed build. Not an agent task, but should happen before further agent-driven feature work stacks up on an unverified base.
3. **P1 — Real Anthropic API integration**, touching `lib/services/` and `pubspec.yaml`. Should not run in parallel with any other task touching `lib/services/text_ai_service.dart`.
4. **P1 — Loading state UI. COMPLETE.** Merged in PR #23; retain this step as completion history. Re-check it during the physical-device pass.
5. **P3 — Issue-closing process fix.** Independent of all app-code tasks (touches only `.github/workflows/`), safe to run in parallel with any of the above.
6. **P2 — Watchlist AI-explanation feature.** Depends on task 3 (P1) being complete; do not start before then.
7. Everything under "Deferred / explicitly out of scope" remains untouched until the above is solid and a deliberate decision is made to begin commercial-phase work.

## 10. Next task for Codex

**Verify the current `main` build, then perform P0.5 on-device verification.** The `file_picker: 10.3.8` fix is merged and the repository now contains an Android CI workflow. First confirm that the workflow completes its test and debug-APK jobs for `main`; correct only evidence-backed CI/configuration failures if present. Then, when a physical device is available, run the preserved P0.5 checklist. Do not begin real Anthropic integration until that baseline is confirmed unless the user explicitly chooses to accept the risk.
