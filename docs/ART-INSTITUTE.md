# Art Institute of Chicago

The Art Institute occupies its geographic position in Atelier’s shared Chicago world, immediately south of Millennium Park. The model combines a detailed Michigan Avenue front, a simplified museum campus, Renzo Piano’s Modern Wing, and Nichols Bridgeway. The continuous Chicago flight approaches the north entrance from the park, enters Griffin Court, and turns into an authored gallery.

## Geographic and architectural anchors

Coordinates use metres east/up/south of **41.878876° N, 87.635918° W**, with street grade at y=0. The September 8, 2026 OpenStreetMap snapshot in `scripts/data/millennium-osm-2026-09-08.json` supplies building outlines and the bridge alignment. The museum campus extends approximately x=983–1230 and z=−199–47. The historic building lies at x=983–1048, z=−127–−27; its Michigan Avenue entrance faces west. The Modern Wing occupies the northeast of the campus at x=1110–1211, z=−199–−88. See [OpenStreetMap’s copyright and attribution page](https://www.openstreetmap.org/copyright) for the map-data license.

The historic frontage follows the museum’s own photographs: seven upper arched bays flank a projected central pavilion, whose three upper loggia arches sit over the main entry portals. Modeled details include recessed windows and blind niches, ashlar joints, pilasters, medallions, arched voussoirs, keystones, layered cornices, dentils, a central pediment, broad steps, and the two bronze lions. The building opened in 1893; the museum’s historical account records later additions including Fullerton Hall, Ryerson Library, and the 1910 grand staircase. [Art Institute architectural history](https://archive.artic.edu/ryerson/armory/1).

The two lion meshes are original anatomical interpretations with standing bodies, articulated legs and paws, layered manes, muzzles, ears, and curved tails. The northern lion’s lowered head and offset foreleg distinguish it from the more upright southern lion. Their orientation and broad form follow actual photographs of Edward Kemeys’s sculptures; this is not a scan of the sculptures. The museum identifies the north lion as “on the prowl” and the south lion as standing “in an attitude of defiance.” [The Lions of Michigan Avenue](https://www.artic.edu/articles/720/the-lions-of-michigan-avenue).

The Modern Wing uses the documented **28 m** building height, two three-storey pavilions, limestone walls, fine metal framing, glass, and a projecting white light-filter roof. The central, north/south Griffin Court remains open through two storeys, with slender columns and a glazed roof. The main façade’s ground entrance has an unobstructed opening; the remaining glazing uses the renderer’s thin dielectric transmission and reflection. Published project dimensions and the material language come from the [Fondazione Renzo Piano project record](https://www.fondazionerenzopiano.org/en/project/the-art-institute-of-chicago-the-modern-wing/). The museum records the Modern Wing’s May 16, 2009 opening and 264,000-square-foot area. [Modern Wing overview](https://archive.artic.edu/modernwing/overview/).

Nichols Bridgeway follows the mapped north/south alignment across Lurie Garden and Monroe Street, then turns east into the third-floor terrace. The modeled deck rises smoothly from grade to **18 m**, with thin handrails, metal supports, and underside structure. The published bridge length is approximately **190 m / 625 ft**; the mapped centreline, including its turn, is used here. Its 4.57 m deck width and smooth rise are authored approximations. The museum documents the 60-foot high connection to Bluhm Family Terrace and the two-storey Griffin Court. [Modern Wing public spaces](https://archive.artic.edu/modernwing/public/).

## Interior and navigation

`ArtInstituteLayout` publishes these camera anchors for route authors:

| Place | Eye position (x, y, z), metres |
| --- | --- |
| Michigan Avenue central portal | (983.4, 5, −76.5) |
| Modern Wing north entrance | (1146, 2, −199) |
| Griffin Court turn | (1146, 2, −178) |
| East gallery | (1175, 2, −178) |

The modern floor is at y=0.20; the historic entrance floor is at y=3.2. The flythrough approaches the Modern Wing at x=1146, passes south through the ground entrance, and turns east at z=−178. Columns, the bench, picture frames, and portal edges sit outside this route. The historical entry hall also has a floor, columns, a high ceiling, and an interpretive monumental staircase.

The current [official museum floor-plan page](https://www.artic.edu/visit/explore-on-your-own/museum-floor-plan) informed the campus relationships: the Michigan Avenue entrance and grand stair are in the western building; Griffin Court runs south from the Modern Wing entrance; the shop lies to its west, and the Ryan Learning Center lies to its east. The modeled eastern exhibition room is **an authored architectural gallery**, not a claim about the current room use, collection hang, or exact internal circulation. Its framed geometric compositions are original geometry. No collection photographs or third-party art textures are included.

## References actually viewed

The following images were opened and visually inspected during implementation:

- The Renzo Piano foundation’s night photograph of the Modern Wing: warm cream interiors behind clear glass, slender silver vertical members, three exposed levels, and a broad white roof extending past the façade. This informed the north elevation and nighttime illumination. [Project record and photograph](https://www.fondazionerenzopiano.org/en/project/the-art-institute-of-chicago-the-modern-wing/).
- The museum’s historic frontal photograph and close lion photograph: central pediment, upper arched niches, projecting entry pavilion, muscular bronze bodies, and raised lion bases. [Museum lion history and photographs](https://www.artic.edu/articles/720/the-lions-of-michigan-avenue).
- The museum’s current first-floor plan: entry, courtyard, wing, and passage relationships. [Museum floor plan](https://www.artic.edu/visit/explore-on-your-own/museum-floor-plan).
- The museum’s aerial view: the historic building, the campus over the rail corridor, the large Modern Wing roof, and the park to the north. [Visit the Art Institute](https://www.artic.edu/visit).
- The museum archive’s Nichols Bridgeway photograph: its slender rising profile, open railings, and connection into the third-floor terrace. [Public spaces](https://archive.artic.edu/modernwing/public/).

Reference photographs were used for visual study and are not redistributed in the project. The building geometry, sculpture approximations, and gallery compositions are authored in Swift.

## Lighting and limits

Neutral warm-white gallery downlights and wall washers use actual scene light sources during the day and at night. Façade washes, concealed roof washers, and low bridge lights switch on at night. Their illumination and reflections interact with the stone, glazing, floors, and adjacent geometry. The Modern Wing’s warm interior and pale floating roof follow the foundation photograph. Plaster soffits cover the pavilion floor undersides; gallery frames, wall labels, baseboards, and shadow reveals add close-range detail. Fixture positions, lamp intensities, and the historic façade’s wash are visual interpretations, not an as-built photometric survey.

This is an architectural reconstruction rather than a surveyed digital twin. Geographic building extents, orientation, the published Modern Wing height, and Nichols Bridgeway’s destination are constrained by map data and primary references. Historic cornice elevations, bay details, stair risers, sculpture anatomy, bridge cross section, terrace furnishings, later wings, and interiors are approximations. Temporary construction, current exhibition installations, and operational access restrictions are not modeled. The neighboring campus wings have simpler exterior detail than the two featured fronts. Thin glass transmits straight through a surface without volumetric refraction or caustics.
