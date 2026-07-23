# Tower Lens — Roadmap

## 1. What Tower Lens is

Tower Lens is a privacy-first, local-first Flutter Android app (initially targeting a Pixel 9a) that lets a user scan or paste dense real-world text -- books, ingredient labels, Terms of Service, manuals, warnings -- and ask an AI to summarize, explain, define, or report on it. Camera scanning with on-device OCR is the intended primary input method; manual paste/type is a fully supported secondary path.

Intended users: people dealing with dense or high-friction text -- students, people reading academic/technical material, people checking ToS/privacy policies, people with allergies or dietary restrictions checking ingredient labels, and generally anyone who wants a fast plain-language read on text in front of them.

Core non-negotiable principles: offline-first/local-by-default storage, user-controlled deletion, no ads (unless explicitly revisited later), no forced subscriptions, and no provider API secrets ever shipped inside a production client.

## 2. Current architecture and dependencies (verified against `main` after merged PR #28)

**Framework:** Flutter, Android-first. iOS/other platforms are untouched `flutter create` scaffolding only.

**Dependencies (`pubspec.yaml`, verified):**
- `file_picker: 10.3.8` -- exact pin; the previously blocking Android compatibility regression is fixed on `main`.
- `permission_handler: ^12.0.3`
- `path: ^1.9.1`
- `camera: ^0.12.0+2`
- `google_mlkit_text_recognition: ^0.16.0`
- `intl: ^0.20.3`
- `shared_preferences: ^2.5.5`
- `http: ^1.5.0`
- `cupertino_icons: ^1.0.8`

The app uses a small native HTTP implementation for the Anthropic Messages API; no Anthropic Dart SDK is used.

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
- `lib/services/text_ai_service.dart` -- abstraction introduced in issue #20/PR #21: `TextAiTaskType` enum (`general`, `tosSummary`), abstract `TextAiService`, and `MockTextAiService`.
- `lib/services/anthropic_text_ai_service.dart` -- HTTP-backed implementation supporting the Anthropic Messages API or a compatible future Tower Lens proxy, including timeout, credential, billing, rate-limit, server, and malformed-response errors.
- `lib/services/text_ai_service_factory.dart` -- selects the mock when no credential is supplied; supports private direct-Anthropic development or a configurable endpoint with bearer authentication for a future proxy.
- `lib/models/library_entry.dart` -- library entry data model.
- `test/library_service_test.dart`, `test/text_ai_service_test.dart`, `test/anthropic_text_ai_service_test.dart`, `test/widget_test.dart` -- existing automated tests, including four mocked HTTP tests that make no paid API calls.
- `.github/workflows/android-ci.yml` -- installs Flutter, resolves dependencies, runs analysis and tests, builds the debug APK, and uploads it as the `tower-lens-debug` artifact with 14-day retention. The repaired workflow and PR #28 both completed successfully.

## 3. Feature status

| Feature | Status |
|---|---|
| Home screen: text/instruction input, mocked run, save to library | Implemented (mocked AI) |
| Local library: save/browse/search/sort/filter/delete, real files, survives uninstall | Implemented |
| ToS/privacy mode: paste, mocked structured summary, save | Implemented (mocked AI) |
| Ingredient/allergy watchlist: manage list, check text against it | Implemented (real logic, not AI-based) |
| Camera + on-device OCR: live preview, live recognition, freeze, editable pre-selected text | Implemented |
| Cohesive UI/UX redesign beyond the functional MVP shell | Not started — desired direction still needs definition after device testing |
| Dark theme (forced default) | Implemented |
| `TextAiService` abstraction with mock fallback | Implemented |
| Real Anthropic API integration | **Implemented for private development** -- merged in PR #28; production still requires a backend |
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

**Current milestone:** The local vertical slice and private-development Anthropic integration are implemented behind a swappable `TextAiService`. The mock fallback, loading/error state, library refresh notifications, tests, Android build repair, and working Flutter Android CI are merged. A future server can replace direct Anthropic calls through the existing configurable endpoint/authentication seam without changing the UI.

**Next milestone:** Install the current CI-produced APK on the Pixel 9a and complete the physical-device verification record below. After the baseline passes, the next product feature is AI explanation of ambiguous Watchlist ingredients. Any failing device behavior becomes its own narrowly scoped bug task before that feature begins.

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

