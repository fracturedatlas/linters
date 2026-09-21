# Plan: linters repo tooling backlog

Status as of 2026-09-21. Deviation checker (`bin/find_deviations.rb`) is built and running: it compares `.rubocop.yml` / `.reek.yml` against the installed gems' defaults, normalizes representation noise (regex strings vs Regexp objects, `(?-mix:)` wrappers, `=>`-hash strings, absolute-path Include/Exclude defaults), and exits 1 when a deviation lacks an `# Updated ...` marker comment.

## Done

- Gemfile (rubocop, reek, lefthook — unpinned, matching unifractured's style) + `.ruby-version` (`ruby-4.0.6`) + lockfile.
- First run triaged: 73 already-marked rubocop deviations, 46 unmarked.
- Backfilled `# Updated ...` markers on 24 cops (11 rubocop, 13 reek) — the straight intentional deviations.
- `TooManyStatements.max_statements` raised 5 → 6 (separate commit, already pushed).

## Punted — encoded as the PUNTED list in bin/find_deviations.rb

Reviewed and deliberately left unmarked; the checker skips them. Revisit when the config is next regenerated from current defaults:

- **AllCops section (5)** — RubyInterpreters, NewCops: enable, ParserEngine: parser_prism, SuggestExtensions: false, ActiveSupportExtensionsEnabled: true. Marker convention doesn't fit the section; it keeps prose comments.
- **Pending-cop toggles (4)** — Gemspec/AddRuntimeDependency, Gemspec/DeprecatedAttributeAssignment, Gemspec/DevelopmentDependencies, Gemspec/RequireMFA, Lint/CopDirectiveSyntax. Explicit Enabled values from when these cops were pending; defaults have since moved.
- **Version drift (4)** — Style/ItBlockParameter (EnforcedStyle + SupportedStyles order; cop is newer than the config), Style/IfWithBooleanLiteralBranches + Style/RedundantCondition (infinite? removed from AllowedMethods), Style/RedundantArgument (to_i removed from Methods).

## Remaining work

1. **Wire the lefthook pre-commit hook** — run `bundle exec ruby bin/find_deviations.rb`, fail the commit on unmarked deviations. Now safe: only punted items remain, and they're allowlisted.
2. **Version-drift policy** — the config header says "Taken from rubocop 1.75.7" but apps resolve newer rubocop (fs: 1.91.0). Decide whether to regenerate the config from current defaults periodically; on regeneration, clear the PUNTED list and re-triage.
3. **Commit all of this** — Gemfile, lockfile, .ruby-version, bin/find_deviations.rb, marker backfills, lefthook.yml, AGENTS.md is already pushed.