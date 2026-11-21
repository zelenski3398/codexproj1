"""Generate deterministic terrain overlays and building lots from registered historic traces."""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from pyproj import Transformer
from shapely.affinity import rotate
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import nearest_points, unary_union
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parents[1] / "assets/malta"
DEST = ROOT / "villages"


def read(path):
    return json.loads((ROOT / path).read_text())


world = read("world_data.json")
project = Transformer.from_crs(4326, world["crs"], always_xy=True)
east, north = project.transform(*world["origin_lon_lat"])


def world_point(lon, lat):
    x, y = project.transform(lon, lat)
    return complex(x - east, north - y)


def pair(z):
    return [round(z.real, 2), round(z.imag, 2)]


def as_complex(coords):
    return complex(*coords)


def rounded(coords):
    return [pair(as_complex(p)) for p in coords]


def polygon_parts(shape):
    if shape.geom_type == "Polygon":
        return [shape] if not shape.is_empty else []
    return [g for g in shape.geoms if g.geom_type == "Polygon" and not g.is_empty]


def line_parts(shape):
    if shape.geom_type == "LineString":
        return [shape] if not shape.is_empty else []
    return [g for g in shape.geoms if g.geom_type == "LineString" and not g.is_empty]


def footprint(church):
    original = church["footprint_lon_lat"]
    shape = Polygon([pair(world_point(*p)) for p in original]).buffer(0)
    if shape.geom_type != "Polygon":
        shape = max(shape.geoms, key=lambda part: part.area)
    center = as_complex(shape.centroid.coords[0])
    corners = list(shape.minimum_rotated_rectangle.exterior.coords)[:4]
    vectors = [as_complex(b) - as_complex(a) for a, b in zip(corners, corners[1:] + corners[:1])]
    axis = max(vectors, key=abs)
    hint = math.radians(church["front_bearing_hint"])
    facade = complex(math.sin(hint), -math.cos(hint))
    if (axis * facade.conjugate()).real < 0:
        axis = -axis
    size = [min(map(abs, vectors)), max(map(abs, vectors))]
    yaw = math.atan2(axis.real, axis.imag)
    original_point = church.pop("supplied_lat_lon")
    correction = None
    if original_point:
        correction = round(abs(center - world_point(*original_point[::-1])), 2)
    church.update(
        center_world=pair(center), footprint_world=rounded(shape.exterior.coords),
        footprint_center_lon_lat=project.transform(center.real + east, north - center.imag, direction="INVERSE"),
        source_lat_lon=original_point, correction_m=correction,
        size=[round(v, 2) for v in size], yaw_deg=round(math.degrees(yaw), 2), model_pivot_offset_m=[0, 0]
    )
    return center, shape


def alignment(control, centres):
    src = np.array([complex(x, y) for _, x, y in control])
    dst = np.array([centres[key] for key, _, _ in control])
    if len(src) == 1:
        scale_rotation = 2.85 + 0j
    else:
        centered = src - src.mean()
        scale_rotation = np.vdot(centered, dst - dst.mean()) / np.vdot(centered, centered)
    offset = dst.mean() - scale_rotation * src.mean()
    residual = abs(src * scale_rotation + offset - dst)
    meta = dict(
        metres_per_pixel=round(abs(scale_rotation), 4),
        rotation_deg=round(math.degrees(np.angle(scale_rotation)), 3),
        offset_world=pair(offset), controls=[p[0] for p in control],
        control_residuals_m=[round(float(v), 2) for v in residual],
        confidence="approximate north-up scale" if len(src) == 1 else (
            "two point fit; no independent residual" if len(src) == 2 else "multi-control similarity fit"),
    )
    return lambda p: pair(as_complex(p) * scale_rotation + offset), meta


