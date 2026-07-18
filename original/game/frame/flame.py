import json
import pygame
import os
import sys

FLAME_JSON_ROOT = "game/frame/flame/"
FLAME_JSON_FILE = "flame.json"
FLAME_IMG_ROOT = "res/img/flame/"
ORIENTATIONS = ("FLAME_C", "FLAME_R", "FLAME_U", "FLAME_L", "FLAME_D")
flames = {}
flame_seq = None

def get_file(file_name):
    if getattr(sys, "frozen", False):
        # 打包后：sys.executable是exe完整路径
        exe_path = os.path.abspath(sys.executable)
        exe_dir = os.path.dirname(exe_path)
    else:
        # 开发环境：使用py文件路径
        py_path = os.path.abspath(__file__)
        exe_dir = os.path.dirname(py_path)

    file_path = os.path.join(exe_dir, file_name)
    return file_path

with open(get_file(FLAME_JSON_ROOT + '/' + FLAME_JSON_FILE)) as f:
    j = json.load(f)
    flame_seq = j["FLAME_SEQ"]


def get_flame(orientation):

    if orientation not in flames.keys():
        flames[orientation] = list()
        with open(get_file(FLAME_JSON_ROOT + '/' + FLAME_JSON_FILE)) as f:
            flame_json = json.load(f)
        root = flame_json[orientation]
        size = len(root["IMG"])
        for i in range(size):
            img = pygame.image.load(get_file(FLAME_IMG_ROOT + '/' + root["IMG"][i])).convert_alpha()
            cx = root["CX"][i]
            cy = root["CY"][i]
            a_flame = Frame(img, cx, cy)
            flames[orientation].append(a_flame)

    return flames[orientation]


class Frame:

    def __init__(self, image: pygame.Surface, cx, cy):
        self.image = image
        self.cx = cx
        self.cy = cy
