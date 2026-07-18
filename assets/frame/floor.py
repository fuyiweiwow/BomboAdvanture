import pygame
import os
import sys


FLOOR_IMG_ROOT = "res/img/mapElem/"
floors = {}

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

def get_floor(type, name):
    if type not in floors.keys():
        floors[type] = dict()
    if name not in floors[type].keys():
        # print(FLOOR_IMG_ROOT + type + '/' + name + ".png")
        img = pygame.image.load(get_file(FLOOR_IMG_ROOT + type + '/' + name + ".png")).convert()
        floors[type][name] = img
    return floors[type][name]
