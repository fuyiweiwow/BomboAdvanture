import json
import pygame
import os
import sys


OBSTACLE_FRAME_ROOT = "game/frame/obstacle/"
OBSTACLE_IMG_ROOT = "res/img/mapElem/"
obstacles = {}

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

def get_obstacle(type, name):
    if type not in obstacles.keys():
        obstacles[type] = dict()
    if name not in obstacles[type].keys():
        obstacles[type][name] = load_obstacle(type, name)
    return obstacles[type][name]


def load_obstacle(type, name):

    an_obstacle = {}
    # print(OBSTACLE_FRAME_ROOT + type + '/' + name + ".json")
    with open(get_file(OBSTACLE_FRAME_ROOT + type + '/' + name + ".json")) as f:
        obstacle_json = json.load(f)
    an_obstacle["WIDTH"] = obstacle_json["WIDTH"]
    an_obstacle["HEIGHT"] = obstacle_json["HEIGHT"]
    an_obstacle["BLOCK"] = an_obstacle["BLOCK_FLAME"] = obstacle_json["BLOCK"]
    an_obstacle["BREAKABLE"] = obstacle_json["BREAKABLE"]
    an_obstacle["CAN_HIDE"] = obstacle_json["CAN_HIDE"]
    if "BLOCK_FLAME" in obstacle_json.keys():
        an_obstacle["BLOCK_FLAME"] = obstacle_json["BLOCK_FLAME"]
    if "SLIDE" in obstacle_json.keys():
        an_obstacle["SLIDE"] = obstacle_json["SLIDE"]
    if "BACKGROUND" in obstacle_json.keys():
        an_obstacle["BACKGROUND"] = bool(obstacle_json["BACKGROUND"])
    if "CAN_PUSH" in obstacle_json.keys():
        an_obstacle["CAN_PUSH"] = bool(obstacle_json["CAN_PUSH"])
    if "PUSH_TIME" in obstacle_json.keys():
        an_obstacle["PUSH_TIME"] = obstacle_json["PUSH_TIME"]
    if "CONTACT" in obstacle_json.keys():
        an_obstacle["CONTACT"] = obstacle_json["CONTACT"]
    an_obstacle["INTERVAL"] = obstacle_json["INTERVAL"]

    append_obstacle(obstacle_json, an_obstacle, "STAND")
    append_obstacle(obstacle_json, an_obstacle, "PUSH")
    append_obstacle(obstacle_json, an_obstacle, "DIE")
    append_obstacle(obstacle_json, an_obstacle, "TRIGGER")

    return an_obstacle


def append_obstacle(obstacle_json, an_obstacle, state: str):

    if state in obstacle_json:
        an_obstacle[state] = list()
        frames = obstacle_json[state]
        size = len(frames["IMG"])
        for i in range(size):
            # print(OBSTACLE_IMG_ROOT + obstacle_json["TYPE"] + '/' + frames["IMG"][i])
            img = pygame.image.load(get_file(OBSTACLE_IMG_ROOT + obstacle_json["TYPE"] + '/' + frames["IMG"][i])).convert_alpha()
            cx = frames["CX"][i]
            cy = frames["CY"][i]
            an_obstacle[state].append(Frame(img, cx, cy))


class Frame:

    def __init__(self, image: pygame.Surface, cx, cy):
        self.image = image
        self.cx = cx
        self.cy = cy
