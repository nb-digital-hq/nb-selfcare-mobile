# AGENTS.md: operating contract for automated contributors

This file is the working contract of the repository for any coding agent (Claude, Gemini, Codex, Cursor, Copilot
or others) and for humans who want the same rules in one place. It applies **without anyone having to repeat it**.
Tool-specific configuration is never versioned in this repository and must never duplicate or contradict this
file.

The project documentation is written in Spanish; this file, the root community files and the issue templates are
in English. Code identifiers and comments are in Spanish.

---

## 1. The rule that governs all others

**`docs/` is the single source of truth.** If the code and `docs/` disagree, there is a defect: either the code is
fixed or the document is changed through the decision process. A contradiction is never left alive.

A change with architectural or user-facing impact **is not finished** until the affected document reflects it,
with its status label up to date, in the same pull request (Constitution, rule 9).

## 2. Before writing code, in this order

| Step | Document | What to look for |
|---|---|---|
| 1 | [Constitution](docs/architecture/constitution.md) | The absolute rules |
| 2 | [ADR index](docs/adr/README.md) | Why things are the way they are |
| 3 | [Architecture](docs/architecture/README.md) | Contracts of the module you are about to touch |
| 4 | [UI conventions](docs/design/ui-conventions.md) | Mandatory when the change touches the interface |

If the work depends on a decision that has not been taken, **do not start**: raise the decision first.

## 3. Repository architecture

```text
docs/                 Single source of truth (Spanish). Start at docs/README.md
  adr/ architecture/ audit/ design/ developer/ institution/ legal/ user/ assets/
lib/
  app/                Root shell, router, bottom bar, fasting bar, profile button
  core/clock/         The only source of the current time
  core/database/      Drift schema, DAOs, migrations and the offline food seed
  core/domain/        Enums and pure policies shared by several features
  core/hardware/      Bluetooth scale driver (Xiaomi Mi Scale 2)
  core/l10n/          ARB catalogues (es, en, pt), language preference
  core/network/       **The only network exit.** Public services and the paired local desktop (ADR-025)
  core/platform/      Native bridges: Health Connect, notifications, permissions, speech
  core/services/      Engines without UI: readiness, caffeine, analytics, PDF report, text parser
  features/           today, nutrition_hydration, body_metrics, fasting, care, quit,
                      journal, pet_gamification, profile_goals, protocol
    */application/    Use cases and queries: the only door from presentation to data
    */domain/         Pure rules of the feature
    */presentation/   Screens and widgets
  shared/             Theme tokens, design-system widgets and formatters
android/app/src/main/kotlin/   Health Connect, alarms, notifications, updater, launcher icons
ios/Runner/           iOS project (untested on a real device)
test/                 Unit, widget, migration, edge-case and architecture tests
tool/guardianes/      Guardians run by `just verify` and CI
tool/screenshots/     Golden captures of every screen in every language
```

## 4. Commands

| Command | Purpose |
|---|---|
| `just setup` | `flutter pub get`, Drift code generation and `flutter gen-l10n` |
| `just run` | Run on a device |
| `just test` | `flutter test` |
| `just guardianes` | All guardians |
| `just capturas` | Regenerate the screen captures (`tool/screenshots`) |
| `just verify` | The full definition of done (section 7) |
| `just apk` | Release APKs (per ABI and universal) |

## 5. Non-negotiable rules

