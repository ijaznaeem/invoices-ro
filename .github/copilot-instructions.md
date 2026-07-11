name: Ledger Flutter App Instructions

## 1. Project context

**Ledger** is a Flutter app for creating recurring invoices that
auto-generate on their due date. It is offline-first: all data lives in an
on-device SQLite database (`sqflite`), there is no backend.

- **Stack:** Flutter 3.19+ / Dart 3.3+, `sqflite`, `google_fonts`, `intl`.
- **State management:** a single hand-rolled `ChangeNotifier`
  (`lib/state/app_state.dart`) exposed via `InheritedNotifier`
  (`lib/state/app_state_scope.dart`). Do not introduce Provider, Riverpod,
  Bloc, or GetX without an explicit architectural decision (see §9) — the
  app is intentionally small enough not to need one yet.
- **Domain:** clients, recurring invoice templates, generated invoices,
  and an activity/notification feed. The generation engine
  (`lib/db/generation_engine.dart`) is the core business logic: it advances
  due dates, catches up on missed cycles, and respects end conditions.

When suggesting code, prioritize correctness of date/money arithmetic and
consistency with the existing layered structure over cleverness or brevity.

---

## 2. Architecture — respect the layers

```
models/    → plain data classes (Client, RecurringTemplate, InvoiceRecord, ...).
             No Flutter imports here. No business logic beyond simple derived
             getters (e.g. InvoiceRecord.displayStatus).
util/      → pure functions (date math, currency formatting). No side effects,
             no I/O, fully unit-testable without a widget tree or a database.
db/        → all SQLite access goes through DatabaseHelper. The generation
             engine (GenerationEngine) is the only thing allowed to run the
             recurring-invoice business rules. Never write raw SQL outside
             database_helper.dart.
state/     → AppState is the single source of truth the UI reads from. Screens
             never call DatabaseHelper or GenerationEngine directly — always
             go through AppState so every screen sees consistent data.
theme/     → design tokens (color, type) only. No layout logic.
widgets/   → small, reusable, presentational. Must not reach into AppState
             themselves — take data and callbacks via constructor parameters.
screens/   → composition root for a tab/page. May read AppStateScope.of(context)
             and call AppState methods. Keep business logic out of screens.
```

**Rule of thumb:** if you're about to write a SQL string, a date-advance
calculation, or a total/tax calculation inside a widget file, stop — that
logic belongs in `db/` or `util/`, with a matching unit test.

---

## 3. Dart/Flutter coding standards