def house(rng, site, used, lot, center, size, yaw, kind):
    if any(lot.intersects(other) for other in used):
        return
    used.append(lot)
    height = rng.choice([4.0, 5.9, 6.4, 7.0]) if kind == "town" else rng.uniform(3.6, 5.4)
    site["houses"].append(dict(
        id=f"Plot{len(site['houses']):04}", xz=pair(as_complex(center) - as_complex(site["origin"])),
        size=[round(x, 2) for x in size], yaw_deg=round(yaw, 2), height=round(height, 2),
        stone=rng.randrange(4), kind=kind, roof_room=kind == "town" and rng.random() < .24,
        balcony=kind == "town" and height > 5.5 and rng.random() < .13,
    ))


def lot_at(x, z, width, depth, yaw):
    return rotate(box(x - width / 2, z - depth / 2, x + width / 2, z + depth / 2), -yaw)


def lot_records(site, land, streets, reserves, military):
    rng = random.Random(site["id"])
    field_areas = []
    used = []
    if military:
        # Straight, widely separated wings around the open centre of each compound.
        for z in (-125, -43, 47, 82):
            for x in (-73, 65, 138):
                if x == 65 and z in (-43, 47):
                    continue
                center = as_complex(site["origin"]) + complex(x, z)
                width, depth = rng.choice([43, 51, 59]), rng.choice([10, 12, 14])
                lot = lot_at(*pair(center), width, depth, 0)
                if land.covers(lot) and not reserves.intersects(lot):
                    house(rng, site, used, lot, pair(center), (width, depth), 0, "barrack")
        return
    # Reserve enclosed gardens on the interior side of street blocks rather than
    # filling the hatch evenly. Keep all open spaces free of road and church geometry.
    interior = land.buffer(-18).difference(reserves.buffer(13))
    for region in sorted(polygon_parts(interior), key=lambda p: -p.area)[:10]:
        if region.area < 1250:
            continue
        p = region.representative_point()
        yard = box(p.x - 12, p.y - 10, p.x + 12, p.y + 10)
        if region.covers(yard):
            field_areas.append(yard)
    if field_areas:
        reserves = reserves.union(unary_union(field_areas))
    for street, road_width in streets:
        for side in (-1, 1):
            station = 10.0
            while station < street.length - 5:
                width, depth = rng.uniform(6.5, 12), rng.uniform(5.9, 12)
                here = as_complex(street.interpolate(station).coords[0])
                tangent = as_complex(street.interpolate(station + 1).coords[0]) - here
                if abs(tangent) < .1:
                    break
                tangent /= abs(tangent)
                point = here + tangent * 1j * side * (road_width / 2 + depth / 2 + 2.5)
                yaw = -math.degrees(math.atan2(tangent.imag, tangent.real)) + (180 if side == 1 else 0)
                lot = lot_at(*pair(point), width, depth, yaw)
                if land.covers(lot) and not reserves.intersects(lot):
                    house(rng, site, used, lot, pair(point), (width, depth), yaw, "town")
                station += width + rng.uniform(.5, 2.7)
    minx, minz, maxx, maxz = land.bounds
    for z in np.arange(minz + 12, maxz, 31):
        for x in np.arange(minx + 12, maxx, 31):
            point = Point(x + rng.uniform(-4, 4), z + rng.uniform(-4, 4))
            if not land.covers(point):
                continue
            distance = reserves.distance(point)
            if distance > 36 and rng.random() > .12:
                continue
            if distance < 13:
                continue
            width, depth = rng.uniform(7, 14), rng.uniform(7, 12)
            yaw = rng.choice([20, 90, 160])
            lot = lot_at(point.x, point.y, width, depth, yaw)
            if land.covers(lot) and not reserves.intersects(lot):
                kind = "farm" if distance > 48 else "town"
                previous = len(used)
                house(rng, site, used, lot, point.coords[0], (width, depth), yaw, kind)
                if kind == "farm" and len(used) > previous:
                    yard = lot.buffer(4, join_style=2)
                    if land.covers(yard) and not reserves.intersects(yard):
                        field_areas.append(yard)
                        reserves = reserves.union(yard)
    origin = as_complex(site["origin"])
    site["yards"] = [[pair(as_complex(p) - origin) for p in yard.exterior.coords] for yard in field_areas]


