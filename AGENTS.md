# AGENTS.md

## Purpose

This repo holds the shared linter configurations for Fractured Atlas projects: `.rubocop.yml` (RuboCop), `.reek.yml` (Reek), and `.herb.yml` (Herb, for HTML+ERB templates), plus `example_rubocop.yml`, the canonical starting point for an app's own `.rubocop.yml`.

Apps inherit the RuboCop config by URL via `inherit_from` in the app's `.rubocop.yml` (see README.md). The Reek config is fetched by the unifractured gem's quality rake task and cached in each app as `.reek-cache.yml`. Changes here therefore propagate to every app once merged to `main` — apps pick up the RuboCop config immediately and the cached configs after their cache refreshes (`rake unifractured:quality:clear_cache` or `rake unifractured:sync`). The Herb config is not yet wired into unifractured.

## Commenting config changes

When a cop or detector setting deviates from its default, add a terse one-line comment directly above the cop name, naming only the changed parameter:

```yaml
# Updated max_statements to 6
TooManyStatements:
  enabled: true
  max_statements: 6
```

Do not write long rationale comments — the convention is a minimal marker. See `.rubocop.yml` for examples: `# Updated Enabled to false`, `# Updated EnforcedStyle to end`, `# Customized completely`.

Comments always go on their own line above the key — never trailing on the same line as a setting. `bin/find_deviations.rb` (run by the lefthook pre-commit hook) enforces both conventions: every deviation from defaults must carry a marker comment, and no config file may contain trailing comments. Herb rule defaults live in `bin/herb-defaults.json`, a snapshot of the `@herb-tools/linter` version pinned in `.herb.yml` — regenerate it whenever the pin is bumped (see the JSON's `regenerate` key).