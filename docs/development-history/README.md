# WWII Malta: development history and architecture

**Evidence snapshot:** `588ac7b1b37b72014b73fe679871e790e5c79145` ([588ac7b](https://github.com/zelenski3398/codexproj1/commit/588ac7b1b37b72014b73fe679871e790e5c79145)). Audit date: 16 October 2026. This documentation describes that snapshot, not subsequent changes.

This record follows all **50 reachable commits** from `64406b082d49576bf5c0ec8c95367530dab9ab2c` (7 October 2026, 16:24:09 UTC) to the snapshot (16 October 2026, 06:59:46 UTC). Git is the historical evidence; the snapshot source establishes current behaviour. The first commit already contains a playable prototype; no earlier design or coding history is available here.

## Later documented changes

See the [incremental updates](../development-updates/README.md) and [supplied reference diagrams](../development-updates/reference-diagrams.md). These supplements do not change the original 50-commit audit boundary. The root README records the newest inspected commit for subsequent updates.

## Read the document

- [Consolidated master document](../WWII-Malta-Development-Complete.md): essential history and architecture, with links to deeper chapters.
- [01. Project overview](01-project-overview.md)
- [02. Development timeline](02-development-timeline.md)
- [03. Architecture](03-architecture.md)
- [04. Aircraft and flight](04-aircraft-and-flight.md)
- [05. Combat and damage](05-combat-and-damage.md)
- [06. Ground vehicles and soldiers](06-ground-vehicles-and-soldiers.md)
- [07. Anti-aircraft systems](07-anti-aircraft-systems.md)
- [08. Malta terrain and geography](08-malta-terrain-and-geography.md)
- [09. Missions and AI](09-missions-and-ai.md)
- [10. Audio and atmosphere](10-audio-and-atmosphere.md)
- [11. Performance and web export](11-performance-and-web-export.md)
- [12. Technical decisions](12-technical-decisions.md)
- [13. Current state and roadmap](13-current-state-and-roadmap.md)
- [14. Commit reference](14-commit-reference.md)
- [Diagram sources](diagrams/README.md).
- [Portable documentation validator](validate.py): `python docs/development-history/validate.py`.
- [Machine-readable commit evidence](commit-evidence.json), [statistics](statistics.json), [daily activity CSV](activity.csv), and [validation report](validation.md).

## Evidence and status conventions

**Historical change** means a change observed in a reachable commit diff. **Current implementation** means a corresponding source path/method is present at the snapshot. **Historical test report** means a result recorded in an older README/document; it is not a fresh test result. **Test coverage present** means an executable test exists, not that it was run for this audit. **Pending** means data or integration is missing. Recommendations are not project commitments.

A source citation points to the current checked-out file; a commit link pins the historical version. For changed/removed files, inspect the linked commit rather than treating the current file as a historical copy. Code links remain relative for maintainability. Refresh this audit after meaningful implementation changes.

## History coverage and access limits

Inspected local `work` and remote-tracking `origin/main`, both at the snapshot after a safe fetch. `origin/main` initially pointed to the root commit; fetching the advertised `main` branch recovered the complete accessible history. `git rev-parse --is-shallow-repository` returned `false`. `git ls-remote --heads --tags origin` advertised **only main**, no tags. All 50 commits form one reachable history, with one root and **zero merge commits**. No resets, rebases or history rewriting were performed.

The verified remote is https://github.com/zelenski3398/codexproj1.git. Public GitHub HTML showed zero merged pull-request results, zero issue results for all-state and closed-state searches, and no releases. The branches page was accessible and the Git transport advertised main. GitHub REST requests for branches, PRs, issues and releases were blocked by the environment proxy (403); `/discussions` returned 404. These observations do not establish the contents of deleted branches, private/unreachable records, inaccessible workflow logs, or pre-root development. No PR/issue rationale has been invented.

Dates are actual Git **author timestamps**, normalized to UTC for the timeline, activity chart and commit headings. The commit manifest also preserves original author and committer timestamp strings. Two CNAME edits used a +02:00 author offset. Reachability order and original timestamps are retained; commit counts are not measures of quality or productivity. Author email addresses and credentials are intentionally not copied.

## Maintaining this audit

1. Record a new immutable source SHA and refresh advertised refs safely.
2. Inspect new diffs and current callers, including removal/replacement of old features.
3. Update affected chapters, commit evidence, counts, diagrams and current-state classifications.
4. Parse every Mermaid source, validate relative Markdown links/source anchors and ensure documentation-only changes.
5. Keep fresh execution results distinct from inherited test reports. Do not rerun generators against production terrain just to refresh documentation.