def raster(footprints, streets, squares, bounds):
    size = 4096
    minx, minz, span = bounds
    scale = size / span

    def coords(points):
        return [((x - minx) * scale, (z - minz) * scale) for x, z in points]

    roads, regions, plazas = [Image.new("L", (size, size)) for _ in range(3)]
    for shape in polygon_parts(footprints):
        draw = ImageDraw.Draw(regions)
        draw.polygon(coords(shape.exterior.coords), fill=255)
        for hole in shape.interiors:
            draw.polygon(coords(hole.coords), fill=0)
    for line, width in streets:
        ImageDraw.Draw(roads).line(coords(line.coords), fill=235, width=max(1, round(width * scale)), joint="curve")
    for square in squares:
        ImageDraw.Draw(plazas).polygon(coords(square.exterior.coords), fill=220)
    Image.merge("RGB", (roads, regions, plazas)).save(DEST / "surface.png", optimize=True)


def main():
    churches = read("villages/church_footprints.json")
    names = read("villages/names.json")
    crops = read("villages/traces.json")
    centre, footprint_shapes = {}, {}
    for church in churches:
        pivot, shape = footprint(church)
        footprint_shapes[church["id"]] = shape
        if not church["minor"]:
            centre[church["id"]] = pivot
    mdina = read("mdina/layout.json")
    mosta = read("mosta/layout.json")
    centre["mdina"] = as_complex(mdina["origin_world"][::2])
    centre["mosta"] = as_complex(mosta["origin_world"][::2])
    for key, (lat, lon) in crops["coast"]["approximate_centres_lat_lon"].items():
        centre[key] = world_point(lon, lat)
    keep_clear = [Polygon(mdina["outline_world_xz"]).buffer(14)]
    for field in world["airfields"]:
        x, _, z = field["position"]
        corridor = box(x-135, z-field["length"]/2-50, x+135, z+field["length"]/2+50)
        keep_clear.append(rotate(corridor, field["heading"], origin=(x, z)))
    keep_clear = unary_union(keep_clear)
    shapes, tracks, alignment_report = {}, {}, {}
    for crop, datum in crops.items():
        if not datum.get("areas"):
            continue
        if datum["controls"]:
            convert, info = alignment(datum["controls"], centre)
        else:
            info = {"confidence": "adjustable approximate site geometry; supplied crop not identifiable"}
        alignment_report[crop] = info
        for key, record in datum["areas"].items():
            pivot = centre.get(key)
            if not datum["controls"]:
                def convert(p):
                    return pair(pivot + as_complex(p))
            shape = Polygon([convert(p) for p in record["outline"]]).buffer(0)
            # Safi has two overlapping sightings. The dedicated Safi crop
            # establishes the historic core; the Kirkop view corroborates it.
            if key == "safi" and crop == "safi_zurrieq":
                shapes.pop(key, None)
                tracks.pop(key, None)
            shapes[key] = shapes.get(key, Polygon()).union(shape)
            tracks.setdefault(key, []).extend((LineString([convert(p) for p in points]), 7.0 if i == 0 else 5.0)
                                              for i, points in enumerate(record["streets"]))
    # Maintain a small public apron at each church. Additional surviving
    # chapels outside the main hatched outline still replace local scenery.
    squares = {}
    for church in churches:
        key, village = church["id"], church["village"]
        shape = footprint_shapes[key]
        squares[key] = shape.buffer(2.5 if church["minor"] else 8, join_style=2).convex_hull
        shapes[village] = shapes[village].union(squares[key].buffer(1))
    military = crops["coast"]["military_landmarks"]
    for item in military:
        item["center_world"] = pair(world_point(*item["lat_lon"][::-1]))
        apron = lot_at(*item["center_world"], *item["size"], item["yaw_deg"]).buffer(7)
        squares[item["id"]] = apron
        district = item["village"]
        shapes[district] = shapes[district].union(apron.buffer(2))
    church_reserve = unary_union(list(squares.values()))
    original_routes = [LineString(path["points"]) for path in read("roads/world_paths.json")["paths"]]
    route_tree = STRtree(original_routes)
    current_streets, occupied, sites = [], Polygon(), {}
    for district, perimeter in shapes.items():
        land = perimeter.difference(keep_clear).difference(occupied.buffer(3))
        if land.is_empty:
            continue
        origin = centre.get(district, as_complex(land.centroid.coords[0]))
        occupied = occupied.union(land)
        local_churches = [c for c in churches if c["village"] == district]
        roads = []
        for raw_line, width in tracks[district]:
            # Join the incoming centerline to nearby existing roads only
            # where the projection has enough room outside protected objects.
            endpoints = []
            for coords in (raw_line.coords[0], raw_line.coords[-1]):
                point = Point(coords)
                nearest = original_routes[int(route_tree.nearest(point))]
                _, joint = nearest_points(point, nearest)
                if 3 < joint.distance(point) < 76 and point.distance(land.boundary) < 52:
                    endpoints.append(joint.coords[0])
                else:
                    endpoints.append(coords)
            line = LineString([endpoints[0], *raw_line.coords, endpoints[1]]).simplify(.6)
            exclusions = keep_clear.union(church_reserve.buffer(-2))
            roads.extend((part, width) for part in line_parts(line.difference(exclusions)) if part.length > 4)
        current_streets.extend(roads)
        sources = [key for key, crop in crops.items() if district in crop.get("areas", {})]
        if district == "attard":
            sources.append("three_villages")
        if district == "zurrieq":
            sources.append("safi_zurrieq")
        sites[district] = dict(id=district, name=names[district], source_crops=sources, origin=pair(origin), houses=[], yards=[],
                               churches=local_churches, streets=[], polygons=[], bounds=list(land.bounds),
                               military=[item for item in military if item["village"] == district])
        sites[district]["polygons"] = [dict(shell=rounded(p.exterior.coords), holes=[rounded(h.coords) for h in p.interiors])
                                        for p in polygon_parts(land)]
        sites[district]["streets"] = [dict(points=rounded(line.coords), width=width) for line, width in roads]
    roads = unary_union([line.buffer(width/2 + 1) for line, width in current_streets])
    reserves = roads.union(church_reserve)
    for district, site in sites.items():
        land = unary_union([Polygon(p["shell"], p["holes"]) for p in site["polygons"]])
        drawn_roads = [(LineString(r["points"]), r["width"]) for r in site["streets"]]
        lot_records(site, land, drawn_roads, reserves, district in ("pembroke", "st_andrews"))
    region = occupied.union(roads).difference(keep_clear)
    lowx, lowz, highx, highz = region.bounds
    bounds = [math.floor(lowx)-12, math.floor(lowz)-12, math.ceil(max(highx-lowx, highz-lowz))+24]
    raster(region, current_streets, list(squares.values()), bounds)
    state = dict(sites=list(sites.values()), alignments=alignment_report, mask=bounds,
                 existing=[{"id": "mosta", "origin": pair(centre["mosta"]), "source_crops": ["mosta_archival"]},
                           {"id": "mdina", "origin": pair(centre["mdina"]), "source_crops": ["rabat_mdina"]}])
    (DEST / "layout.json").write_text(json.dumps(state, ensure_ascii=False, separators=(",", ":")) + "\n")
    for key, site in sites.items():
        print(f"{key:14} {len(site['houses']):4} buildings, {len(site['churches']):2} churches, {len(site['streets']):2} routes")
    print(json.dumps(alignment_report, indent=2))


if __name__ == "__main__":
    main()