**Human on-device verification pass.** Before further feature work, install the current CI-produced debug APK on the Pixel 9a and record the tested commit/run plus the result of every row below. Use the mock build for the complete local flow first. Direct-Anthropic testing is a separate final row and must use a private APK whose key is never committed or distributed.

| Device check | Required evidence | Status |
|---|---|---|
| Install and launch | APK installs, launches, and shows all four tabs | **Pass** — Pixel 9a, 2026-07-22; CI `tower-lens-debug` app-code baseline `f719507`; installed, launched, and all four tabs visible |
| Permissions and folder setup | Storage settings flow returns to the app; folder picker selects/creates the library | **Pass** — Pixel 9a, 2026-07-22; folder setup opened successfully, selected/created a test folder, returned to Tower Lens, and displayed the chosen folder |
| Home manual input | Paste/type, run mock explanation, edit, save | **Pass** — Pixel 9a, 2026-07-22; manual text/instruction entry, loading state, mock output, save confirmation, editing the input, and rerunning against the edited text all passed |
| Camera/OCR | Camera preview opens; capture/freeze produces editable recognized text; cancel/back works | **Pass** — Pixel 9a, 2026-07-22; camera permission, live preview, capture/freeze, OCR output, editing recognized text, and cancel/back behavior passed; returning to Home preserved the existing text |
| Camera denial/recovery | Deny camera safely, then grant it and retry without reinstalling | **Pass** — Pixel 9a, 2026-07-22; after permission was revoked in Android Settings, reopening the scanner returned to the Android camera-permission prompt without crashing, and granting permission reopened the live preview without reinstalling |
| Library | Saved item appears; refresh, search, sort, filter, open, and delete all work | **Fail** — Pixel 9a, 2026-07-22; saved item appeared and opened correctly. Searching for a known distinctive word returned no result. Deleting removed the item, but did so immediately without confirmation. Refresh, sort, and filter still to test |
| ToS | Paste text, run summary, read output, save, and reopen from Library | **Pass** — Pixel 9a, 2026-07-22; paste/input, loading state, structured mock summary, save confirmation, and reopening the saved entry from Library with its original text and structured summary all passed |
| Watchlist | Add/remove entries; matching and non-matching ingredient checks behave correctly | **Pass** — Pixel 9a, 2026-07-22; adding `peanut` succeeded, a scanned peanut bag triggered the expected warning, and an unrelated scanned item produced no warning. With both `peanut` and `milk` present, removing only `peanut` kept checking enabled through `milk`; rescanning the peanut bag no longer produced the peanut warning |
| Rendering and state | Dark theme/output contrast are readable; loading disables duplicate requests; an error can be retried | **In progress** — Pixel 9a, 2026-07-22; while a mock request was loading, the Run control was disabled and prevented a duplicate request. Readability and retry-after-error still to test |
| Restart persistence | Restart app; library path, saved scans, and Watchlist entries persist | **Pass** — Pixel 9a, 2026-07-22; after fully closing and reopening Tower Lens, the selected Library folder, saved ToS entry, and `milk` Watchlist item were all still present |
| Direct Anthropic private build | General and ToS calls return real responses; offline and invalid-key errors are understandable | Not run |
| No-camera behavior | Verify on a camera-less device/emulator when available; manual input remains usable | Deferred — no suitable device yet |

**Pass rule:** P0.5 is complete only when every non-deferred row is marked Pass with the tested app commit or Actions run recorded. A failure is documented and moved into a separate bugfix PR; it is not silently waived.

### P1 — Real API integration

