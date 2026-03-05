import os
import sys

tscn_path = r"c:\Users\h_u_n\.gemini\antigravity\scratch\banh-mi-exe\scenes\minigames\tetris_minigame_cs.tscn"

with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add ext_resource for the control script
script_res = '[ext_resource type="Script" path="res://scripts/minigames/tetris_cs/mobile_controls.gd" id="2_mobile"]\n'
# Find the last ext_resource
lines = content.split('\n')
ext_idx = -1
for i, line in enumerate(lines):
    if line.startswith('[ext_resource'):
        ext_idx = i
if ext_idx != -1:
    lines.insert(ext_idx + 1, script_res)
else:
    # insert after gd_scene
    lines.insert(1, script_res)

# 2. Modify Window offsets to push it up
for i, line in enumerate(lines):
    if line == '[node name="Window" type="PanelContainer" parent="."]':
        for j in range(i+1, i+20):
            if lines[j].startswith("offset_top ="):
                lines[j] = "offset_top = -540.0"
            elif lines[j].startswith("offset_bottom ="):
                lines[j] = "offset_bottom = 140.0"
        break

# 3. Append MobileControls node format
new_nodes = """
[node name="MobileControls" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -450.0
offset_bottom = -50.0
grow_horizontal = 2
grow_vertical = 0
theme_override_constants/separation = 20
script = ExtResource("2_mobile")

[node name="Row1" type="HBoxContainer" parent="MobileControls"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 20
alignment = 1

[node name="BtnHold" type="Button" parent="MobileControls/Row1"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 32
text = "HOLD"

[node name="Spacer" type="Control" parent="MobileControls/Row1"]
custom_minimum_size = Vector2(80, 0)
layout_mode = 2

[node name="BtnUp" type="Button" parent="MobileControls/Row1"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 48
text = "🔃"

[node name="Spacer2" type="Control" parent="MobileControls/Row1"]
custom_minimum_size = Vector2(80, 0)
layout_mode = 2

[node name="BtnHardDrop" type="Button" parent="MobileControls/Row1"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 48
text = "⏬"

[node name="Row2" type="HBoxContainer" parent="MobileControls"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 20
alignment = 1

[node name="BtnLeft" type="Button" parent="MobileControls/Row2"]
custom_minimum_size = Vector2(120, 120)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 48
text = "◀️"

[node name="BtnDown" type="Button" parent="MobileControls/Row2"]
custom_minimum_size = Vector2(120, 120)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 48
text = "🔽"

[node name="BtnRight" type="Button" parent="MobileControls/Row2"]
custom_minimum_size = Vector2(120, 120)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 48
text = "▶️"
"""

content = '\n'.join(lines) + new_nodes

with open(tscn_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Modified tetris tscn successfully.")
