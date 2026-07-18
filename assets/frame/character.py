import pygame
import os
import sys
from game.algo import blender


CHARACTER_IMG_ROOT = "res/img/"
CHARACTER_ORIENTS = ("STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D", "LOSE")
CHARACTER_COMPONENTS = {
    "R": ("Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Face", "Hair", "Hair_m", "Eye", "Ear", "Mouth", "Cap", "Cap_m", "Fhadorn", "Npack", "Npack_m", "Fpack", "Thadorn"),
    "U": ("Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Face", "Eye", "Ear", "Mouth", "Hair", "Hair_m", "Cap", "Cap_m", "Fhadorn", "Npack", "Npack_m", "Fpack", "Thadorn"),
    "L": ("Thadorn", "Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Npack", "Npack_m", "Face", "Hair", "Hair_m", "Eye", "Ear", "Mouth", "Cap", "Cap_m", "Fhadorn", "Fpack"),
    "D": ("Fpack", "Npack", "Npack_m", "Body", "Body_m", "Foot", "Leg", "Leg_m", "Cloth", "Cloth_m", "Cladorn", "Face", "Hair", "Hair_m", "Eye", "Ear", "Mouth", "Cap", "Cap_m", "Fhadorn", "Thadorn")
}
CHARACTER_COMPONENTS_MASKED = ("Body_m", "Cloth_m", "Hair_m", "Leg_m", "Npack_m", "Cap_m")
DECORATION_CATEGORIES = ("Cap", "Hair", "Eye", "Ear", "Mouth", "Cladorn", "Fpack", "Npack", "Thadorn", "Footprint")
characters = {}

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


# 通过name和color获取body序列。
# name是一级键，取自body_json的NAME；color是二级键，取自color常量
def get_character(character_json, color, decorations: dict, is_ghost=False):
    name = character_json["NAME"] + "_ghost" if is_ghost else character_json["NAME"]
    if name not in characters.keys():
        characters[name] = dict()
    if color not in characters[name]:
        a_color = load_color(character_json, color, decorations, is_ghost)
        characters[name][color] = a_color
    return characters[name][color]


# 通过color常量和body_json创建body序列，用于生成get_body的二级键的值
def load_color(character_json, color, decorations: dict, is_ghost):
    a_color = {}
    # 遍历朝向
    for orient in CHARACTER_ORIENTS:
        if orient not in character_json.keys():
            # 如果character没有这个方向，则跳过不加载
            continue
        a_color[orient] = dict()
        a_color[orient]["Cx"] = character_json[orient]["Cx"]  # 获取每个朝向的x偏移
        a_color[orient]["Cy"] = character_json[orient]["Cy"]  # 获取每个朝向的y偏移
        # 遍历身体部件
        for component in CHARACTER_COMPONENTS["D"]:
            if component in character_json[orient].keys():
                a_color[orient][component] = list()
                type = component.lower()
                frames = character_json[orient][component]
                # 对于每一帧 加载图片
                size = len(character_json[orient][component]["IMG"])
                for i in range(size):
                    # print(CHARACTER_IMG_ROOT + type + '/' + frames["IMG"][i])
                    img = pygame.image.load(get_file(CHARACTER_IMG_ROOT + type + '/' + frames["IMG"][i])).convert_alpha()
                    if is_ghost:
                        img.fill((192, 192, 192), special_flags=pygame.BLEND_SUB)
                        pygame.surfarray.pixels_alpha(img)[...] = pygame.surfarray.pixels_alpha(img)[...] * 0.5
                    if component in CHARACTER_COMPONENTS_MASKED:
                        # 使用叠加的方式进行染色
                        img = blender.color_overlay(img, color, True)
                    cx = frames["CX"][i]
                    cy = frames["CY"][i]
                    a_color[orient][component].append(Frame(img, cx, cy))
        if orient == "LOSE":
            continue
        for component in DECORATION_CATEGORIES:
            if component in decorations.keys():
                # 删除已有的xxx和xxx_m
                if component in a_color[orient]:
                    del a_color[orient][component]
                if component + "_m" in a_color[orient]:
                    del a_color[orient][component + "_m"]
                if component == "Cladorn":
                    if "Cloth" in a_color[orient]:
                        del a_color[orient]["Cloth"]
                    if "Cloth_m" in a_color[orient]:
                        del a_color[orient]["Cloth_m"]
                # 读取新的decoration
                load_decoration_img(component, a_color, orient, decorations)

    return a_color


def load_decoration_img(category: str, a_color, orient, decorations: dict):
    a_color[orient][category] = list()
    frames = decorations[category][orient]
    # 对于每一帧 加载图片
    size = len(frames["IMG"])
    type = category.lower()
    for i in range(size):
        # print(CHARACTER_IMG_ROOT + type + '/' + frames["IMG"][i])
        img = pygame.image.load(CHARACTER_IMG_ROOT + type + '/' + frames["IMG"][i]).convert_alpha()
        cx = frames["CX"][i]
        cy = frames["CY"][i]
        a_color[orient][category].append(Frame(img, cx, cy))


class Frame:

    def __init__(self, image: pygame.Surface, cx, cy):
        self.image = image
        self.cx = cx
        self.cy = cy
