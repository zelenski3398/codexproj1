BRITISH LIGHT AA EMPLACEMENT — ORIGINAL GAME ASSET

Simplified Bofors-inspired British WWII static light AA position, not a measured historical replica. One gun emplacement; duplicate it to form a battery. No crew or firing/audio scripts.

Import British_AA_Emplacement.glb into Godot. Units are metres, Y up. Ground is Y=0. Footprint approximately 7.4 m across. Place root at the terrain surface; level the local terrain or remove the GroundPad mesh if needed.

Node structure: Emplacement > YawPivot > ElevationPivot > Muzzle.
Rotate YawPivot around local Y for traverse. ElevationPivot is initially elevated 32 degrees; set local rotation X to the desired elevation, rather than adding 32 degrees again. Gun forward is local -Z. Muzzle is an empty transform at the barrel exit for muzzle flashes/projectile spawning. Operator seats rotate with the mount; barrel, breech, ammunition and sights elevate together.

Materials are embedded PBR colours; no external textures required. No collisions are supplied: add simplified static collision for the emplacement and appropriate gun hitboxes in Godot. Sandbags are individually modelled; consider merging static pieces or generating LODs for many instances. This asset is visually checked but has not been tested inside your Godot project.

Preview.png is rendered from the actual mesh. build_model.py is the editable generator (Python with trimesh, numpy, matplotlib).

Historical context reference: https://film.iwmcollections.org.uk/record/23693 — British Bofors battery footage. Geometry is original and approximate, not copied from a museum asset.
