# Tower Lens — Roadmap

## 1. What Tower Lens is

Tower Lens is a privacy-first, local-first Flutter Android app (initially targeting a Pixel 9a) that lets a user scan or paste dense real-world text -- books, ingredient labels, Terms of Service, manuals, warnings -- and ask an AI to summarize, simplify, or analyze it using a custom instruction. Camera scanning with on-device OCR is the intended primary input method; manual paste/type is a fully supported secondary path.

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
Android PDF text extraction uses the Apache-2.0-licensed
`com.tom-roush:pdfbox-android:2.0.27.0` dependency through a narrow platform
channel. TXT and Markdown imports are decoded locally in Dart.

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
- `lib/services/text_ai_service.dart` -- abstraction introduced in issue #20/PR #21: mode-specific `TextAiTaskType` values for custom instructions, structured summaries, text simplification, and ToS analysis; abstract `TextAiService`; and `MockTextAiService`.
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
| Ingredient/allergy watchlist: manage list, high-fidelity scan, multi-pass AI risk analysis | **Implemented and device-verified through PR #45** |
| Camera + OCR: live local recognition plus optional Claude-assisted High-Fidelity Mode | **Implemented and device-verified through PR #44** — High-Fidelity Mode is substantially more accurate; hostile real-world OCR stress testing is moved to beta testing |
| Cohesive UI/UX redesign beyond the functional MVP shell | **Implemented and device-verified** — navigation, launcher layout, appearance/accessibility, Settings organization, theme consistency, crisp holographic surfaces, and app-wide polish are complete; deeper asset/shader art direction is deferred to Step 9 |
| Dark theme (forced default) | Implemented |
| `TextAiService` abstraction with mock fallback | Implemented |
| Real Anthropic API integration | **Implemented for private development** -- merged in PR #28; production still requires a backend |
| Shared backend/proxy for production API key handling across the active app | Not started; the dormant Price Check feature has its own implemented backend |
| Credits / metered billing | Not started (correctly deferred per scope) |
| Accounts / authentication | Not started (correctly deferred per scope) |
| Payments (Google Play Billing) | Not started (correctly deferred per scope) |
| Ads | Not implemented, not planned unless explicitly revisited |
| Price-check / marketplace estimate mode | **Implemented, hidden, and deferred to beta/public release** — PR #59 merged the configurable remote client, server-side Claude identification and cited web research, separate Buyer/Seller calls, metadata-safe transient uploads, and real local folder persistence/import. The code is preserved, but its Tools card is hidden until activation, deployment, device verification, and prompt refinement resume for beta/public release. |
| iOS support | Not started, explicitly deferred |
| PDF/Obsidian export beyond native Markdown | Not started |
| PDF, TXT, and Markdown import | **Implemented and device-verified** — local extraction into editable Home/ToS source fields; all phone checks passed 2026-07-27 |
| Loading UI state for `TextAiService` calls | **Implemented** -- Home and ToS disable in-flight controls, show progress indicators, and surface a retry-safe error message |
| On-device verification of everything since the last confirmed working build | **Not done** -- see Known Bugs |

## 4. Current milestone and next milestone

**Current milestone:** The core private-development app is implemented and device-verified through Step 6. Price Check's full staged code was merged in PR #59, but the feature is intentionally hidden from the launcher and deferred to Step 10 beta testing. Tower Lens now presents the four active tools followed by an always-last `More features coming soon` card. Production distribution infrastructure is Step 7, the public blurb and shader research are Steps 8–9, and beta testing follows in Step 10.

