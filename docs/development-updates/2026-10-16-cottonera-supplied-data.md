# 16 October 2026 — Cottonera populated from supplied geographic data

[Update index](README.md) · [Guide and actual native previews](../cottonera-region.md)

Source commit: [73344f1](https://github.com/zelenski3398/codexproj1/commit/73344f14724c745f3fd822fad36f02bfe0926896).
Inspected exclusive range: `fbfab9dd1bf49bfdd61d893021a2e568f887c45d..73344f14724c745f3fd822fad36f02bfe0926896`.
`b137fd8` in that range published the previous audio documentation only.

Previously Cottonera had source-anchored labels and unplaced architectural
templates, with no populated city geometry because geographic data was missing.
The user supplied a 7,551-feature Overpass Turbo GeoJSON extract with OSM/ODbL
metadata. The new preprocessing tool selects a documented editorial Cottonera
extent, excluding Valletta, then uses the existing importer/compiler. No terrain,
coastline, road path, airfield position, physics or mission script changed.

The resulting continuous world contains **2,575 source-footprint buildings**,
**38 fortification features**, Fort St Angelo, source churches and Gardjola,
with **145 persistent collision chunks** and near/mid/far mesh representations.
Polygon coordinates and holes remain identical to the supplied source. The four
named render groups use nearest gazetteer anchors for batching only; these are
explicitly not municipal or historical boundaries. Known modern-dated features
are excluded; undated modern footprints may remain. The manifest deliberately
remains `partial_geodata`: identified historical line systems, dockyard geometry,
Inquisitor's Palace and some gate/landmark details still require review.

The normalized dataset records input/source hashes, scope, licence and warnings.
Runtime web exports omit the large processing sources but include compiled
scenery and attribution. Original world file hashes remain unchanged. Existing
region/world lifecycle handles clean mission retry with one fresh city instance.

Validation: real source dataset **15 assertions**, importer **14/14**, compiler
**10/10**, native populated-region **15/15**, existing Malta gameplay **36/36**,
and production Chromium/ANGLE world/render/retry checks **28/28** passed.
The populated-region test raycasts against an actual mapped roof. Native
Compatibility rendered three genuine world previews. Web export/import reported
no script/resource errors; browser checks reported no shader, resource,
JavaScript or HTTP errors. The original documentation validator still passes its
frozen 50-commit audit and 859 links. This update does not rewrite that audit.

Manual street-by-street walking/driving, verified historical facades, sustained
browser city flyover/frame-rate measurements and complete dockyard/wall-line
reconstruction remain unverified or incomplete. No such results are claimed.
