import json
import pygame
import os
import sys

BOMB_FRAME_ROOT = "game/frame/bomb/"
BOMB_IMG_ROOT = "res/img/bomb/"
bombs = {}

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


def get_bomb(name):
    if name not in bombs.keys():
        bombs[name] = load_bomb(name)
    return bombs[name]


def load_bomb(name):
    a_bomb = {}
    with open(get_file(BOMB_FRAME_ROOT + name + ".json")) as f:
        bomb_json = json.load(f)
    a_bomb["INTERVAL"] = bomb_json["INTERVAL"]
    a_bomb["STAND"] = list()
    size = len(bomb_json["STAND"]["IMG"])
    for i in range(size):
        img = pygame.image.load(get_file(BOMB_IMG_ROOT + '/' + bomb_json["STAND"]["IMG"][i])).convert_alpha()
        cx = bomb_json["STAND"]["CX"][i]
        cy = bomb_json["STAND"]["CY"][i]
        a_bomb["STAND"].append(Frame(img, cx, cy))
    return a_bomb


class Frame:

    def __init__(self, image: pygame.Surface, cx, cy):
        self.image = image
        self.cx = cx
        self.cy = cy