**Next milestone:** Prepare the active app for public distribution in Step 7. Price Check remains dormant until its activation, backend deployment, live-item device verification, and tool-specific prompt refinement are handled inside Step 10 beta testing.

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
| Library | Saved item appears; refresh, search, sort, filter, open, and delete all work | **Pass through PR #40** — Pixel 9a, updated 2026-07-27; existing data and Markdown, nested folders, breadcrumbs/Up navigation, custom-folder saves, AI-suggested editable filenames, all sorting options, scoped/root search, overwrite protection, file/folder rename and move, file/folder deletion confirmation, sanitization, restart persistence, long-press actions, drag-and-drop moves, destination highlighting, and post-move destination navigation pass. |
| ToS | Paste text, run summary, read output, save, and reopen from Library | **Pass** — Pixel 9a, 2026-07-22; paste/input, loading state, structured mock summary, save confirmation, and reopening the saved entry from Library with its original text and structured summary all passed |
| Watchlist | Add/remove entries; matching and non-matching ingredient checks behave correctly | **Pass** — Pixel 9a, 2026-07-22; adding `peanut` succeeded, a scanned peanut bag triggered the expected warning, and an unrelated scanned item produced no warning. With both `peanut` and `milk` present, removing only `peanut` kept checking enabled through `milk`; rescanning the peanut bag no longer produced the peanut warning |
| Rendering and state | Dark theme/output contrast are readable; loading disables duplicate requests; an error can be retried | **Pass** — Pixel 9a, updated 2026-07-25; Home and ToS text and Markdown outputs are readable, loading prevents duplicate requests, offline failures show readable errors, controls recover, failed attempts cannot be saved, and both modes retry successfully after reconnecting without an app restart. |
| Restart persistence | Restart app; library path, saved scans, and Watchlist entries persist | **Pass** — Pixel 9a, 2026-07-22; after fully closing and reopening Tower Lens, the selected Library folder, saved ToS entry, and `milk` Watchlist item were all still present |
| Direct Anthropic private build | General and ToS calls return real responses; offline and invalid-key errors are understandable | **Pass** — Pixel 9a, updated 2026-07-25; user-entered valid keys produce real Home and ToS responses, invalid keys produce an understandable credential error, key save/replace/removal no longer asserts or freezes, and offline errors recover after reconnecting. Timeout, billing, rate-limit, server, and malformed-response mappings remain covered by automated tests because they are not safely forceable from the current UI. |
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
- Library requirement: replace the current top-of-screen folder-filter model with a hierarchical file-browser model. The main content area shows the current folder's immediate child files and folders; tapping a folder navigates into it; back/up navigation and breadcrumbs expose the current path; creating a folder places it inside the currently open folder; and users can move both files and folders to other locations in the tree. Long-pressing a file or folder enters contextual selection mode for rename, move, and delete. Files and folders can also be dragged onto valid folder rows or breadcrumb destinations; valid destinations highlight, and a successful drop opens the destination so the moved item is immediately visible. Preserve search, sorting, filtering where useful, opening entries, deletion, and local readable-file storage. Replace the current narrow sorting control with a visible dropdown that shows the active choice and initially supports Newest, Oldest, Name A–Z, Name Z–A, and Type. Keep the selected sort stable while navigating folders, and apply it consistently to the current folder's contents. Require an explicit confirmation dialog with Cancel and Delete actions before deleting any file or folder; nothing should be removed merely by tapping the delete control.
- Save requirement: before saving a scan or analysis, let the user enter or edit its filename. Pre-fill a sensible generated default so saving can remain one tap when the user does not care about the name; validate or sanitize invalid filesystem characters and prevent accidental overwrites.
- Dependencies: complete P0.5 first so verified functional defects are separated from design dissatisfaction. The design brief should precede UI code.
- Risks: high overlap across screens; uncontrolled restyling could create bloat or regress accessibility and existing flows. Preserve behavior, local-first principles, and the `TextAiService`/storage boundaries.

**Task: Route Watchlist ingredient-risk evaluation through real AI — COMPLETE; DEVICE-VERIFIED**
- Objective: preserve fast local exact matching while using Claude to evaluate exact, categorical, and contextual ingredient risks against the user's watchlist.
- Implemented behavior: Watchlist camera scans always use locked High-Fidelity OCR with no toggle. After text review, local exact matches appear immediately. With real AI configured, Tower Lens runs three independent label reviews and sends all three reports, the high-fidelity OCR text, and the watchlist to a fourth synthesis request.
- Output contract: every result begins with the safety disclaimer; separates exact matches, categorical matches, contextual warnings, and uncertainty/label claims; identifies supporting label wording; treats negated or "free-from" claims as warnings to verify rather than confirmed red flags; accounts for may-contain/shared-equipment wording and OCR uncertainty; never declares a product safe.
- Offline/degraded behavior: local exact matching remains usable without AI, and remains visible if AI analysis fails.
- Files: `lib/screens/watchlist_screen.dart`, `lib/screens/camera_scan_screen.dart`, `lib/services/text_ai_service.dart`, `lib/services/anthropic_text_ai_service.dart`, and focused tests.
- Dependencies: P1 and High-Fidelity OCR.
- Completion evidence: PR #45 merged after CI passed analysis, unit/widget tests, and debug APK compilation. Pixel 9a device testing confirmed the locked High-Fidelity Watchlist flow, multi-pass analysis, synthesis output, safety disclaimer, exact/categorical/contextual risk handling, and usable end-to-end behavior.