**Task: Implement real Anthropic API-backed `TextAiService` — COMPLETE (merged in PR #28)**
- Objective: add a concrete `TextAiService` implementation that calls the real Claude API without breaking the existing mock path.
- Acceptance criteria met: `AnthropicTextAiService` implements the interface; the default model is configurable and currently `claude-haiku-4-5-20251001`; direct-development credentials come from `--dart-define`; the mock remains the no-credential fallback; Home and ToS use the factory through the established injected service boundary.
- Files: `lib/services/anthropic_text_ai_service.dart`, `lib/services/text_ai_service_factory.dart`, `lib/main.dart`, `pubspec.yaml`, `pubspec.lock`, README configuration documentation, and mocked HTTP tests.
- Tests: four mocked HTTP tests cover Messages API parsing, backend bearer authentication, rate-limit timing, and malformed successful responses; existing tests remain in CI.
- Remaining risk: a key compiled into an APK is extractable. Direct Anthropic configuration is private-development-only; distributed/production builds require the deferred backend/proxy.
- Completion evidence: PR #28 merged; dependency resolution, `flutter analyze`, tests, and debug APK build completed successfully in CI.

**Task: Loading state for AI calls — COMPLETE (merged in PR #23)**
- Objective: Home and ToS screens currently have no loading indicator despite `TextAiService.runTask` being genuinely async (mock includes an artificial delay specifically to surface this gap).
- Acceptance criteria: a loading indicator shows between tapping Run/Summarize and the output appearing; Run/Summarize button disabled while in flight.
- Files: `lib/screens/home_screen.dart`, `lib/screens/tos_screen.dart`.
- Dependencies: should land after P1 to avoid two agents editing the same two screens concurrently; could alternatively land just before P1 against the mock service, then simply keep working once P1 swaps the implementation.
- Risks: low, pure UI state.
- Completion evidence: both screens maintain an in-flight flag, disable relevant controls, render a progress indicator, and restore controls after success or failure (`30ef426`).

### P2 — Product experience and completeness

**Task: Restructure the app UI/UX around a deliberate visual and interaction design**
- Objective: replace the functional MVP feel with a cohesive app experience whose navigation, hierarchy, spacing, components, visual identity, and screen-to-screen flow match the intended Tower Lens product.
- Acceptance criteria: **UNKNOWN — DEFINE WITH USER** after the physical-device pass; begin with a short design brief and screen inventory, then implement the approved direction in small, testable increments rather than a single app-wide rewrite.
- Scope to evaluate: bottom-navigation structure and labels, Home/ToS/Watchlist relationship, scan and paste entry points, information density, component consistency, typography, color and contrast beyond the current forced-dark-theme fix, empty/loading/error states, and the overall tactile feel of common flows.
- Library requirement: replace the current top-of-screen folder-filter model with a hierarchical file-browser model. The main content area shows the current folder's immediate child files and folders; tapping a folder navigates into it; back/up navigation and breadcrumbs expose the current path; creating a folder places it inside the currently open folder; and users can move both files and folders to other locations in the tree. Preserve search, sort, filtering where useful, opening entries, deletion, and local readable-file storage. Require an explicit confirmation dialog with Cancel and Delete actions before deleting any file or folder; nothing should be removed merely by tapping the delete control.
- Save requirement: before saving a scan or analysis, let the user enter or edit its filename. Pre-fill a sensible generated default so saving can remain one tap when the user does not care about the name; validate or sanitize invalid filesystem characters and prevent accidental overwrites.
- Dependencies: complete P0.5 first so verified functional defects are separated from design dissatisfaction. The design brief should precede UI code.
- Risks: high overlap across screens; uncontrolled restyling could create bloat or regress accessibility and existing flows. Preserve behavior, local-first principles, and the `TextAiService`/storage boundaries.

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
- **Library search failure found during Pixel 9a verification (2026-07-22):** a saved entry was visible and opened correctly, but searching for a distinctive word known to occur in that entry produced no visible result. Reproduce against current `main`, determine whether indexing, query matching, folder scope, or UI refresh is responsible, and fix in a separate narrowly scoped bug PR.
- **Library deletion lacks confirmation (Pixel 9a verification, 2026-07-22):** deleting a saved entry successfully removed it, but the app displayed no confirmation dialog first. Add an explicit Cancel/Delete confirmation before removing saved files or folders; keep this as a focused safety fix rather than treating successful removal as a full pass.
- **Resolved in PR #24:** the confirmed `file_picker` Android regression was addressed by pinning `file_picker: 10.3.8` exactly. CI and physical-device confirmation remain required before treating the full app as verified.
- Issue #5 was closed as `completed` before its PR (#6) merged. Its required README sentence is now present on `main` via later commit `9822806`, but the historical process-integrity gap still needs the P3 workflow audit.

**Technical debt:**
- No automated integration/widget test coverage for Library, ToS, Watchlist, or Camera screens. `LibraryService` has notification-focused unit tests, alongside the `TextAiService` mock unit test and the default Flutter widget smoke test.
- Home/ToS loading and retry-safe error states are implemented. The Anthropic service maps timeouts, connection failures, credential/billing errors, rate limits, server errors, and malformed responses; physical verification of those user-visible paths remains part of P0.5.
- Storage/search-filter approach (live directory scan, no cache) has not been stress-tested at scale; fine for the expected personal-use volume (dozens to low hundreds of entries) but unverified beyond that.

**Security/privacy concerns:**
- `MANAGE_EXTERNAL_STORAGE` is a broad, Google-Play-scrutinized permission. Acceptable for local sideloaded development; **unresolved decision** for eventual public release -- may need to migrate to per-folder Storage Access Framework access, or provide Play Console justification, before store submission.
- Real API integration must supply the key via `--dart-define` or equivalent, never committed or hardcoded. Longer-term, per original product scope, production API keys must never ship inside the client at all -- a backend/proxy is required before any public release, and is explicitly not yet started.

**Unresolved product decisions:**
- The target visual language, navigation model, and interaction feel for the planned UI/UX restructure; define these with references and a screen-by-screen brief before implementation. The Library navigation model is decided: it should behave as a hierarchical file browser rather than expose folders primarily as top-level filters. Saving should expose an editable filename with an automatically generated default.
- Whether/how the camera entry point should degrade on a device with no camera hardware (manifest currently allows install via `android:required="false"`, but the resulting UX on such a device is untested).
- Exact backend/proxy architecture and timing for production API key custody.

## 8. Release and monetization phases

**MVP (current phase):** local-first, no accounts, no payments, and no backend. Mock responses remain the safe default; private builds can use the real Anthropic service behind `TextAiService`. No monetization infrastructure exists or is needed yet.

**Post-MVP, pre-commercial:** complete physical-device verification and use direct Claude API calls only for private development with a key supplied by `--dart-define`. This is not viable for distributed/public releases under the no-client-side-secrets principle.

**Commercial phase (not started, no work should begin here until MVP + real API integration are solid):** backend/proxy holding the real API key server-side, credit-based metering (or subscription -- undecided), Google Play Billing integration for Android, no ads, no forced subscription, fair pay-as-you-go framing per original product principles.

## 9. Recommended execution order

1. **P0 — Pin `file_picker` to `10.3.8`. COMPLETE.** Merged in PR #24; retain this step as completion history.
2. **P0.5 — Human on-device verification pass** against the current CI-produced APK. IN PROGRESS; use the preserved evidence table above.
3. **P1 — Real Anthropic API integration. COMPLETE.** Merged in PR #28; retain this step as completion history. Re-check real responses and error presentation during P0.5.
4. **P1 — Loading state UI. COMPLETE.** Merged in PR #23; retain this step as completion history. Re-check it during the physical-device pass.
5. **P2 — Define the UI/UX redesign.** After P0.5, produce a concise design brief and screen inventory with the user before changing UI code; implement the approved direction as small increments.
6. **P3 — Issue-closing process fix.** Independent of all app-code tasks (touches only `.github/workflows/`), safe to run in parallel with any of the above.
7. **P2 — Watchlist AI-explanation feature.** Depends on task 3 (P1) being complete; sequence it against the UI redesign once that brief establishes the Watchlist flow.
8. Everything under "Deferred / explicitly out of scope" remains untouched until the above is solid and a deliberate decision is made to begin commercial-phase work.

## 10. Next task for Codex

**Perform and record P0.5 on-device verification.** Download the `tower-lens-debug` artifact from the latest successful `main` Android CI run, install it on the Pixel 9a, and complete every non-deferred row in the preserved checklist. Test the mock/local paths first. Test real Anthropic only with a separate private build containing the development key; never upload or distribute that APK. Any failure becomes a narrowly scoped bug task and PR. Once the gate passes, define the P2 UI/UX redesign brief and screen inventory with the user before choosing whether the first implementation increment is the app shell/navigation or the Watchlist ingredient-ambiguity flow.
