# Original landmark proposal: Chicago Cultural Center

Research date: September 9, 2026. The proposal below is preserved as its original research record. It was subsequently implemented for Atelier 2.3.0; see [Chicago Cultural Center architecture, routes and validation status](CULTURAL-CENTER.md). The recommendation-only research itself made no building, route, renderer or map changes. Statements below about a future project describe that earlier point in development.

The **Chicago Cultural Center** would be a strong next addition. Its historic library exterior, marble and mosaic interiors, and Preston Bradley Hall’s Tiffany glass dome would create an intimate architectural walkthrough beside the existing Millennium Park scene. The City lists the building at **78 East Washington Street**, completed in **1897** by **Shepley, Rutan & Coolidge**, and designated a Chicago Landmark in 1976. [City landmark record](https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1274).

## Fit with the existing world

At the time of the proposal, read-only inspection found the Cultural Center in the bundled Chicago map, but no dedicated Cultural Center geometry, interior model or destination in the Swift sources. It then passed through the general mapped-building renderer. Tribune Tower, by comparison, already had a dedicated Gothic crown, facade and entrance model in `MagnificentGateway.swift`.

| Existing data | Value |
| --- | --- |
| Map resource | `Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json` |
| Snapshot timestamp | `2026-09-07T22:11:33Z` |
| Building name | `Chicago Cultural Center` |
| Derived building ID / OSM relation | `-158994370` / [15899437](https://www.openstreetmap.org/relation/15899437) |
| Footprint bounds in world metres | x `882.20…930.10`, z `−613.27…−500.77` |
| Approximate footprint bounding-box centre | `(906.15, 0, −557.02)` |
| Approximate geographic centre | `41.883880° N, 87.624985° W` |
| Current context height | `18.75 m`, derived from levels; not a verified architectural height |

The centre coordinate is calculated from the bundled outer-footprint bounds and the existing Willis-origin projection; it is not an entrance coordinate or a survey measurement. It lies approximately **190 m northwest of the modeled Cloud Gate centre** in a straight line. That calculation establishes proximity, not a validated pedestrian route. A connecting approach across the existing Millennium Park/Michigan Avenue setting could stay within the current city geography, concentrating new detail on the building and its immediate block.

The inspected resource SHA-256 is `2b7b9ef2dd40798bc58994e43dc7fb71fac2cdda56e9cf8b34ee8f4bfd58a904`. A future detailed model should replace the generic building and verify its height, floor levels and openings against architectural evidence.

## What would make the walkthrough distinctive

A future project could follow the exterior and Washington Street entrance into the mosaic stair, then reveal Preston Bradley Hall and the Tiffany dome overhead. The Chicago Architecture Center describes the limestone exterior, elaborate marble and mosaic spaces, and a 38-foot Tiffany dome containing approximately 30,000 glass pieces. Those features provide useful close-view subjects beyond the existing skyline studies. [Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-cultural-center).

The restoration team’s own account is a strong starting reference for the dome: Wight oversaw work on more than 30,000 glass pieces and identifies Jacob A. Holzer as its original designer. The page includes project imagery to inspect during the future modeling pass. [Wight & Company’s Preston Bradley Hall restoration](https://www.wightco.com/work/preston-bradley-dome/).

The second dome requires separate research. Berglund’s restoration account identifies the **Grand Army of the Republic dome as Healy & Millet**, with Tiffany decorative finishes in the rooms. Its project photographs and restoration descriptions would help distinguish those spaces from Preston Bradley Hall and avoid reproducing an older, unrestored appearance. [Berglund’s Grand Army of the Republic restoration](https://www.berglundco.com/projects/chicago-cultural-center-grand-army-of-the-republic-rooms).

Warm evening interiors, glass transmission, polished stone and restrained exterior lighting would suit the renderer’s strengths. These are proposed visual subjects, not a promise of new optical effects, a measured performance result or a completed eight-view plan. The primary-source text and existing map were inspected for this recommendation; the linked photographs have not yet undergone a dedicated visual-reference review, and no photographs were downloaded or bundled.
