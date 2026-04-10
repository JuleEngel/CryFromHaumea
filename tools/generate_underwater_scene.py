#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Generate the complete underwater.tscn scene file with cave layout and atmosphere."""

import struct
import os

OUTPUT = os.path.join(os.path.dirname(__file__), "..", "levels", "underwater.tscn")

# ── Cave layout definition ──────────────────────────────────────────
# '#' = wall tile, '.' = open water
# The submarine starts near the top-left open area

CAVE = """\
######################################################
######################################################
######################################################
#####...............##############...............######
####.................############.................#####
###...................##########...................####
##.....................########.....................###
#.......................######.......................##
#........................####........................#
#.........................##.........................#
#...................................................#
#...................................................#
#...................................................#
#.........##....................................##...#
#........####..................................####..#
#.......######................................######.#
##.....########.........######...............#########
###...##########.......########.............##########
####.############.....##########...........#########..
#####.############...############.........########....
#####..############.##############.......########.....
####....##########...############.......########......
###......########.....##########.......########.....##
##........######.......########.......########.....###
#..........####.........######.......########.....####
#...........##...........####.......########.....#####
#.............................#....########......#####
#..............................##.########.......#####
#...............................#..######..........###
#..............................................##...##
#...............................................###..#
#................................................####
##................................................####
###...............................................####
####...............................................###
#####...............................................##
######...............................................#
#######..............................................#
########....................##........................#
#########..................####......................##
##########................######....................###
###########..............########..................####
############............##########................#####
#############..........############..............######
##############........##############............#######
###############......################..........########
################....##################........########
#################..####################......#########
######################################################
######################################################
"""


def parse_cave(cave_str):
    """Parse cave string into a set of wall cell coordinates, centered at origin."""
    walls = set()
    lines = cave_str.strip().split("\n")
    height = len(lines)
    width = max(len(line) for line in lines)
    ox, oy = width // 2, height // 2

    for row, line in enumerate(lines):
        for col, ch in enumerate(line):
            if ch == "#":
                walls.add((col - ox, row - oy))
    return walls


def get_atlas_coords(cx, cy, walls):
    """Pick atlas tile based on 4-neighbor connectivity."""
    has_top = (cx, cy - 1) in walls
    has_right = (cx + 1, cy) in walls
    has_bottom = (cx, cy + 1) in walls
    has_left = (cx - 1, cy) in walls
    index = has_top * 1 + has_right * 2 + has_bottom * 4 + has_left * 8
    return index % 4, index // 4


def encode_tile_map_data(walls):
    """Encode wall positions into TileMapLayer PackedByteArray."""
    data = bytearray()
    for cx, cy in sorted(walls):
        ax, ay = get_atlas_coords(cx, cy, walls)
        data.extend(struct.pack("<hhHHHH", cx, cy, 0, ax, ay, 0))

    return ", ".join(str(b) for b in data)


