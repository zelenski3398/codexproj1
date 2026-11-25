"""Refine the mainland mesh with reliable samples from the bundled 2012 DTM."""
import json

import numpy as np
import rasterio
from pyproj import Transformer
from scipy.ndimage import distance_transform_edt, map_coordinates
from shapely import STRtree, distance, linestrings, points


class MainlandElevation:
    def __init__(self, asset, geography, original, boundary):
        self.settings = json.loads((asset / 'grading/elevation.json').read_text())
        with rasterio.open(asset / 'source' / self.settings['raster']) as raster:
            values = raster.read(1)
            valid = np.isfinite(values) & (values != raster.nodata)
            self.values = np.where(valid, values, 0)
            self.valid = valid.astype(float)
            self.survey_margin = distance_transform_edt(valid)
            self.inverse = ~raster.transform
            self.project = Transformer.from_crs(geography['crs'], raster.crs, always_xy=True)
        self.origin = Transformer.from_crs(4326, geography['crs'], always_xy=True).transform(
            *geography['origin_lon_lat'])
        self.original = original
        self.coast = original.coast
        self.coast_segments = linestrings(boundary)
        self.coast_index = STRtree(self.coast_segments)

    def heights(self, xz):
        original = self.original.heights(xz)
        x, y = self.project.transform(self.origin[0] + xz[:, 0], self.origin[1] - xz[:, 1])
        column, row = self.inverse * (x, y)
        coords = [row - .5, column - .5]
        coverage = map_coordinates(self.valid, coords, order=1)
        elevation = map_coordinates(self.values, coords, order=1) / np.maximum(coverage, 1e-8)
        # Fade through the last two pixels of survey edges. Keep the original
        # coastline, its cap and the steep nearshore profiles tied to the ring.
        margin = map_coordinates(self.survey_margin, coords, order=1)
        reliable = np.clip((margin - 1) / 2, 0, 1)
        limit = self.settings['full_detail_coast_distance_metres']
        coast = np.ones(len(xz))
        near, segments = self.coast_index.query_nearest(points(xz), max_distance=limit, all_matches=False)
        coast[near] = distance(points(xz[near]), self.coast_segments[segments]) / limit
        weight = reliable * coast * coast * (3 - 2 * coast)
        calibrated = elevation * self.settings['vertical_scale'] + self.settings['vertical_offset_metres']
        return original + (calibrated - original) * weight

    def refinement_points(self, bounds):
        spacing = self.settings['sample_spacing_metres']
        x = np.arange(np.floor(bounds[0, 0] / spacing) * spacing, bounds[1, 0], spacing) + spacing * .25
        z = np.arange(np.floor(bounds[0, 2] / spacing) * spacing, bounds[1, 2], spacing) + spacing * .375
        xx, zz = np.meshgrid(x, z)
        candidates = np.column_stack((xx.ravel(), zz.ravel()))
        original = self.original.heights(candidates)
        land = np.isfinite(original)
        candidates, original = candidates[land], original[land]
        refined = self.heights(candidates)
        return candidates[np.abs(refined - original) >= self.settings['minimum_relief_difference_metres']]
