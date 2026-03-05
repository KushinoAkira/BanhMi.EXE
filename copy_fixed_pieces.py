import shutil
import os

brain_dir = r"C:\Users\h_u_n\.gemini\antigravity\brain\4e6fee2c-45ec-4c6a-adb6-457d0fad2b0a"
out_dir = r"c:\Users\h_u_n\.gemini\antigravity\scratch\banh-mi-exe\assets\textures\xiangqi"

files = {
    "xq_red_general_1772641009492.png": "red_general.png",
    "xq_red_advisor_1772641024971.png": "red_advisor.png",
    "xq_red_elephant_1772641039664.png": "red_elephant.png",
    "xq_red_horse_1772641057731.png": "red_horse.png",
    "xq_red_chariot_1772641071082.png": "red_chariot.png",
    "xq_red_cannon_1772641085136.png": "red_cannon.png",
    "xq_red_soldier_1772641104741.png": "red_soldier.png",
    "xq_black_general_1772641136618.png": "black_general.png",
    "xq_black_advisor_1772641157141.png": "black_advisor.png",
    "xq_black_elephant_1772641174310.png": "black_elephant.png",
    "xq_black_horse_1772641197151.png": "black_horse.png",
    "xq_black_chariot_1772641211224.png": "black_chariot.png",
    "xq_black_cannon_1772641222832.png": "black_cannon.png",
    "xq_black_soldier_1772641236812.png": "black_soldier.png",
}

for src_name, dst_name in files.items():
    src = os.path.join(brain_dir, src_name)
    dst = os.path.join(out_dir, dst_name)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"Copied {dst_name}")
    else:
        print(f"MISSING: {src}")
