# 21 November 2026 — Wartime Mosta reconstruction

The [source range](https://github.com/zelenski3398/codexproj1/compare/b964ed125e57b93d944ea2bf54b6e5dc422d162c...8e015db4eda91133243dbae1325ede29c4e6559b) contains the preceding St Elmo raid documentation and the [Mosta implementation](https://github.com/zelenski3398/codexproj1/commit/8e015db4eda91133243dbae1325ede29c4e6559b). Mosta builds in the normal continuous Malta scene and preserves the island’s terrain geometry.

The Rotunda anchors the reference trace. Its south-southeast portico, dome, belfries and steps sit above the historic square. Street linework, house clusters, gardens, fields and farmyards come from the user’s map and aerial references, with three additional control points for approximate registration. The two local road joins preserve the connections to Ta’ Qali and Birkirkara. The site masks remove overlapping rural scenery and update recovery-road pickup candidates.

## Verification

Godot 4.6.3 passed **14/14** Mosta assertions. The test checks the WGS84 projection, ground fit, façade, dome, branches, open plots, roof collision, draw batching, compatible damage, overlap removal and terrain debug visibility. The built scene has **1,236 houses** and removes **711** intersecting rural-wall collision triangles. Building and wall visuals use **131** batches, with detail culled at 330 m. Site construction took about 123 ms in the isolated headless run. A fresh generation produced byte-identical layout and mask files, and the release Web export succeeded.

Nearby regressions passed for Malta terrain (**30/30**), island roads (**11/11**), vegetation (**11/11**) and St Elmo (**43/43**). Native Compatibility renderer captures include the registered overhead comparison, two obliques and the forecourt. A surveyed building plan, verified reference dates, and sustained performance on target hardware remain unverified.

[Geographic evidence, approximations and captures](../mosta-reconstruction.md)
