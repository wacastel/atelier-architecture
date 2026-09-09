#!/usr/bin/env python3
"""Independent checks of emitted Hyde Park road meshes; requires Shapely 2.1.

Reads the derivative and dated OSM source without importing/running its preparer.
The mesh checks use actual triangle indices, including the renderer's XZ-to-XYZ
winding convention. This does not claim that omitted pedestrian tunnels exist.
"""
import argparse
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
import math
import struct
import tempfile
from pathlib import Path

from shapely import LineString, Point, Polygon, box, union_all

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "Sources/ArchitectureEngine/Resources/HydePark/HydeParkContext.json"
RAW = ROOT / "scripts/data/chicago-hyde-park-osm-2026-09-08.json"
PEDESTRIAN = {"footway", "path", "cycleway", "pedestrian", "steps"}
BRIDGES = {1166004942, 1166004940, 1166004944, 1166004921, 1344476701, 1344476703}
ONE_LANE = {281449302, 1166004939, 1166004940}
MAPPED_SIDEWALKS = {231032996, 1409644372, 314954677}
LOCAL = box(4540, 9545, 4655, 9660)
REFERENCE = "https://www.chicagoparkdistrict.com/parks-facilities/57th-street-underpass-mural-artwork"
checks = 0


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def twice_area(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def f32(value):
    return struct.unpack("f", struct.pack("f", value))[0]


def rendered_area(a, b, c):
    # Model the Float differences, products and subtraction used by the Swift
    # geometric cross product, rather than evaluating products in Python Double.
    dx1, dz1 = f32(f32(b[0]) - f32(a[0])), f32(f32(b[1]) - f32(a[1]))
    dx2, dz2 = f32(f32(c[0]) - f32(a[0])), f32(f32(c[1]) - f32(a[1]))
    return f32(f32(dx1 * dz2) - f32(dz1 * dx2))


def ring_shape(surface):
    shape = Polygon()
    for ring in surface["rings"]:
        check(len(ring) >= 3, "Surface contains a short boundary ring")
        polygon = Polygon(ring)
        check(polygon.is_valid, "Surface boundary ring is invalid")
        shape = shape.symmetric_difference(polygon)
    return shape


def projected_source(element, origin):
    lat, lon = origin
    return LineString([
        ((p["lon"] - lon) * 111320 * math.cos(math.radians(lat)),
         (lat - p["lat"]) * 111320)
        for p in element["geometry"]
    ])


def retained_carriageways(data):
    """Literal legacy segment rectangles, not the preparer's joined buffers.

    These older city roads still render where new Hyde surfaces are clipped at
    their shared boundary. Their dated hashes make that limited coverage credit
    explicit; a new road cannot pass merely because its own centerline exists.
    """
    parts = []
    for relative, expected in data["previousResourceSHA256"].items():
        previous_file = ROOT / relative
        check(digest(previous_file) == expected, "Retained city resource hash changed")
        previous = json.loads(previous_file.read_text())
        segments = []
        for path in previous.get("paths", []) + previous.get("bridges", []):
            if path.get("kind") in PEDESTRIAN or path.get("bridge") or abs(path.get("elevation", 0)) >= 1:
                continue
            segments.extend((a, b, path["width"]) for a, b in zip(path["points"], path["points"][1:]))
        for road in previous.get("roads", []):
            segments.extend(((a[0], a[2]), (b[0], b[2]), road["width"])
                            for a, b in zip(road["points"], road["points"][1:])
                            if abs(a[1]) < 1 and abs(b[1]) < 1)
        for a, b, width in segments:
            dx, dz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dz)
            if length < 0.01:
                continue
            nx, nz = -dz / length * width / 2, dx / length * width / 2
            parts.append(Polygon(((a[0] - nx, a[1] - nz), (a[0] + nx, a[1] + nz),
                                  (b[0] + nx, b[1] + nz), (b[0] - nx, b[1] - nz))))
    return union_all(parts)


