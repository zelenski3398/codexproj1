"""Project a hand-traced historic Mosta layout using the island's EPSG:32633 frame.

Run with Python 3, NumPy, pyproj, Shapely and Pillow. The two outputs are
deterministic, and all existing terrain and island-road assets are read-only.
"""
import json
import math
from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from pyproj import Transformer
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union
from shapely.affinity import rotate, translate

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/malta"
OUT = ASSETS / "mosta"
trace = json.loads((OUT / "reference_trace.json").read_text())
world = json.loads((ASSETS / "world_data.json").read_text())
project = Transformer.from_crs("EPSG:4326", world["crs"], always_xy=True)
origin = np.array(project.transform(*world["origin_lon_lat"]))


def xz(lon_lat):
    return (np.array(project.transform(*lon_lat)) - origin) * [1, -1]


# Validate the project frame independently of the historical image fit.
for field in world["airfields"]:
    expected = np.array(field["position"])[[0, 2]]
    assert np.linalg.norm(xz([field["longitude"], field["latitude"]]) - expected) < 0.10, field["id"]

anchor = xz(trace["anchor_lon_lat"])
pixel = np.array(trace["anchor_pixel"])
src = np.array([control["pixel"] for control in trace["control_points"]]) - pixel
dst = np.array([xz(control["lon_lat"]) - anchor for control in trace["control_points"]])
ratio = (np.vdot(src[:, 0] + 1j * src[:, 1], dst[:, 0] + 1j * dst[:, 1])
         / np.sum(src * src))
scale = trace["scale_metres_per_pixel"] or abs(ratio)
rotation = math.radians(trace["clockwise_degrees"]) if trace["clockwise_degrees"] is not None else np.angle(ratio)
matrix = scale * np.array([[math.cos(rotation), -math.sin(rotation)],
                           [math.sin(rotation), math.cos(rotation)]])


def local(points):
    return (np.array(points) - pixel) @ matrix.T


def rounded(points):
    return np.round(points, 4).tolist()


front_left, front_right = [xz(p) for p in trace["facade_endpoints_lon_lat"]]
run = front_right - front_left
front = np.array([-run[1], run[0]]) / np.linalg.norm(run)
yaw = math.atan2(front[0], front[1])
church_reserve = rotate(box(-35, -34, 35, 70), -math.degrees(yaw), origin=(0, 0))
square = rotate(Polygon([(-30, 43), (30, 43), (35, 66), (20, 79), (-32, 68)]), -math.degrees(yaw), origin=(0, 0))
built = unary_union([Polygon(local(p)) for p in trace["built_areas"]])
gaps = [Polygon(local(p)) for p in trace["gaps"]]
fields = [Polygon(local(p)) for p in trace["fields"]]
streets = [{"id": entry["id"], "width": entry["width"], "points": local(entry["pixels"])}
           for entry in trace["streets"]]
sources = json.loads((ASSETS / "roads/world_paths.json").read_text())["paths"]
old_inner = []
ties = []
junctions = {"ta_qali_mosta": "west_east", "mosta_birkirkara": "northwest_southeast"}
for source in sources:
    if source["id"] not in junctions:
        continue
    route = LineString(np.array(source["points"]) - anchor)
    cut = route.intersection(Point(0, 0).buffer(660))
    parts = [cut] if cut.geom_type == "LineString" else list(cut.geoms)
    old_inner.extend(part.buffer(max(source["width"] * 0.5 + 9, 13)) for part in parts)
    piece = min(parts, key=lambda item: item.distance(Point(0, 0)))
    endpoint = max([piece.coords[0], piece.coords[-1]], key=lambda p: np.linalg.norm(p))
    street = next(s for s in streets if s["id"] == junctions[source["id"]])
    along = LineString(street["points"])
    # Join a forward branch close to the boundary via the actual tangency.
    match = along.interpolate(along.project(Point(endpoint)))
    if Point(endpoint).distance(match) > 1:
        station = route.project(Point(endpoint))
        sign = -1 if source["id"] == "ta_qali_mosta" else 1
        extension = route.interpolate(max(0, min(route.length, station + sign * 24)))
        line = np.array([extension.coords[0], endpoint, match.coords[0]])
        streets.append({"id": source["id"] + "_tie", "width": street["width"], "points": line})
    ties.append({"id": source["id"], "world_xz": rounded(np.array(endpoint) + anchor),
                 "join_local_xz": rounded(match.coords[0])})