- Follow the [Effective Dart](https://dart.dev/effective-dart) style guide.
  Run `dart format .` before every commit — do not hand-format.
- Enable and respect `flutter_lints` (already a dev dependency). Treat new
  lint warnings as build failures, not suggestions to ignore.
- **Null safety is not optional.** Never use `!` to silence the analyzer
  unless you can state in a comment *why* the value is guaranteed non-null
  (e.g. "id is always set — this object came from a DB row").
- Prefer `final` over `var`; prefer immutable model classes with `copyWith`
  over mutable state.
- All public classes, and any non-trivial method (generation logic, date
  math, aggregate DB queries), get a `///` doc comment explaining intent,
  not just restating the signature.
- No `print()` in committed code — use a proper logger
  (`package:logging` or `debugPrint` gated behind `kDebugMode`) if you need
  runtime diagnostics.
- Constructors: use `const` wherever the widget allows it. If you add a
  field to a widget that breaks constness, check whether that's actually
  necessary before accepting the performance regression.

---

## 4. State management conventions

- Every mutation goes through an `AppState` method (e.g. `addClient`,
  `markInvoicePaid`) — never call `DatabaseHelper` from a screen or widget.
- `AppState` methods that change data must leave the in-memory lists
  consistent with the database before calling `notifyListeners()` (it
  already does this via `reload*()` calls — keep that pattern).
- Don't add new global mutable state outside `AppState`. If a screen needs
  local-only state (form input, a `TextEditingController`, a selected tab
  index), it belongs in that screen's own `State` object.
- If the app grows past ~2,000 lines or picks up features that need
  fine-grained rebuild control (e.g. a very large invoice list with
  per-row async status), raise it as an explicit decision to move to
  Riverpod before writing it — don't silently bolt on a second state
  management approach.

---

## 5. Database & schema changes

- All schema lives in `DatabaseHelper._initDb()`. `sqflite` databases are
  versioned — any schema change **must**:
  1. Bump the `version` passed to `openDatabase`.
  2. Add an `onUpgrade` migration that transforms existing user data in
     place. Never assume a fresh install — real devices will have data
     from earlier schema versions.
  3. Be covered by a test that creates an old-version DB, runs the
     migration, and asserts the resulting schema/data.
- Money is stored and computed in `REAL`/`double`. Since this is a
  single-currency MVP with 2-decimal display, that's acceptable — but if
  multi-currency or precise accounting support is added, migrate to
  integer minor units (cents) rather than floating point.
- All dates are stored as `yyyy-MM-dd` ISO strings for lexical sort/compare
  to work correctly (`due_date < ?` comparisons rely on this). Keep using
  `util/date_utils.dart` helpers — never format dates ad hoc.

---

## 6. Error handling

- Any `DatabaseHelper` call that can fail (constraint violation, disk I/O)
  should be wrapped where it's invoked from `AppState`, and surface a
  user-facing message via `ScaffoldMessenger` — never let an exception
  reach the widget tree unhandled.
- Form validation happens client-side before hitting the database
  (`Form`/`TextFormField` validators) — don't rely on SQLite constraints
  as the only validation layer.
- Prefer explicit `Future<T>` with try/catch over silently returning
  `null`/empty lists on failure, unless "empty" is a genuinely valid state
  (e.g. no clients yet).

---

## 7. Testing requirements

Every PR that touches business logic must include tests. Minimum bar:

- **`util/date_utils.dart` and the generation engine** — pure unit tests,
  no widget/database needed for date math; use `sqflite_common_ffi` for
  in-memory DB tests of `GenerationEngine.run()`. Cover explicitly:
  - a template due today generates exactly one invoice
  - a template with a start date weeks in the past catches up on all
    missed cycles
  - month-end dates (e.g. Jan 31 monthly) clamp correctly instead of
    overflowing into the next month
  - `end_type: count` and `end_type: date` correctly transition a
    template to `ended` and stop generating
- **`AppState`** — test that mutating methods leave lists/stat aggregates
  consistent after `notifyListeners()`.
- **Widget tests** for each screen's empty state and at least one
  populated state.
- Run `flutter test` and `flutter analyze` locally before opening a PR;
  both must be clean.

---

## 8. Performance & UX

- Lists use `ListView.builder`/`GridView.count` with bounded item counts —
  never build unbounded lists eagerly with `.map().toList()` inside a
  non-lazy `Column`.
- Avoid rebuilding the whole screen on every `AppState` change if a
  narrower rebuild is easy — but don't prematurely optimize with
  `Selector`-style patterns until profiling shows a real problem.
- Respect the existing ledger design language (`theme/app_theme.dart`,
  `widgets/ledger_row.dart` etc.) — new UI should reuse `LedgerRow`,
  `StatCard`, `StatusPill`, `EmptyState` rather than inventing parallel
  components.
- Support both light and dark mode for any new screen — check both when
  reviewing a PR's screenshots.
- Respect `MediaQuery` text scaling and minimum tap target sizes (48x48)
  for accessibility; don't hardcode pixel layouts that break under larger
  system font sizes.

---

## 9. When to introduce a new dependency

Before adding a package, check:
1. Does `pubspec.yaml` already have something that covers this?
2. Is this solving a real, current need, or a hypothetical future one?
3. Is it actively maintained (recent pub.dev releases, not abandoned)?

Get explicit sign-off (PR discussion, not silent inclusion) before adding:
state management packages, analytics/telemetry, or anything that adds
network access to what is currently an offline-only app.

---

## 10. Git & PR conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/)
  — `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`. Keep commits
  scoped to one logical change.
- **Branches:** `feature/<short-description>`, `fix/<short-description>`.
- **PRs:** describe *what* changed and *why*; link the issue if one
  exists. Include before/after screenshots for UI changes (light + dark).
- No direct commits to `main` — all changes via PR, even small ones.
- CI (see §11) must pass before merge; don't merge with a red build.

---

## 11. CI expectations

Every PR should run, at minimum:
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
Treat any of these failing as a blocker, not a follow-up task.

---

## 12. Privacy & security

- This app stores real client data (names, emails, invoice amounts)
  on-device. Do not add any network call, analytics SDK, or crash
  reporter that transmits this data off-device without it being an
  explicit, reviewed feature — not a side effect of adding a package.
- If a backup/export feature is added, be explicit in the UI about what's
  being exported and where it's going.

---

## 13. Documentation

- Keep `README.md` current: setup steps, architecture diagram, and the
  "what changed / what's next" sections should reflect the actual state
  of the app, not the state at initial creation.
- Any new screen or non-obvious business rule (e.g. a new end-condition
  type, a new invoice status) gets a short note in the README's
  architecture section, not just inline code comments.