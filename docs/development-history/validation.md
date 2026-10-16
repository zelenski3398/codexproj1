# Documentation audit validation

[Contents](README.md) · [Portable validator](validate.py)

Audit snapshot: `588ac7b1b37b72014b73fe679871e790e5c79145`. Executed 16 October 2026. Validation concerns this new documentation and selected source-data safeguards; historical gameplay pass reports remain attributed to their original documentation/commits.

## History and source checks

- Verified repository remote, clean starting state, local work and fetched origin/main, non-shallow status, one root, 50 reachable commits, zero merges and no tags. Safe fetch updated only remote-tracking history; no reset/rebase/rewrite occurred.
- Inspected full available log, per-commit statistics/name-status, implementation diff hunks and current source callers/resources. Commit evidence retains all 50 SHAs, actual author/committer timestamp strings, parents and changed path/status lists. Manifest validation compares those lists with Git.
- The 23 milestone groups account for every commit once. Ambiguous CNAME, parser, test synchronization and deployment-report commits are explicitly indexed. No merged implementation is double-counted.
- Verified all named source files and a focused method/line evidence index. Current tracked snapshot counts, scene inventory, runtime/test script split, resource inventory and generated terrain/city manifests were inspected. Runtime GLB JSON contains 166 meshes; pending Cottonera has no placed chunks.
- Activity uses actual UTC-normalized author dates. Historical size samples use tracked blob bytes, not imports/exports or productivity estimates.

## Fresh executable checks

| Check | Result |
| --- | --- |
| `python docs/development-history/validate.py` | Checks all local Markdown links/heading anchors, source line bounds, exact commit coverage/parents/file lists, snapshot counts, activity dates, diagram-source/block equality and common credential patterns; final counts below |
| Mermaid 11.12.0 in real headless Chromium via Playwright | **17/17 unique sources parsed and rendered to nonempty SVG**; architecture block is also repeated in master |
| `tests/cottonera_import_checks.py` with the existing geographic Python environment | **14/14 passed** |
| `tests/cottonera_pipeline_checks.py` in the same environment | **10/10 passed**; synthetic outputs remain in temporary directories |
| Projected Mdina and all three airfield X/Z | Recalculated with EPSG:32633 and the recorded origin; matches existing layout/world data within floating-point tolerance |
| Final repository scope | Only the requested master and development-history documentation tree are new; tracked gameplay/scripts/scenes/assets unchanged |

The data-tool tests confirm missing-data/source-rejection and synthetic compiler behaviour. They do not verify a populated Cottonera environment, gameplay balance or a complete city traversal. Their 24 assertions are the only freshly executed game-related regression assertions in this audit.

## GitHub visibility

Public HTML PR search: zero merged results. All-state and closed-state issue searches: zero results. Releases: none listed. Branches page accessible; Git transport advertised only main and no tags. REST endpoints for branches, PRs, issues and releases were blocked by proxy 403. Discussions URL returned 404. No inaccessible/private/deleted records or current deployment/run logs are claimed as inspected.

## Checks not performed

No fresh interactive flight, takeoff/landing, dogfight, mission timing, AA tracking, listening test or complete native/web game acceptance was run for this documentation-only change. No new web release was exported/deployed. Existing reports of such checks are labelled historical and linked; the 89.44–89.45 s bomber measurements are not fresh measurements. Historical Windows white terrain, exact road/geography fidelity, populated Cottonera and consumer-hardware performance remain unverified.

## Secret and change-scope review

No credential files/environment values were read into the document. Commit subjects, hashes, path/status metadata and timestamps were included; author email addresses and transient custom hostname contents were omitted. Common token/private-key pattern scanning found no matches, and generated content was reviewed for sensitive configuration. Pattern scanning is a limited safeguard, not a guarantee about every historical repository blob.

Only documentation was created. Git fetch was read-only with respect to the work tree and did not rewrite branch history. Gameplay and generated world assets were not regenerated. The historical audit remains pinned to the source snapshot above. Subsequent documentation publication commits are outside its 50-commit analysis range.

## Final validation counts

- **18 Markdown documents** checked, including the master and supporting indexes/report.
- **854 relative links and source references** resolved; heading anchors and source line bounds passed.
- **50/50 commits** represented with matching Git parent and changed-path inventories; no duplicates or omissions.
- **17 unique Mermaid sources / 18 embedded blocks** match exactly; all unique sources additionally parsed and rendered in Chromium.
- Git-derived counts/activity and common secret-pattern checks passed with **zero validator errors**.
- **40 new documentation/support files**: the requested master, index and 14 chapters; diagram index and validation report; 17 Mermaid sources, one SVG chart, two JSON evidence/statistics files, one CSV and one portable validator.

Reproduce link/coverage/count checks with `python docs/development-history/validate.py`. Mermaid rendering used Mermaid 11.12.0 in a temporary external Node environment and real headless Chromium; no runtime/dependency files were added to the game.