**Task: Import existing text files into Tower Lens — COMPLETE (merged in PR #41)**
- Objective: let users import existing PDF, TXT, and Markdown files as source material instead of requiring camera OCR or manual paste.
- Acceptance criteria: users can choose a supported file, review the extracted text before submitting it, and preserve the original filename as the editable save-name default; unsupported, unreadable, or empty files produce a recoverable error.
- Formats: PDF (`.pdf`), plain text (`.txt`), and Markdown (`.md`).
- Dependencies: none. The broader Step 4 automated-coverage expansion is deferred by user direction; the existing CI analysis, test, and APK build gate remains required for this increment.
- Completion evidence: PR #41 merged; CI passed analysis, all existing tests, debug APK compilation, and artifact upload. All eleven Pixel 9a checks passed on 2026-07-27, including Home and ToS imports, editable TXT/Markdown, multi-page PDF extraction, analysis and saving, stale-output clearing, picker cancellation, unsupported-file filtering, offline extraction, and existing-flow regression checks.

**Task: Refine the prompts sent to the AI service — COMPLETE; DEVICE-VERIFIED**
- Objective: deliberately improve the mode-specific prompts for summary quality, structure, accuracy, tone, and faithfulness to the source text rather than treating the first functional prompts as final product behavior.
- Home acceptance criteria:
  - Custom instructions remain available when no preset is selected.
  - Selecting a preset disables and visually grays the custom-instruction editor; selecting the active preset again restores the editor without discarding its text.
  - `Summarize` produces a quick blurb, a main-points list, and then a high-fidelity, high-detail breakdown.
  - `Simplify Text` rewrites rather than summarizes, preserves the original paragraphs and meaning as closely as possible, and targets a selectable common-word cutoff from the top 10,000 to top 5,000 English words in 1,000-word increments. The slider resets to Highest accuracy whenever the mode is selected.
  - Question-answer and report-generation presets are removed to keep the product focused on reducing reading barriers rather than replacing user creativity.
- ToS acceptance criteria: begin with a short summary, then prioritize immediate notices, potential major consequences, ordinary restrictions, unusual or suspicious terms, and missing information. Cover charges; cancellation/refunds; notices and changes; data/metadata collection, use, sale, advertising, AI, retention, deletion, international transfer, and jurisdiction; content ownership and licenses; surrendered rights; arbitration/class-action/jury waivers and opt-outs; liability, warranties, indemnity, and responsibilities; account control; eligibility; prohibited uses; and third parties. Preserve exact deadlines, fees, exceptions, and consequences and keep the output informational rather than legal advice.
- Cost transparency: show a local pre-run estimate of total input/output token usage as a range with an 80% confidence indicator. Anthropic still requires `max_tokens`, so use a generous request-specific safety ceiling from 4,096 up to the configured Haiku model's 64,000-token output capacity rather than the former fixed 1,200-token output limit; the estimate itself is not a cap and makes no API call.
- Vocabulary reference: https://www.top10000words.com/english/top-10000-english-words
- Files: Home and ToS screens, `TextAiService`, `AnthropicTextAiService`, token estimation, Markdown-editor enabled state, and focused automated tests.
- Dependencies: none. Existing API-key/error verification keeps transport and lifecycle failures separate from output-quality decisions.
- Device evidence from 2026-07-27: preset selection/deselection, custom-instruction preservation and disabled appearance, the Simplify Text slider/reset, token estimates, summary structure, and short-text simplification all passed on the Pixel 9a. Multi-page Simplify Text and the mock ToS timed out because every request still used the original fixed 45-second limit.
- Timeout follow-up: ordinary requests retain the 45-second minimum. Predicted output beyond 1,500 tokens adds request time, with more aggressive scaling for full-text simplification and ToS analysis and a 10-minute hard ceiling. Home and ToS show the estimated maximum duration before a long or complicated request is submitted; focused calculation and widget tests cover the behavior.
- Final device evidence from 2026-07-28: the user approved the prompt modes, token and duration estimates, short and long simplification behavior, and ToS analysis after the dynamic-timeout follow-up.

**Task: Improve camera/OCR reliability for dense and angled text — COMPLETE FOR MVP (merged in PR #44; device-verified)**
- Objective: make camera scanning dependable for full pages, dense layouts, and imperfect real-world captures.
- Implemented behavior: normal mode retains fast, entirely on-device live ML Kit OCR. Optional High-Fidelity Mode switches to maximum camera resolution, captures a still on Freeze, and asks Claude to reconstruct the text from the image plus the frozen and five preceding local OCR readings. It preserves editable review/rescan behavior, shows processing and privacy/cost notices, deletes the temporary still, and falls back to local OCR on failure.
- Device evidence from 2026-07-27: High-Fidelity Mode works on the Pixel 9a and produces substantially better OCR than the prior scanner.
- Follow-up evaluation: moved to beta testing. Test small print, dense full pages, headings plus paragraphs, columns, uneven lighting, and angled pages across real users and documents; only add cropping, boundary guidance, or perspective correction if beta evidence shows they are needed.
- Privacy/cost: normal mode remains entirely on-device. High-Fidelity Mode explicitly warns that it sends the scanned image and recent OCR readings to Claude and uses credits.
- Dependencies: broader automated-coverage expansion remains deferred.

### Deferred / explicitly out of scope for now (per product principles, not forgotten)

- No-camera device/emulator verification until suitable hardware or an emulator is available.
- iOS support.
- Ads (not planned unless explicitly revisited).
- PDF/Obsidian-specific export beyond native Markdown. PDF, TXT, and Markdown **import** are planned in Step 4 and are not deferred.


## 7. Known bugs, technical debt, security/privacy concerns, unresolved decisions

**Known bugs:**
- **Resolved — API-key dialog lifecycle assertion (verified 2026-07-25):** saving, replacing, and removing valid or invalid keys no longer triggers the `_dependents.isEmpty` assertion or leaves the app unresponsive.
- **Resolved — Library search failure (verified 2026-07-25):** distinctive source/output keywords, case-insensitive queries, structured Markdown output, and search within the selected folder now work on the Pixel 9a.
- **Resolved — Library deletion confirmation (verified 2026-07-25):** both file and recursive folder deletion require explicit confirmation, and Cancel leaves the item intact.
- **Resolved in PR #24:** the confirmed `file_picker` Android regression was addressed by pinning `file_picker: 10.3.8` exactly. CI and physical-device confirmation remain required before treating the full app as verified.

**Technical debt:**
- Automated coverage is still incomplete across the full app. Library service/widget tests now cover nested browsing, sorting, search-related parsing, safe save destinations and filenames, overwrite protection, deletion confirmation, AI-suggested titles, and file/folder rename and move operations. Broader ToS, Watchlist, Camera/OCR, persistence, retry, and Library-scale coverage remains in Step 4.
- Home/ToS loading and retry-safe error states are implemented. The Anthropic service maps timeouts, connection failures, credential/billing errors, rate limits, server errors, and malformed responses; physical verification of those user-visible paths remains part of P0.5.
- Storage/search-filter approach (live directory scan, no cache) has not been stress-tested at scale; fine for the expected personal-use volume (dozens to low hundreds of entries) but unverified beyond that.

**Security/privacy concerns:**
- `MANAGE_EXTERNAL_STORAGE` is a broad, Google-Play-scrutinized permission. Acceptable for local sideloaded development; **unresolved decision** for eventual public release -- may need to migrate to per-folder Storage Access Framework access, or provide Play Console justification, before store submission.
- Real API integration must supply the key via `--dart-define` or equivalent, never committed or hardcoded. Longer-term, per original product scope, production API keys must never ship inside the client at all -- a backend/proxy is required before any public release, and is explicitly not yet started.

**Unresolved product decisions:**
- The target visual language, navigation model, and interaction feel for the planned UI/UX restructure; define these with references and a screen-by-screen brief before implementation. The Library navigation model is decided: it should behave as a hierarchical file browser rather than expose folders primarily as top-level filters. Its sort control should be a visible multi-option dropdown rather than a narrow newest/oldest toggle. Saving should expose an editable filename with an automatically generated default.
- Whether/how the camera entry point should degrade on a device with no camera hardware (manifest currently allows install via `android:required="false"`, but the resulting UX on such a device is untested).
- Exact backend/proxy architecture and timing for production API key custody.

## 8. Release and monetization phases

**MVP (current phase):** local-first, no accounts, no payments, and no backend. Mock responses remain the safe default; private builds can use the real Anthropic service behind `TextAiService`. No monetization infrastructure exists or is needed yet.

**Post-MVP, pre-commercial:** complete physical-device verification and use direct Claude API calls only for private development with a key supplied by `--dart-define`. This is not viable for distributed/public releases under the no-client-side-secrets principle.

**Commercial phase (not started, no work should begin here until MVP + real API integration are solid):** backend/proxy holding the real API key server-side, credit-based metering (or subscription -- undecided), Google Play Billing integration for Android, no ads, no forced subscription, fair pay-as-you-go framing per original product principles.

## 9. Recommended execution order

1. **Library safety and hierarchical file browser — COMPLETE.** Confirmation for file/folder deletion, nested folders, breadcrumbs and up navigation, create/move/rename operations, visible sorting, editable AI-suggested filenames, overwrite protection, long-press contextual actions, drag-and-drop moves onto folders and breadcrumbs, and preservation of search, filtering, Markdown, and local-first storage are implemented and device-verified through PR #40.

2. **File import — COMPLETE.** User-facing PDF, TXT, and Markdown import, local extraction, editable review, recoverable errors, and original-filename preservation are implemented and device-verified through PR #41. Broader automated coverage remains explicitly deferred.

3. **AI prompt refinement — COMPLETE.** Presets, token estimates, duration warnings, structured summaries, Simplify Text, and detailed ToS analysis are implemented and approved on the Pixel 9a. Dynamic timeouts resolved the long-request cutoff without changing prompts or token ceilings.

4. **Camera/OCR reliability — COMPLETE FOR MVP.** PR #44 added optional Claude-assisted High-Fidelity Mode using a maximum-resolution still plus recent local OCR readings; the Pixel 9a device check shows a substantial reliability improvement. Hostile real-world OCR stress testing belongs to Step 10 beta testing.

5. **Watchlist AI explanations — COMPLETE.** PR #45 is merged and device-verified. Watchlist scans require High-Fidelity OCR; immediate local matching is preserved; three independent Claude risk reviews feed a fourth synthesis pass that distinguishes exact, categorical, contextual, and uncertain/free-from evidence and always leads with the safety disclaimer.

6. **Define and implement the UI/UX redesign — COMPLETE.** The functional redesign is implemented and verified on the Pixel 9a. The app now uses three persistent destinations (Tools, Library, and Settings); Tools opens by default; the featured tool spans the full launcher width; tool selection, usage-based featuring, persistence, and every existing workspace remain functional. Settings uses grouped destinations in the approved order, with appearance and accessibility controls persisted app-wide. Light/dark modes, semantic text and background colors, text scaling, glass intensity, and motion controls are applied consistently. Device-polish follow-ups restored a non-floating navigation bar, removed unnecessary tab fades, corrected launcher sizing and clipping, and replaced backdrop blur with crisp cyan/violet/rose spectral lighting. The remaining desire for a more expressive holographic/sci-fi identity requires visual references, assets, and shader research and is intentionally deferred to Step 9.

   **Deferred Price Check specification — scheduled under Step 10 beta testing.** PR #59 merged the dedicated tool that identifies ordinary secondhand items, researches their current market, estimates a price range, and optionally produces separate Buyer and/or Seller guidance. All implementation remains in the repository, but Price Check is hidden from the Tools launcher for now and replaced there by an always-last `More features coming soon` card. Do not delete or dismantle the dormant feature. It remains a decision aid, not a certified appraisal, authenticity check, legal determination, or guarantee of what an item will sell for.

   **User flow and run choices:**
   1. The user supplies the required photo and item fields, fills any optional accuracy fields, chooses `Default` or `In-depth`, and selects `Buyer guidance`, `Seller guidance`, or both.
   2. The app shows the estimated credit range and estimated maximum duration, using request-specific dynamic timeouts like the existing text-analysis tools. It does not expose search counts or a monetary-cost estimate.
   3. The remote backend sends the normalized photos and input fields to Claude with the identification instructions appropriate to the selected credit tier.
   4. Claude identifies the likely item and checks whether it is restricted, illegal, or unsuitable for general pricing. The user must confirm or edit the identification before any market research begins.
   5. After confirmation, the backend runs the selected depth of cited market research and produces the shared market estimate.
   6. The backend then passes the completed market research into one separate Buyer-analysis process, one separate Seller-analysis process, or both, exactly as selected. These downstream analyses consume additional tokens but do not repeat the web research.
   7. The app displays the shared market result plus distinct Buyer and Seller output fields. Each selected guidance type is also saved as its own file. Generating one never silently generates or charges for the other.

   **Credit tiers:**
   - `Default` is the normal run: confirmed identification, focused cited research, three to eight strong comparables when available, an evidence-qualified price range, confidence, and basic risks.
   - `In-depth` uses a broader/deeper identification and market-research process for a more thorough, higher-credit decision-assistant result. It does not automatically include Buyer or Seller guidance; those remain independent selections available to both tiers.
   - Detailed search counts and prompt/search strategy will be finalized during the post-functionality prompt-refinement pass. Both tiers must use explicit general pricing guidelines rather than relying on an unconstrained request to "find a price."

   **Inputs:**
   - Required for every new run: at least one photo, condition, tested status, known issues (including damage or missing parts), quantity, ZIP/postal code, and country.
   - Optional accuracy fields: description or pasted listing text/link, known make/model/variant/age or other identifying information, additional photos up to five total, included accessories, user modifications, asking price, and user-supplied comparison links or screenshots.
   - The form begins with the compact required set and progressively exposes the larger optional field set. Normal photo analysis should read visible labels, model numbers, and barcodes; a dedicated barcode scanner is not part of this MVP.
   - ZIP/postal code is strongly recommended context and is required alongside country so research can use a reasonably accurate local market and check applicable restrictions without requesting device-location permission.
   - Output pricing uses the normal/default currency of the selected country. Item price is the comparison basis; shipping, taxes, platform fees, and net proceeds are not added to the MVP estimate.

   **Identification, safety, and category boundaries:**
   - Identification distinguishes photo-observed facts, user-supplied claims, and Claude inferences; reports uncertainty or conflicts; and returns an editable identification card for explicit confirmation.
   - At the identification stage, fully stop restricted or illegal items from entering market research or Buyer/Seller analysis. Claude may use the supplied ZIP/postal code and country to determine relevant local restrictions. The result explains why the item cannot proceed without providing pricing or transaction guidance.
   - Do not impose a narrow ordinary-goods category allowlist. The general pricing pipeline should attempt any lawful item for which ordinary comparable-market evidence can support a useful range.
   - Do not price specialist, unique, rare, antique, or collectible items whose value materially depends on individualized expertise, provenance, authentication, professional grading, or condition inspection. Identify the likely category and explain why specialist valuation is needed.
   - Category names alone do not force rejection: ordinary vehicles, jewelry, watches, art, medical devices, and similar goods may proceed when they are lawful and adequate ordinary comparable data exists. The identification gate decides based on the actual item's restriction and valuation needs.

   **Market research and evidence rules:**
   - Use current, public, attributable web evidence through Claude's cited web-search capability, following a deliberate search procedure that will be refined after functional implementation.
   - Prefer recent completed/sold transactions when available. Active listings may be used as clearly labeled asking-price evidence, but must never be represented as confirmed sales or silently mixed with sold results.
   - User-supplied listing/comparison links and screenshots are allowed as additional evidence. Never scrape authenticated pages, bypass access controls, automate marketplace accounts, post listings, or contact buyers or sellers.
   - Preserve the source URL, retrieval date, currency, sale/listing status, condition, item price, match quality, and relevant unknowns for each cited comparable. Rank exact model/variant and similar-condition results first; exclude or visibly down-rank lots, parts-only listings, reproductions, mismatched specifications, materially different condition, suspicious outliers, and uncertain identities.
   - Show the strongest three to eight comparables rather than every search result. Separate verified sold/completed evidence from active asking prices.

   **Shared market result:**
   - Show the confirmed identification, evidence date, geographic/currency context, comparable table, important assumptions, factors moving value up or down, and a rounded market price range rather than a single precise number.
   - Show `High`, `Medium`, or `Low` confidence with a plain-language reason. Do not use a pseudo-precise percentage.
   - When evidence is too weak for a reliable appraisal, explicitly say `No reliable estimate`, explain what is missing and how to improve it, and still provide a clearly labeled broad, low-confidence likely range when the available evidence supports even that much. If no defensible range exists, do not invent one.
   - Always state that the result is informational and not a professional appraisal, authenticity determination, safety inspection, legal opinion, or sale guarantee. Surface evidence-based counterfeit, stolen-property, recall, damaged-battery, personal-data, and similar risks without asserting wrongdoing as fact.

   **Separate Buyer analysis:**
   - Consume the completed shared research in a new Claude process; do not redo identification or web research.
   - Return an asking-price/deal assessment, suggested opening-offer range, walk-away ceiling range, questions to ask, tests to perform, missing-accessory and repair-cost considerations, and relevant scam/counterfeit/account-lock/stolen-property/recall/battery-damage warnings.
   - Use price ranges throughout. The Buyer analysis has its own screen field and its own saved output file.

   **Separate Seller analysis:**
   - Consume the completed shared research in a new Claude process; do not redo identification or web research.
   - Return `Quick sale`, `Fair listing`, and `Patient/optimistic listing` price ranges; an editable listing title and description; recommended photos; a disclosure checklist; and a negotiation-floor range.
   - Do not recommend a marketplace or calculate expected net proceeds. The Seller analysis has its own screen field and its own saved output file.

   **Privacy, saving, importing, and failure behavior:**
   - Keep inputs on-device until the user explicitly starts the relevant stage. Strip EXIF metadata before upload, clearly preview what will be sent, and delete backend temporary images after the run.
   - Saving is manual. Each saved price check creates a folder in the user's chosen Library location. That folder contains the saved photos, a separate input-fields file, the shared identification/research/estimate output, and separate Buyer and/or Seller analysis files for whichever processes were run.
   - A new run may import a previous Price-check folder instead of starting from blank fields. Its photos and input fields auto-fill and remain editable.
   - Prior analysis must not bias the new identification, search, estimate, or Buyer/Seller analysis. The prior outputs are summarized in a separate Claude process, withheld from the new market pipeline, and used only after the new analysis is complete to describe market changes between the dated runs.
   - Price Check is entirely unavailable offline except for opening existing saved folders/reports through the Library; it must never substitute model-memory or cached prices for live research.
   - Preserve editable inputs after identification or research failure. Never save a failed run as a successful estimate. No marketplace actions, account connections, background monitoring, alerts, inventory management, bidding, payments, shipping purchase, or tax/investment guidance are included.

   **Architecture and implementation order:**
   1. `PR 1 — Complete mock workspace/UI — COMPLETE:` the fifth Tools card and dedicated Price-check workspace now cover required and optional fields; camera or file photo input with one-to-five-photo management; Default/In-depth selection; independent Buyer/Seller selections; token and duration estimate surfaces; a persistently dismissible privacy review; editable identification confirmation; shared estimate/comparables; distinct Buyer, Seller, and prior-run market-change outputs; exact save-folder/import-folder previews; and exclusion, low-evidence, offline, loading, error, and retry states. Device feedback also restored launcher tool colors without glass, enlarged the featured card, removed screen fades, reduced motion globally, added free-entry quantity, and enabled tap-outside keyboard dismissal. Market results remain deterministic mock data; focused widget/model tests cover launcher integration, confirmation gating, dual guidance, prior-run import, restricted items, low evidence, and warning persistence. Live research and Library persistence remain excluded from this increment.
   2. `PR 2 — Full functionality — COMPLETE; MERGED IN PR #59:` the repository now includes the remote backend/API proxy and production-safe provider-key custody; structured contracts for identification, confirmation, research, Buyer analysis, Seller analysis, prior-run summarization, and market-change comparison; cited Claude web research; dynamic token/duration estimates and timeouts; metadata-safe transient photos; local multi-file folder persistence/import; and focused automated coverage.
   3. `Activation and prompt refinement — DEFERRED TO BETA/PUBLIC RELEASE:` deploy the backend, restore the launcher entry, test real items on the Pixel 9a, and refine the identification, exclusion/legal-check, Default/In-depth research, evidence ranking, price-range, Buyer, Seller, previous-run summary, and market-change comparison prompts. Finalize the exact research-depth/search behavior during that release phase.

7. **Prepare for public distribution.** Build the shared production backend for the active app, add accounts/authentication and Google Play Billing, and resolve broad Android storage permission before store release. Price Check deployment and activation remain excluded here and are handled under Step 10.

   - **Public-information UI complete:** Settings now opens real About Tower Lens, Terms of Service, Privacy Policy, Contact Developer, and Support Developer screens. Contact uses a private Web3Forms form with required subject/message fields and optional reply email; Support Developer opens Ko-fi. The legal text is deliberately marked pre-release and must be reviewed/finalized once the production backend, account deletion flow, and billing behavior exist.
   - **Tutorial remains separate:** the Tutorials destination is preserved as a placeholder, but the first-launch/setup tutorial is its own follow-up increment and is not bundled into the public-information UI.

   **Approved beta billing model:**
   - Use one-time credit packs only. Do not launch with a subscription. A subscription may be reconsidered later only if users ask for it.
   - Let users explore the app and tutorial without an account, but require `Continue with Google` before buying credits so the backend can preserve purchased balances across reinstalls and devices.
   - Give no free starting credits during beta. Grant 1.5x the normal credits on the user's first completed credit purchase instead, applying the multiplier before the final whole-credit rounding.
   - Keep the currency legible: one estimated Claude token corresponds to one base credit. Apply the approved 3x operating charge plus a 0.15x Google Play allowance, for a total of 3.15 credits per estimated/actual provider token. Every tool must show the 3.15x credit estimate before a run rather than exposing the unmultiplied provider-token estimate.
   - Launch with whole-dollar purchase options of $1, $2, $5, $10, and $20, plus a custom whole-dollar amount. Do not use `.99` prices. Implement Custom through Google Play's supported multi-quantity purchase flow for the $1 consumable product, and grant credits only from the quantity verified by the backend.
   - Grant a clean 50,000 normal credits per whole purchase dollar. Presets therefore grant 50,000 / 100,000 / 250,000 / 500,000 / 1,000,000 credits for $1 / $2 / $5 / $10 / $20. Custom amounts use the same 50,000-credits-per-dollar rule. This deliberately rounds down from the output-rate-derived 66,666 credits per dollar; together with the 3.15x usage charge, that conservative grant covers Google's 15% cut even on the first-purchase bonus under the approved simplified cost model.
   - Grant 1.5x credits on the first completed purchase: 75,000 / 150,000 / 375,000 / 750,000 / 1,500,000 for the presets. Under the simplified share model, `3.15 / 1.5 = 2.1x`; the conservative 50,000-credit pack grant keeps the purchase non-loss-making after Google's cut while giving up the intended developer-profit share.
   - The estimate is not the final debit. After each successful Claude request, the production backend must read Claude's reported `input_tokens` and `output_tokens`, sum them, calculate `ceil(actual provider tokens x 3.15)`, and atomically debit that many credits from the user's server-side balance. Failed provider requests must not be charged. The app must display the server-confirmed debit; it must never calculate or authorize the balance mutation locally.
   - Do not implement silent automatic charging. Let users choose a preferred refill pack, low-balance threshold, and monthly spending ceiling; below the threshold, offer a quick-refill prompt that still opens Google Play's required purchase confirmation. Stop prompting after the chosen monthly ceiling is reached.
   - **Balance/shop UI implemented ahead of the server:** the Tools header displays a tappable credit balance, Settings links to a complete Shop screen, and the Shop presents the approved presets, Custom whole-dollar entry, 1.5x first-purchase bonus, and prompted-refill preferences. Until authentication and billing are connected, a preview account store returns a zero balance and purchase actions explicitly make no balance change. Replace that store with the authenticated server implementation; never promote the preview state into an authoritative local ledger.

8. **Write a blurb.** Produce the concise public-facing description of the app and the benefits worth emphasizing.

9. **Shader research.** Collect visual references and investigate the asset pipeline and rendering approach needed for a more expressive holographic/sci-fi interface. Evaluate Flutter-native custom shaders, fragment shaders, layered assets, performance on the Pixel 9a, and accessibility scaling before committing to another visual implementation pass.

10. **Beta testing.** Run the app with the invited beta group and record functional bugs, confusing flows, output-quality failures, cost/latency problems, and real-world OCR limits. Include hostile OCR cases such as small print, dense and multi-column pages, uneven lighting, and angled documents; add further camera processing only when repeated beta evidence justifies it.

   **Price Check beta/public-release work:** deploy and harden the preserved backend, restore the launcher entry when ready, test real items on the Pixel 9a, and verify citations, safety gates, cost/latency, save/import, and prior-run comparison behavior. Refine the identification, exclusion/legal-check, Default/In-depth research, evidence-ranking, price-range, Buyer, Seller, previous-run summary, and market-change comparison prompts from observed beta output. Price Check remains hidden until this work is intentionally started.

11. **Second AI prompt refinement.** Use beta-test output to perform a second app-wide prompt-quality pass after every active major tool and live pipeline can be evaluated together. Revisit summaries, ToS analysis, Simplify Text, High-Fidelity OCR, Watchlist, and any other active AI-backed mode whose real-world output shows recurring quality or faithfulness problems. Price Check's tool-specific refinement is handled within its Step 10 beta work.
   - For `Simplify Text`, Claude may replace a difficult word with a short phrase when no clean one-to-one synonym preserves the meaning.
   - Claude may make the smallest local grammatical or sentence-structure adjustment necessary to integrate that phrase naturally and preserve the source's ideas.
   - Claude must not rewrite the sentence as a whole. Preserve its original meaning, order of ideas, emphasis, and structure as closely as practical.
   - When neither a direct synonym nor an easy phrase replacement exists, Claude may use limited judgment to produce the clearest faithful substitution rather than forcing an awkward or inaccurate one-to-one replacement.

## 10. Next task for Codex

**Build the tutorial as its own public-distribution increment.** Add the first-launch/setup tutorial without changing the completed public-information screens. After the tutorial, define and implement the shared backend/account/metering boundary and resolve the Android storage-permission release blocker. Keep Price Check dormant until its Step 10 beta work is intentionally resumed.
