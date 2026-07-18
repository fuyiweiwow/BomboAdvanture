import json
import pygame
import os
import sys

from game.frame.frame import Frame

MAGIC_FRAME_ROOT = "game/frame/magic/"
MAGIC_IMG_ROOT = "res/img/magic/"
magics = {}

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


def get_magic(name):
    if name not in magics.keys():
        magics[name] = load_magic(name)
    return magics[name]


def load_magic(name):
    a_magic = {}
    with open(get_file(MAGIC_FRAME_ROOT + '/' + name + ".json")) as f:
        magic_json = json.load(f)
    a_magic["STAND"] = list()
    size = len(magic_json["IMG"])
    for i in range(size):
        # print(name + " " + MAGIC_IMG_ROOT + '/' + magic_json["IMG"][i])
        img = pygame.image.load(get_file(MAGIC_IMG_ROOT + '/' + magic_json["IMG"][i])).convert_alpha()
        cx = magic_json["CX"][i]
        cy = magic_json["CY"][i]
        a_magic["STAND"].append(Frame(img, cx, cy))
    return a_magic