def main():
    walls = parse_cave(CAVE)
    tile_data = encode_tile_map_data(walls)

    scene = f"""\
[gd_scene format=3 uid="uid://cufte051u5rd"]

[ext_resource type="PackedScene" uid="uid://dxx4cju371esd" path="res://game_objects/submarine/submarine.tscn" id="1_sub"]
[ext_resource type="PackedScene" uid="uid://dirkbudgjfg5" path="res://game_objects/alien1/alien1.tscn" id="2_alien"]
[ext_resource type="TileSet" path="res://levels/tilesets/ice_cave_tileset.tres" id="3_tileset"]
[ext_resource type="Shader" path="res://visual_effects/underwater.gdshader" id="4_water"]
[ext_resource type="Script" path="res://visual_effects/underwater_effect.gd" id="5_effect"]
[ext_resource type="Texture2D" uid="uid://djftd7mdgmb5y" path="res://game_objects/submarine/bubble.png" id="6_bubble"]
[ext_resource type="Texture2D" path="res://levels/tilesets/debris_dot.png" id="7_debris"]
[ext_resource type="Texture2D" path="res://levels/tilesets/stalactite_01.png" id="8_stal1"]
[ext_resource type="Texture2D" path="res://levels/tilesets/stalactite_02.png" id="9_stal2"]
[ext_resource type="Texture2D" path="res://levels/tilesets/crystal_01.png" id="10_crystal"]
[ext_resource type="Shader" path="res://levels/tilesets/ice_edge_smooth.gdshader" id="11_edge"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_water"]
shader = ExtResource("4_water")

[sub_resource type="ShaderMaterial" id="ShaderMaterial_edge"]
shader = ExtResource("11_edge")
shader_parameter/glow_radius = 4.0
shader_parameter/glow_strength = 0.6
shader_parameter/glow_color = Color(0.48, 0.72, 0.88, 1.0)

[sub_resource type="Gradient" id="Gradient_biolum"]
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_biolum"]
gradient = SubResource("Gradient_biolum")
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 0)

[sub_resource type="Curve" id="Curve_debris_scale"]
_data = [Vector2(0, 0.5), 0.0, 0.0, 0, 0, Vector2(0.5, 1.0), 0.0, 0.0, 0, 0, Vector2(1, 0.0), 0.0, 0.0, 0, 0]
point_count = 3

[node name="Underwater" type="Node2D" unique_id=741864157]

[node name="ParallaxBackground" type="ParallaxBackground" parent="."]

[node name="DeepLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.15, 0.15)

[node name="Background" type="ColorRect" parent="ParallaxBackground/DeepLayer"]
offset_left = -3000.0
offset_top = -2000.0
offset_right = 3000.0
offset_bottom = 2000.0
color = Color(0.02, 0.05, 0.1, 1)

[node name="MidLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.4, 0.4)

[node name="IceSilhouette1" type="ColorRect" parent="ParallaxBackground/MidLayer"]
offset_left = -600.0
offset_top = -300.0
offset_right = -450.0
offset_bottom = 200.0
color = Color(0.04, 0.08, 0.15, 0.6)

[node name="IceSilhouette2" type="ColorRect" parent="ParallaxBackground/MidLayer"]
offset_left = 300.0
offset_top = -200.0
offset_right = 500.0
offset_bottom = 350.0
color = Color(0.03, 0.07, 0.13, 0.5)

[node name="IceSilhouette3" type="ColorRect" parent="ParallaxBackground/MidLayer"]
offset_left = -100.0
offset_top = 250.0
offset_right = 150.0
offset_bottom = 500.0
color = Color(0.05, 0.09, 0.16, 0.4)

[node name="CaveWalls" type="TileMapLayer" parent="."]
material = SubResource("ShaderMaterial_edge")
tile_set = ExtResource("3_tileset")
tile_map_data = PackedByteArray({tile_data})

[node name="Decorations" type="Node2D" parent="."]

[node name="Stalactite1" type="Sprite2D" parent="Decorations"]
position = Vector2(-480, -330)
texture = ExtResource("8_stal1")

[node name="Stalactite2" type="Sprite2D" parent="Decorations"]
position = Vector2(320, -310)
texture = ExtResource("9_stal2")

[node name="Stalactite3" type="Sprite2D" parent="Decorations"]
position = Vector2(-100, -350)
scale = Vector2(-1, 1)
texture = ExtResource("8_stal1")

[node name="Stalactite4" type="Sprite2D" parent="Decorations"]
position = Vector2(650, -290)
texture = ExtResource("9_stal2")

[node name="Crystal1" type="Sprite2D" parent="Decorations"]
position = Vector2(-350, 180)
scale = Vector2(2, 2)
texture = ExtResource("10_crystal")

[node name="Crystal2" type="Sprite2D" parent="Decorations"]
position = Vector2(200, -100)
scale = Vector2(1.5, 1.5)
texture = ExtResource("10_crystal")

[node name="Crystal3" type="Sprite2D" parent="Decorations"]
position = Vector2(500, 400)
scale = Vector2(2.5, 2.5)
texture = ExtResource("10_crystal")

[node name="AmbientBubbles" type="CPUParticles2D" parent="."]
z_index = 1
amount = 25
lifetime = 5.0
texture = ExtResource("6_bubble")
emission_shape = 3
emission_rect_extents = Vector2(1600, 1200)
direction = Vector2(0, -1)
spread = 15.0
gravity = Vector2(0, -80)
initial_velocity_min = 20.0
initial_velocity_max = 50.0
angular_velocity_min = -45.0
angular_velocity_max = 45.0
scale_amount_min = 1.0
scale_amount_max = 2.5
color = Color(0.8, 0.9, 1.0, 0.35)

[node name="FloatingDebris" type="CPUParticles2D" parent="."]
z_index = 1
amount = 40
lifetime = 10.0
texture = ExtResource("7_debris")
emission_shape = 3
emission_rect_extents = Vector2(1600, 1200)
direction = Vector2(0.2, -0.3)
spread = 180.0
gravity = Vector2(0, -5)
initial_velocity_min = 3.0
initial_velocity_max = 12.0
scale_amount_min = 0.8
scale_amount_max = 2.0
scale_amount_curve = SubResource("Curve_debris_scale")
color = Color(0.75, 0.85, 0.95, 0.15)

[node name="BiolumLight1" type="PointLight2D" parent="."]
position = Vector2(-550, -150)
color = Color(0.2, 0.8, 0.9, 1)
energy = 0.4
texture = SubResource("GradientTexture2D_biolum")
texture_scale = 3.0

[node name="BiolumLight2" type="PointLight2D" parent="."]
position = Vector2(400, 100)
color = Color(0.3, 0.9, 0.5, 1)
energy = 0.35
texture = SubResource("GradientTexture2D_biolum")
texture_scale = 2.5

[node name="BiolumLight3" type="PointLight2D" parent="."]
position = Vector2(-200, 300)
color = Color(0.2, 0.7, 0.95, 1)
energy = 0.3
texture = SubResource("GradientTexture2D_biolum")
texture_scale = 2.0

[node name="BiolumLight4" type="PointLight2D" parent="."]
position = Vector2(700, -200)
color = Color(0.4, 0.85, 0.6, 1)
energy = 0.35
texture = SubResource("GradientTexture2D_biolum")
texture_scale = 2.8

[node name="Submarine" parent="." unique_id=482854008 instance=ExtResource("1_sub")]
position = Vector2(-320, -320)

[node name="Alien1" parent="." unique_id=2062702134 instance=ExtResource("2_alien")]
position = Vector2(300, 500)

[node name="WaterEffect" type="CanvasLayer" parent="."]
layer = 100

[node name="ColorRect" type="ColorRect" parent="WaterEffect"]
material = SubResource("ShaderMaterial_water")
script = ExtResource("5_effect")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
"""

    with open(OUTPUT, "w") as f:
        f.write(scene)

    print(f"Written underwater.tscn ({len(walls)} wall tiles)")
    print(f"Submarine at cell ~(-5, -5) = world (-320, -320)")
    print(f"Alien at world (300, 500)")


if __name__ == "__main__":
    main()
