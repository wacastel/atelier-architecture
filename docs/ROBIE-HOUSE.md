# Frederick C. Robie House

Atelier's Hyde Park location adds Wright's house to the same Chicago world as McCormick Place. Seven close architectural studies cover the exterior, balcony and principal living spaces; the eighth route follows the lakefront connection from McCormick Place to the house. The surrounding neighborhood and corridor use the separate offline Hyde Park context resource.

The house is procedural, metre-scale triangle geometry. Brick courses, roof edges, window frames, glass came, furniture and planting cast their own ray-traced shadows. No reference photograph is used as a facade texture.

## Reference basis

The [Frank Lloyd Wright Trust's account](https://flwright.org/explore/frederick-c-robie-house) establishes the 1910 completion and the relationship between the offset wings, terraces, horizontal masonry and central living space. Its description of clear, colored and iridescent art glass informed the transmitting panels and flattened diamond motif.

The [Trust's Conservation Management Plan](https://flwright.org/sites/default/files/2023-06/RobieCMP_FLWT_web.pdf), especially printed pages 44–47, 51–53 and 98, was inspected as both text and rendered pages. It supplied the 86-foot-9-inch living/dining prow span, low roof sections, recessed horizontal mortar, buff limestone, central hearth opening and integrated lighting. Local working reference pages are excluded from the repository.

The [National Park Service nomination and HABS drawings](https://npgallery.nps.gov/GetAsset/620ea545-086b-48b8-b3cb-02011c292dcd) include the measured main-floor plan and elevations (PDF pages 13 and 15 were inspected). The [Library of Congress HABS IL-1005 catalog](https://www.loc.gov/item/il0039/) identifies the underlying survey. The plan guided the western living room, eastern dining room, northern stair/service spaces, three south-facing garage doors, and prow geometry. Historic alterations recorded by the survey are not treated as the restored present condition.

[Harboe Architects' restoration project](https://www.harboearch.com/projects/the-ruse-rnga7) and James Caulfield's restored living-room photographs were visually inspected. They informed the ochre plaster, dark oak trim, stepped ceiling, geometric laylights, globe fixtures, pierced hearth, radiators and modest furniture palette. Their documented restoration completed in 2018–2019 is the finish reference.

The evening exterior photograph on [University of Chicago Student Arts](https://www.studentarts.uchicago.edu/artspass-locations/robiehouse) was also visually inspected. Warm light visible through the glazing, shadowed roof planes and trailing green planters guide the night treatment. The image is a lighting reference, not a photometric measurement.

## Model and map alignment

`RobieHouseLayout` uses OSM building way **125667497** in the existing Willis-origin east/south projection. The local origin is `(3309.7, 0, 9917.1)` metres; the local east direction follows the approximately 1.15-degree skew of the mapped block. The source footprint has centroid `(3312.995, 9914.681)` and is retained in [the extracted footprint record](../scripts/data/chicago-robie-footprint-2026-09-08.json). The main living wing and north service wing are authored separately within that mapped site.

The principal floor is 3.20 metres above world grade. The living/dining prows are 26.4412 metres apart. The lower roofs, smaller belvedere, chimneys, west outdoor room, south balcony, garden wall, urns and planters form distinct geometry. Roman brick faces have shallow recessed joints; close piers and hearth include return edges, while long courtyard walls use economical displaced faces over solid masonry.

Art glass combines clear transmission, amber and olive pieces, oak frames and raised metal came. Night illumination uses warm interior practicals and modest exterior accents. Day/night controls affect the exterior lights; principal-room practical lighting remains available during daytime.

## Scope and navigation

This is a referenced architectural reconstruction, not an as-built survey or an official virtual tour. Roof slopes, elevations, individual brick placement, planting, fixture powers and some furniture dimensions are interpreted. The glass uses an original geometric reconstruction of the reference grammar rather than a traced conservation drawing. Furniture placement supports circulation and is not a claim about a particular museum display date.

The living room and dining room are furnished, roofed spaces with a continuous aisle around the hearth. The balcony and west outdoor room have physical decks. Ground-floor recreation furniture is visible through the windows. Service rooms and the third-floor bedrooms receive exterior detail and interior light but do not have complete room-by-room museum interiors. The roof and wall massing remains intact when going inside.

Select the house using the existing click-to-focus control to orbit and scroll toward it. Tour selection restores the authored camera. The short house routes preserve normal manual movement, day/night and idle controls.

## Validation

Run [validate-robie-house.sh](../scripts/validate-robie-house.sh) for the actual standalone house mesh, material indices, finite/unit normals, mapped bounds, window transmission, light budget and warm color ordering. CPU rays verify the covered west porch, both room floors, south balcony, physical glass, central hearth and the opening above its mantle. Bidirectional body sweeps exercise the garden pavement, balcony, living room, dining room and connecting hearth aisle. Full city route and GPU checks are documented in the release validation record.

The standalone result is **1,026 checks passed**, **438,350 rendered triangles**, **190 framed art-glass panels**, and **38 architectural light sources**. The navigation BVH retains 34,206 triangles; smaller visible ornament remains in the Metal scene. These figures are for the house and its authored grounds only, not the surrounding city. A final pair of small west-facing masonry/planter washes improves night readability; their fixture geometry leaves the navigation triangles byte-for-byte equivalent in defined coordinate data.