reserve = unary_union([church_reserve, square.buffer(3), *gaps, *fields])
road_shapes = [LineString(s["points"]).buffer(s["width"] * 0.5 + 0.6) for s in streets]
road_space = unary_union(road_shapes)
allowed = built.difference(unary_union([reserve, road_space]))
houses = []
occupied = []
rng = random.Random(trace["seed"])


def place(center, width, depth, angle, side, kind, host):
    footprint = translate(rotate(box(-width / 2, -depth / 2, width / 2, depth / 2), angle, origin=(0, 0)), *center)
    if not host.covers(footprint) or footprint.intersects(road_space) or footprint.intersects(church_reserve):
        return False
    if any(footprint.intersection(existing).area > 0.12 for existing in occupied):
        return False
    occupied.append(footprint)
    storeys = rng.choices([1, 2, 3], [42, 53, 5])[0] if kind != "farm" else 1
    houses.append({"id": f"house_{len(houses)+1:03}", "xz": rounded(center), "size": [round(width, 3), round(depth, 3)],
                   "yaw_deg": round(-angle + (180 if side > 0 else 0), 3),
                   "height": round(storeys * rng.uniform(2.85, 3.3) + 0.45, 3),
                   "stone": rng.randrange(4), "kind": kind, "balcony": storeys > 1 and rng.random() < 0.14,
                   "roof_room": storeys > 1 and rng.random() < 0.24})
    return True


for street in streets:
    if street["id"].endswith("_tie") or street["id"] == "bridge_approach":
        continue
    line = LineString(street["points"])
    for side in (-1, 1):
        station = 5.0
        while station < line.length - 5.0:
            width = rng.uniform(5.5, 10.4)
            depth = rng.uniform(7.5, 14.0)
            along = np.array(line.interpolate(station).coords[0])
            tangent = np.array(line.interpolate(station + 1).coords[0]) - np.array(line.interpolate(station - 1).coords[0])
            tangent /= np.linalg.norm(tangent)
            normal = np.array([-tangent[1], tangent[0]])
            setback = street["width"] * 0.5 + depth * 0.5 + rng.uniform(1.0, 2.5)
            center = along + side * normal * setback
            angle = math.degrees(math.atan2(tangent[1], tangent[0]))
            if rng.random() > 0.08:
                place(center, width, depth, angle, side, "townhouse", allowed)
            station += width + rng.choice([0.25, 0.5, 0.9, 1.6])

# Densify larger street blocks in varied rows while retaining the traced gaps.
for street in [s for s in streets if s["id"] not in {"bridge_approach"} and not s["id"].endswith("_tie")]:
    line = LineString(street["points"])
    for side in (-1, 1):
        station = 9.0
        while station < line.length - 9.0:
            along = np.array(line.interpolate(station).coords[0])
            direction = np.array(line.interpolate(station + 1).coords[0]) - np.array(line.interpolate(station - 1).coords[0])
            direction /= np.linalg.norm(direction)
            for setback in [16.0, 29.0, 42.0]:
                if rng.random() < (0.54 if setback == 42 else 0.66):
                    continue
                center = along + side * np.array([-direction[1], direction[0]]) * setback
                place(center, rng.uniform(5.7, 10.0), rng.uniform(6.8, 11.7), math.degrees(math.atan2(direction[1], direction[0])), side, "court_back", allowed)
            station += rng.uniform(8, 13)