| Rule | Where it lives | Mechanism |
|---|---|---|
| Nothing leaves the device unless the person asks for it | `lib/core/network/salidas.dart` | Automatic: `tool/guardianes/red.dart` rejects any HTTP client, socket or remote image outside `lib/core/network/`, and any connection in Kotlin; each client is bound to the hosts of its purpose |
| The app writes no logs | — | Automatic: `tool/guardianes/registro.dart` rejects `print`, `debugPrint`, `log` and `android.util.Log` |
| Every visible text is translated | `lib/core/l10n/arb/` | Automatic: `tool/guardianes/i18n.dart` (same keys in es, en and pt, same placeholders, no unused keys) |
| Everything shipped is open and Apache-compatible | `pubspec.lock` | Automatic: `tool/guardianes/licencias.dart`; `THIRD-PARTY-NOTICES.md` must be current |
| No private keys, keystores or agent configuration in the repo | `.gitignore` | Automatic: `tool/guardianes/secretos.dart` |
| One version and one date everywhere | `pubspec.yaml`, `lib/core/constants/app_constants.dart`, `CHANGELOG.md`, `CITATION.cff` | Automatic: `tool/guardianes/version.dart` |
| Docs have a title, a status label, working links, no emoji, no local paths, no pending work | `docs/` | Automatic: `tool/guardianes/docs.dart` |
| The current time comes only from `Clock` | `lib/core/clock/` | Test: `test/qa_audit/architecture_guardrails_test.dart` |
| Presentation reads and writes through `features/*/application/`, never through DAOs | `lib/features/` | Test: architecture guardrails |
| `core/` and `shared/` never depend on `features/` | `lib/` | Test: architecture guardrails |
| Dates are stored as ISO-8601 text; age is never stored | `build.yaml`, `lib/core/database/tables.dart` | Review and database tests |
| A published migration is never edited | `lib/core/database/app_database.dart`, `drift_schemas/` | `test/drift/` upgrades from every published schema |
| Backups use `VACUUM INTO` and are validated before restoring | `lib/core/services/backup_service.dart` | `test/database/backup_restore_test.dart` |
| Every view works in colour themes and in paper themes (no elevation, 1.5 px borders, no animation) | `lib/shared/theme/` | `test/design_system/` and the captures |
| Nibi never dies, gets sick or blames the person | `lib/features/pet_gamification/` | Test: architecture guardrails |
| `android:allowBackup="false"` stays | `android/app/src/main/AndroidManifest.xml` | Test: architecture guardrails |
| No new dependency without justifying cost, licence and maintenance | [dependency policy](docs/architecture/dependency-policy.md) | Licence automatic; the rest in the pull request |

## 6. Privacy

* **No telemetry, analytics, crash reporting or usage tracking**, including "anonymous" or opt-out variants.
* **Public destinations:** Open Food Facts on explicit lookup and GitHub releases on explicit update checks.
  ADR-025 also permits the explicitly paired local SelfCare desktop, with consent and a pinned certificate.
* **Pairing credentials** belong in the OS secure store, never SQLite, backups, logs or preferences. There is
  no account.
* **No real personal data in the repository**, not even for tests or screenshots. Captures use the fictional demo
  profile.

## 7. Verification

Run before declaring anything finished, without being asked:

```bash
just verify
# equivalent to:
flutter pub get
dart run build_runner build
flutter gen-l10n
dart format --output=none --set-exit-if-changed $(git ls-files 'lib/*.dart' 'test/*.dart' 'tool/*.dart')
flutter analyze
flutter test
dart run tool/guardianes/todos.dart
```

A change that touches packaging or native code is also checked with `flutter build apk --release`.

Definition of done:

1. The acceptance criterion is met and another person can check it.
2. Tests for the added logic and one regression test per fixed defect, named after the property they verify.
3. Verification is green.
4. If it has architectural or user-facing impact, `docs/` is updated in the same change.
5. If it adds visible text, its English and Portuguese translations are in the catalogues.
6. If it changes something visible, `CHANGELOG.md` says so.

## 8. Language and style

* Spanish for identifiers, comments, `docs/` and commit messages; English for root community files and templates.
  Professional register, **no emoji** anywhere.
* Comments explain **why**, not what, and never narrate the history of the code.
* Text in the app is warm and never guilt-inducing: invitations, not reproaches.

## 9. Commits

```bash
git commit -s -m "feat(care): avisar cuando quede reserva para una semana"
```

Conventional Commits, `-s` mandatory (DCO), body explaining why and what was verified.

## 10. What requires asking

* Approving or changing an ADR, adding a dependency or changing a licence.
* Publishing, pushing to a remote, or any outward-facing action.
* Anything that sends data off the device or contradicts this file or the Constitution.

## 11. One agent on the working tree

Two agentic tools must never write to this repository at the same time. If modifications appear that you do not
recognise, compare with `HEAD` (`git status`, `git show HEAD:<path>`) and restore from it; never trust the copy on
disk.
