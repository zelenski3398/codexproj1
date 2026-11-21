"""Compose trace and in-engine village panoramas from the capture test."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1] / "assets/malta"
PANEL = (440, 277)


def load(path):
    return json.loads((ROOT / path).read_text())


def map_panel(site):
    panel = Image.new("RGB", PANEL, "#e1d3ac")
    draw = ImageDraw.Draw(panel)
    minx, minz, maxx, maxz = site["bounds"]
    center_x = (minx + maxx) / 2
    center_z = (minz + maxz) / 2
    height = max(max(maxz - minz, (maxx - minx) * .63) * 1.09, 180)
    scale = PANEL[1] / height

    def point(x, z):
        return ((x-center_x)*scale+PANEL[0]/2, (z-center_z)*scale+PANEL[1]/2)

    spacing = 100
    for x in range(int(center_x-height)//spacing*spacing, int(center_x+height)+spacing, spacing):
        px, _ = point(x, center_z)
        draw.line([(px, 0), (px, PANEL[1])], fill="#cec095")
    for z in range(int(minz)//spacing*spacing, int(maxz)+spacing, spacing):
        _, pz = point(center_x, z)
        draw.line([(0, pz), (PANEL[0], pz)], fill="#cec095")
    for shape in site["polygons"]:
        draw.polygon([point(*p) for p in shape["shell"]], fill="#b5a486", outline="#746652")
        for hole in shape["holes"]:
            draw.polygon([point(*p) for p in hole], fill="#e1d3ac", outline="#746652")
    for street in site["streets"]:
        draw.line([point(*p) for p in street["points"]], fill="#9b563b",
                  width=max(1, int(street["width"]*scale)))
    for church in site["churches"]:
        draw.polygon([point(*p) for p in church["footprint_world"]], fill="#564933")
        x, y = point(*church["center_world"])
        radius = 4 if church["minor"] else 6
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), outline="#613627", width=2)
    draw.line([(15, 249), (15+100*scale, 249)], fill="#423a2b", width=2)
    draw.text((15, 254), "100 m", fill="#423a2b")
    draw.text((410, 12), "N", fill="#423a2b")
    draw.line([(414, 28), (414, 46)], fill="#423a2b", width=2)
    draw.polygon([(409, 31), (419, 31), (414, 25)], fill="#423a2b")
    return panel


def atlas(sites, captures, output):
    page = Image.new("RGB", (1360, 28 + len(sites)*322), "#292722")
    draw = ImageDraw.Draw(page)
    font = ImageFont.truetype("DejaVuSans.ttf", 16)
    labels = ["Registered interpretation", "In-game overhead", "In-game oblique"]
    for column, label in enumerate(labels):
        draw.text((12 + column*449, 9), label, font=font, fill="#e9dbbd")
    for index, site in enumerate(sites):
        y = 35 + index*322
        draw.text((12, y+4), site["name"], font=font, fill="#e9dbbd")
        if "polygons" in site:
            page.paste(map_panel(site), (12, y+30))
        else:
            draw.text((20, y+65), "Existing reconstruction and source trace in project documentation.",
                      font=font, fill="#e9dbbd")
        for i, view in enumerate(("overhead", "oblique"), 1):
            with Image.open(captures / f"{site['id']}-{view}.jpg") as image:
                page.paste(ImageOps.fit(image, PANEL), (12 + i*449, y+30))
    page.save(output, quality=86, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    sites = {s["id"]: s for s in load("villages/layout.json")["sites"]}
    existing = {"mosta": "Mosta", "mdina": "Mdina"}
    sites.update({k: {"id": k, "name": v} for k, v in existing.items()})
    groups = {
        "central": ["mosta", "attard", "lija", "balzan", "birkirkara", "qormi"],
        "north": ["naxxar", "gharghur", "st_andrews", "pembroke", "st_julians"],
        "west": ["mdina", "rabat", "hal_bajada", "zebbug", "siggiewi", "qrendi"],
        "south": ["mqabba", "gudja", "kirkop", "safi", "zurrieq", "nigret", "bubaqra"],
    }
    args.output.mkdir(parents=True, exist_ok=True)
    for name, group in groups.items():
        atlas([sites[key] for key in group], args.captures, args.output / f"{name}.jpg")


if __name__ == "__main__":
    main()