def validate(resource):
    data = json.loads(resource.read_text())
    raw = json.loads(RAW.read_text())
    sources = {e["id"]: e for e in raw["elements"] if e.get("type") == "way"}
    paths = {p["id"]: p for p in data["paths"]}
    check(RAW.name in data["sourceSHA256"], "Dated OSM provenance is absent")
    check(data["sourceSHA256"][RAW.name] == digest(RAW), "Dated OSM source hash changed")
    check("roadSurfaces" in data and data["roadSurfaces"], "Unioned road surfaces are absent")

    kinds = {"asphalt": [], "pavement": [], "sidewalk": []}
    triangle_count = 0
    float_collapsed = 0
    float_collapsed_area = 0.0
    surfaces = []
    for item in data["roadSurfaces"]:
        surface, height = item["surface"], item["elevation"]
        kind = surface["kind"]
        check(kind in kinds, f"Unknown road-surface material kind {kind}")
        check(math.isfinite(height) and -0.1 <= height <= 0.5, "Ground road mesh is floating")
        check(abs(height - (0.12 if kind == "asphalt" else 0.19)) < 0.001,
              "Emitted material surface differs from its adjoining modeled grade")
        points, indices = surface["points"], surface["triangles"]
        check(len(indices) % 3 == 0 and indices, "Road surface lacks complete triangles")
        check(all(len(p) == 2 and all(math.isfinite(v) for v in p) for p in points), "Nonfinite road vertices")
        check(all(isinstance(i, int) and 0 <= i < len(points) for i in indices), "Road triangle index is invalid")
        triangles = []
        area_sum = 0.0
        for offset in range(0, len(indices), 3):
            a, b, c = (points[i] for i in indices[offset:offset + 3])
            area2 = twice_area(a, b, c)
            check(area2 > 1e-10, f"Nonpositive road triangle winding in {surface['id']}")
            # lakefrontSurface emits a,c,b in XYZ. Its geometric normal.y is
            # therefore this positive XZ determinant, including Float storage.
            rendered_area2 = rendered_area(a, b, c)
            check(rendered_area2 >= 0, "Road triangle flips downward after Float conversion")
            if rendered_area2 == 0:
                float_collapsed += 1
                float_collapsed_area += area2 / 2
            triangles.append(Polygon((a, b, c)))
            area_sum += area2 / 2
        triangle_count += len(triangles)
        actual = union_all(triangles)
        boundary = ring_shape(surface)
        tolerance = max(0.01, actual.area * 1e-9)
        check(actual.is_valid, "Emitted road triangle union is invalid")
        check(abs(area_sum - actual.area) < tolerance, "Overlapping triangles remain within a road mesh")
        check(actual.symmetric_difference(boundary).area < tolerance, "Actual triangles leave holes or cross surface boundary")
        kinds[kind].append(actual)
        surfaces.append({"id": surface["id"], "kind": kind, "elevation": height,
                         "triangles": len(triangles), "areaSquareMetres": actual.area})
    check(triangle_count < 250000, "Road correction exceeds its bounded triangle budget")
    check(float_collapsed_area < 0.01, "Meaningful road area collapses in renderer Float vertices")

    unions = {kind: union_all(parts) for kind, parts in kinds.items()}
    for kind, parts in kinds.items():
        check(sum(p.area for p in parts) - unions[kind].area < 0.01, f"Duplicate {kind} mesh surfaces overlap")
    overlap = {}
    for a, b in (("asphalt", "pavement"), ("asphalt", "sidewalk"), ("pavement", "sidewalk")):
        overlap[f"{a}/{b}"] = unions[a].intersection(unions[b]).area
        check(overlap[f"{a}/{b}"] < 0.01,
              f"Raised or coplanar {b} overlaps {a} by {overlap[f'{a}/{b}']:.6f} square metres")
    all_surface = union_all(list(unions.values()))
    lot = ring_shape(data["authoredMask"])
    check(all_surface.intersection(lot).area < 0.001, "Road mesh enters the authored Robie lot")

    continuity = []
    for ident in sorted(BRIDGES):
        check(ident in paths and ident in sources, f"Missing known 57th crossing {ident}")
        path, source = paths[ident], sources[ident]
        check(source["tags"].get("bridge") == "yes", "Expected source bridge relationship is missing")
        check(path["bridge"] == source["tags"]["bridge"], "Source bridge tag was erased")
        check(float(path["sourceLayer"]) == float(source["tags"]["layer"]), "Source layer provenance was erased")
        check(path["gradeSource"] == "57th_street_surface_grade_override", "57th grade interpretation is undocumented")
        check(0 <= path["elevation"] <= 0.5, f"False elevated slab remains at {ident}")
        source_line = projected_source(source, data["origin"])
        check(all(source_line.distance(Point(p)) <= 0.003 for p in path["points"]), "Crossing moved away from dated OSM geometry")
        ped = path["kind"] in PEDESTRIAN
        endpoint_rows = []
        for endpoint in (path["points"][0], path["points"][-1]):
            peers = [p for p in paths.values() if p["id"] != ident
                     and (p["kind"] in PEDESTRIAN) == ped
                     and any(math.dist(endpoint, q) < 0.02 for q in (p["points"][0], p["points"][-1]))]
            check(peers, f"Crossing {ident} has no mapped adjoining endpoint")
            check(all(abs(p["elevation"] - path["elevation"]) <= 0.005 for p in peers), f"Crossing {ident} has an elevation jump")
            endpoint_rows.append([p["id"] for p in peers])
        continuity.append({"id": ident, "elevation": path["elevation"], "endpointPeers": endpoint_rows})

    lane_widths = []
    for ident in sorted(ONE_LANE):
        check(sources[ident]["tags"].get("lanes") == "1", "One-lane source fixture changed")
        path = paths[ident]
        check(3.0 <= path["width"] <= 5.5, f"One-lane ramp {ident} is still widened to two lanes")
        check(path.get("widthSource"), "Width provenance is absent")
        lane_widths.append({"id": ident, "width": path["width"], "sourceLanes": 1})
    for ident in sorted(MAPPED_SIDEWALKS):
        check(sources[ident]["tags"].get("sidewalk:both") == "separate", "Separate-sidewalk source fixture changed")
        path = paths[ident]
        check(path["sidewalkLeft"] == "mapped" and path["sidewalkRight"] == "mapped", "Mapped sidewalks would be generated a second time")

    # Independent samples lie inside the source segment's carriageway width;
    # no triangulation or preparer buffer routine is reused to choose them.
    sample_count = 0
    bend_count = 0
    coverage_targets = {False: unions["asphalt"].buffer(0.004),
                        True: all_surface.buffer(0.004)}
    for path in paths.values():
        line = LineString(path["points"])
        if path["elevation"] > 0.5 or not line.intersects(LOCAL):
            continue
        ped = path["kind"] in PEDESTRIAN
        target = coverage_targets[ped]
        points, w = path["points"], path["width"] / 2
        normals = []
        for a, b in zip(points, points[1:]):
            dx, dz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dz)
            if length < 0.1:
                normals.append(None)
                continue
            n = (-dz / length, dx / length)
            normals.append(n)
            for f in (0.15, 0.5, 0.85):
                for offset in (-0.8 * w, 0, 0.8 * w):
                    q = Point(a[0] + dx * f + n[0] * offset, a[1] + dz * f + n[1] * offset)
                    if LOCAL.contains(q):
                        check(target.covers(q), f"Emitted road/junction mesh leaves a source-width gap on {path['id']}")
                        sample_count += 1
        for i in range(1, len(points) - 1):
            a, b = normals[i - 1], normals[i]
            if a is None or b is None or a[0] * b[0] + a[1] * b[1] < -0.49:
                continue
            nx, nz = a[0] + b[0], a[1] + b[1]
            length = math.hypot(nx, nz)
            if length < 0.01:
                continue
            for side in (-1, 1):
                q = Point(points[i][0] + side * nx / length * w * 0.7,
                          points[i][1] + side * nz / length * w * 0.7)
                if LOCAL.contains(q):
                    check(target.covers(q), f"Missing connected outer-corner wedge on {path['id']}")
                    bend_count += 1
    check(sample_count > 200 and bend_count > 20, "Insufficient actual-junction coverage probes")

    # Hyde Park's new LSD chains extend beyond the base-terrain WORLD box.
    # Their replacement surfaces must include the final tails, not silently
    # disappear at z=10800 when the legacy segment renderer is suppressed.
    drive_probes = 0
    retained_drive_probes = 0
    drive_max_z = max(q[2] for road in data["roads"] for q in road["points"])
    check(drive_max_z > 10920, "Expected mapped southern LSD tail is absent")
    drive_surface = coverage_targets[False]
    retained_surface = retained_carriageways(data).buffer(0.004)
    for road in data["roads"]:
        for a, b in zip(road["points"], road["points"][1:]):
            dx, dz = b[0] - a[0], b[2] - a[2]
            length = math.hypot(dx, dz)
            if length < 0.01:
                continue
            n = (-dz / length, dx / length)
            for fraction in (0, 0.25, 0.5, 0.75, 1):
                for offset in (-road["width"] * 0.4, 0, road["width"] * 0.4):
                    q = Point(a[0] + dx * fraction + n[0] * offset,
                              a[2] + dz * fraction + n[1] * offset)
                    new_coverage = drive_surface.covers(q)
                    prior_coverage = not new_coverage and retained_surface.covers(q)
                    check(new_coverage or prior_coverage, f"New LSD road surface omits mapped chain {road['id']} at {tuple(q.coords)[0]}")
                    if prior_coverage:
                        retained_drive_probes += 1
                    drive_probes += 1
    check(drive_probes > 100, "Insufficient LSD carriageway coverage probes")
    for ident in (1050626206, 1050626208):
        check(ident in paths, "A separately mapped 57th sidewalk disappeared")
        line = LineString(paths[ident]["points"])
        expected = line.buffer(paths[ident]["width"] * 0.40).intersection(LOCAL).difference(unions["asphalt"].buffer(0.02))
        check(expected.difference(unions["pavement"].buffer(0.004)).area < 0.03, "Mapped sidewalk coverage was lost")

    return {"passed": True, "checks": checks, "resourceSHA256": digest(resource),
            "sourceSHA256": digest(RAW), "surfaces": surfaces, "triangles": triangle_count,
            "floatCollapsedTriangles": float_collapsed, "floatCollapsedArea": float_collapsed_area,
            "materialOverlapSquareMetres": overlap, "bridgeEndpointContinuity": continuity,
            "oneLaneWidths": lane_widths, "sourceWidthProbes": sample_count, "bendProbes": bend_count,
            "driveCoverageProbes": drive_probes, "southernDriveExtentZ": drive_max_z,
            "driveProbesCoveredByRetainedCityQuads": retained_drive_probes,
            "officialUnderpassReference": REFERENCE,
            "scope": "Actual emitted triangle coverage/winding, disjoint at-grade materials, dated-source bridge endpoints, one-lane widths and separate-sidewalk policy. CPU only.",
            "limits": ["The official reference establishes two pedestrian underpasses, not surveyed heights.",
                       "The bounded road repair preserves source bridge/layer tags but does not reconstruct the omitted pedestrian tunnels or approach ramps. No underpass clearance is asserted.",
                       "Continuous geometry at the six surface crossings is checked; this is not a road-design or accessibility certification."]}


