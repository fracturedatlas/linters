# AGENTS.md

## Purpose

This repo holds the shared linter configurations for Fractured Atlas projects: `.rubocop.yml` (RuboCop) and `.reek.yml` (Reek), plus `example_rubocop.yml`, the canonical starting point for an app's own `.rubocop.yml`.

Apps inherit the RuboCop config by URL via `inherit_from` in the app's `.rubocop.yml` (see README.md). The Reek config is fetched by the unifractured gem's quality rake task and cached in each app as `.reek-cache.yml`. Changes here therefore propagate to every app once merged to `main` — apps pick up the RuboCop config immediately and the Reek config after their cache refreshes (`rake unifractured:quality:clear_cache` or `rake unifractured:sync`).

## Commenting config changes

When a cop or detector setting deviates from its default, add a terse one-line comment directly above the cop name, naming only the changed parameter:

```yaml
# Updated max_statements to 6
TooManyStatements:
  enabled: true
  max_statements: 6
```

Do not write long rationale comments — the convention is a minimal marker. See `.rubocop.yml` for examples: `# Updated Enabled to false`, `# Updated EnforcedStyle to end`, `# Customized completely`.