import json
import os
import sys
import pygame

from game.const import game as G
from game.algo import blender
from game.frame import magic
from game.frame.frame import Frame

EFFECT_ROOT = "game/effect/effect/"
effects = {}

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

def get_effect(name):

    if name not in effects.keys():
        effects[name] = load_effect(name)
    return effects[name]


def load_effect(name):

    an_effect = {}
    # print(EFFECT_ROOT + '/' + name + ".json")
    with open(get_file(EFFECT_ROOT + '/' + name + ".json")) as file:
        effect_json = json.load(file)
    magic_len = len(effect_json["MAGICS"])
    an_effect["magics"] = list()
    for i in range(magic_len):
        magic_root = effect_json["MAGICS"][i]
        magic_name = magic_root["NAME"]
        a_magic = magic.load_magic(magic_name)
        a_magic_instance = dict()
        a_magic_instance["cx"] = magic_root["CX"]
        a_magic_instance["cy"] = magic_root["CY"]
        a_magic_instance["repeat"] = magic_root["REPEAT"]
        a_magic_instance["interval"] = magic_root["INTERVAL"]
        a_magic_instance["special_flag"] = magic_root["SPECIAL_FLAG"]
        if G.LOW_CONFIG_MODE and a_magic_instance["special_flag"] == -2:
            a_magic_instance["special_flag"] = 0
        if "MAX_TIME" in magic_root.keys():
            a_magic_instance["max_time"] = magic_root["MAX_TIME"]
        a_magic_instance["frames"] = list()
        for j in range(len(a_magic["STAND"])):
            f: Frame = a_magic["STAND"][j].duplicate()
            if "COLOR_ADD" in magic_root.keys():
                f.image.fill(magic_root["COLOR_ADD"], special_flags=pygame.BLEND_ADD)
            if "COLOR_SUB" in magic_root.keys():
                f.image.fill(magic_root["COLOR_SUB"], special_flags=pygame.BLEND_SUB)
            if "COLOR" in magic_root.keys():
                f.image = blender.color_overlay(f.image, magic_root["COLOR"], True)
            if "ALPHA" in magic_root.keys():
                pygame.surfarray.pixels_alpha(f.image)[...] = pygame.surfarray.array_alpha(f.image)[...] * (magic_root["ALPHA"][j] / 255.0)
            if "SCALE" in magic_root.keys():
                f.cx += (1 - magic_root["SCALE"][j][0]) * f.image.get_size()[0] / 2
                f.cy += (1 - magic_root["SCALE"][j][1]) * f.image.get_size()[1] / 2
                f.image = pygame.transform.smoothscale_by(f.image, (magic_root["SCALE"][j][0], magic_root["SCALE"][j][1]))
            f.get_alpha()
            a_magic_instance["frames"].append(f)
        an_effect["magics"].append(a_magic_instance)

    return an_effect