def reject_fixture(case):
    """A worker validates an isolated derivative with unchanged strict checks."""
    global checks
    name, expected, target = case
    checks = 0
    try:
        validate(target)
    except AssertionError as error:
        message = str(error)
        check(message.startswith(expected), f"Negative control {name} failed for an unexpected reason: {message}")
        return {"name": name, "rejected": True, "error": message,
                "checksBeforeRejection": checks - 1, "fixtureSHA256": digest(target)}
    raise AssertionError(f"Negative control {name} incorrectly passed")


def negative_controls(resource):
    """Exercise the same public validator against isolated corrupt derivatives."""
    cases = (
        ("reversed_triangle", "Nonpositive road triangle winding"),
        ("duplicate_asphalt_tile", "Duplicate asphalt mesh surfaces overlap"),
        ("floating_57th_bridge", "False elevated slab remains"),
        ("two_lane_width_for_one_lane_ramp", "One-lane ramp"),
        ("missing_southern_drive_tile", "New LSD road surface omits mapped chain"),
    )
    source_text = resource.read_text()
    pending = []
    with tempfile.TemporaryDirectory(prefix="atelier-road-oracle-") as folder:
        for name, expected in cases:
            fixture = json.loads(source_text)
            if name == "reversed_triangle":
                indices = fixture["roadSurfaces"][0]["surface"]["triangles"]
                indices[0], indices[1] = indices[1], indices[0]
            elif name == "duplicate_asphalt_tile":
                tile = next(x for x in fixture["roadSurfaces"] if x["surface"]["kind"] == "asphalt")
                fixture["roadSurfaces"].append(tile)
            elif name == "floating_57th_bridge":
                next(p for p in fixture["paths"] if p["id"] == 1166004940)["elevation"] = 7.0
            elif name == "two_lane_width_for_one_lane_ramp":
                next(p for p in fixture["paths"] if p["id"] == 281449302)["width"] = 7.7
            else:
                removed = [x for x in fixture["roadSurfaces"]
                           if x["surface"]["kind"] == "asphalt"
                           and max(p[1] for p in x["surface"]["points"]) > 10800]
                check(removed, "Southern-tail negative control found no target tile")
                fixture["roadSurfaces"] = [x for x in fixture["roadSurfaces"] if x not in removed]
            target = Path(folder) / f"{name}.json"
            target.write_text(json.dumps(fixture, separators=(",", ":")))
            pending.append((name, expected, target))
        # Three independent CPU workers bound repeated GEOS work. No renderer,
        # preparer or GPU job is launched, and all source data remain immutable.
        with ProcessPoolExecutor(max_workers=3) as pool:
            return list(pool.map(reject_fixture, pending))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resource", type=Path, default=RESOURCE)
    parser.add_argument("--negative-controls", action="store_true",
                        help="Also reject five isolated geometry/provenance regressions (CPU only)")
    arguments = parser.parse_args()
    try:
        report = validate(arguments.resource)
        if arguments.negative_controls:
            report["negativeControls"] = negative_controls(arguments.resource)
    except (AssertionError, KeyError, ValueError) as error:
        print(json.dumps({"passed": False, "checks": checks, "error": str(error)}, indent=2))
        raise SystemExit(1)
    print(json.dumps(report, indent=2))