yards = []
farm_host = Point(0, 0).buffer(600).difference(reserve)
for i, center in enumerate(local(trace["farm_yards"])):
    if place(center, 10, 7, rng.uniform(-26, 26), 1, "farm", farm_host):
        fence = box(center[0] - 9, center[1] - 5, center[0] + 9, center[1] + 12)
        yards.append({"id": f"farm_yard_{i:02}", "points": rounded(fence.exterior.coords)})

mask_world_min = anchor + [-975, -975]
mask_size = 1950.0
image_size = 1024


def raster(shapes, blur):
    img = Image.new("L", (image_size, image_size))
    draw = ImageDraw.Draw(img)
    for shape in shapes:
        for part in [shape] if shape.geom_type == "Polygon" else shape.geoms:
            if part.is_empty or part.geom_type != "Polygon":
                continue
            def pixels(coords):
                return [tuple(p) for p in (np.array(coords) + anchor - mask_world_min) * image_size / mask_size]
            draw.polygon(pixels(part.exterior.coords), fill=255)
            for interior in part.interiors:
                draw.polygon(pixels(interior.coords), fill=0)
    return img.filter(ImageFilter.GaussianBlur(blur))


replaced = raster(old_inner, 2.0)
paths = raster([LineString(s["points"]).buffer(s["width"] * .5) for s in streets if s["width"] >= 6], .72)
lanes = raster([LineString(s["points"]).buffer(s["width"] * .5) for s in streets if s["width"] < 6], .67)
paths = ImageChops.lighter(paths, lanes.point(lambda i: round(i * .78)))
paving = raster([square], 0.7)
cultivation = raster(fields + gaps, 0.85).point(lambda pixel: round(pixel * .39))
paving = ImageChops.lighter(paving, cultivation)
covered = unary_union([built.buffer(3), church_reserve.buffer(4), square.buffer(4), *gaps, *fields,
                       road_space.intersection(Point(0, 0).buffer(755)),
                       *[Polygon(yard["points"]).buffer(2) for yard in yards]])
exclusions = [covered] if covered.geom_type == "Polygon" else list(covered.geoms)
raster(exclusions, .30).convert("RGB").save(OUT / "scenery_mask.png", optimize=True)
Image.merge("RGB", [paths, replaced, paving]).save(OUT / "surface_mask.png", optimize=True)
report = {
    "crs": world["crs"], "origin_world": [float(anchor[0]), 0, float(anchor[1])],
    "anchor_lon_lat": trace["anchor_lon_lat"], "facade_bearing_clockwise_from_north": 180 - math.degrees(yaw),
    "facade_yaw": yaw, "rotunda": trace["rotunda"], "alignment_scale": scale,
    "alignment_clockwise_degrees": math.degrees(rotation),
    "controls": [{**c, "residual_m": float(np.linalg.norm(local(c["pixel"]) - d))}
                 for c, d in zip(trace["control_points"], dst)],
    "mask_world_min": rounded(mask_world_min), "mask_span": mask_size,
    "exclusions": [{"shell": rounded(part.exterior.coords), "holes": [rounded(ring.coords) for ring in part.interiors]} for part in exclusions],
    "outline": [rounded(p.exterior.coords) for p in [built] if p.geom_type == "Polygon"]
                if built.geom_type == "Polygon" else [rounded(p.exterior.coords) for p in built.geoms],
    "gaps": [rounded(p.exterior.coords) for p in gaps], "square": rounded(square.exterior.coords),
    "streets": [{**s, "points": rounded(s["points"])} for s in streets], "road_ties": ties,
    "houses": houses, "farms": yards, "fields": [rounded(p.exterior.coords) for p in fields],
}
(OUT / "layout.json").write_text(json.dumps(report, separators=(",", ":")) + "\n")
print(f"Mosta anchor {anchor}, {len(houses)} houses, {len(streets)} streets, front bearing {report['facade_bearing_clockwise_from_north']:.2f}")
print(f"Fit {scale:.3f} m/pixel at {math.degrees(rotation):.2f}°, residuals {[round(p['residual_m']) for p in report['controls']]} m")
