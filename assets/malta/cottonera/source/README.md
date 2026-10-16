# Cottonera sources and access status

The requested Commons map, Kottonera history page, OSM API and Overpass endpoints
were blocked by the execution environment HTTPS proxy (403 on 2026-10-16).
They were not read, downloaded or used to trace fortification geometry.
`access_report.json` records the attempted URLs and missing inputs.

`places.json` is a four-record GeoNames cities500 subset from the public
`geonamescache` 3.0.2 distribution, downloaded through the available Python
package index. The complete package hash is recorded. No package is installed
or required by the game. These are coarse gazetteer points, not city boundaries,
historic centres, landmark positions or 1942 footprints.

Attribution: GeoNames, https://www.geonames.org/, Creative Commons Attribution
(CC BY; https://www.geonames.org/about.html). Package code is MIT, with its
original notice in `geonamescache-LICENSE.txt`. No package code is redistributed.
The existing coastline is © OpenStreetMap contributors, ODbL; elevation is the
Planning Authority DTM 2012, CC BY 4.0. See `../../source/README.md`.

Actual urban/fortification geometry must come from a supplied OSM/XML,
Overpass JSON or WGS84 GeoJSON file, with source/licence metadata. Modern data
are a baseline and do not establish wartime building or waterfront layouts.
