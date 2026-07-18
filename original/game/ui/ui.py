import pygame
from enum import Enum
import os
import sys


UI_IMG_ROOT = "res/img/ui/"
ui_imgs = {}


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


def get_ui(type, name):

    if type not in ui_imgs.keys():
        ui_imgs[type] = dict()
    if name not in ui_imgs[type].keys():
        img = pygame.image.load(get_file(UI_IMG_ROOT + '/' + type + '/' + name + ".png")).convert_alpha()
        ui_imgs[type][name] = img
    return ui_imgs[type][name]


class UIInstance(pygame.sprite.Sprite):

    def __init__(self, type, name):
        self.sheet = None  # 与image等大的透明层
        self.redraw_trigger = True  # 当前帧是否需要draw当前sheet 避免重复draw造成负担
        self.load(type, name)

    def load(self, type, name):
        self.image = get_ui(type, name)
        self.rect = self.image.get_rect()
        self.sheet = pygame.Surface(self.rect.size, pygame.SRCALPHA, 32)

    def update(self):
        pass

    def draw(self, screen: pygame.Surface):
        if self.redraw_trigger:
            screen.blit(self.image, self.rect)
            screen.blit(self.sheet, self.rect)
            self.redraw_trigger = False


class UIType(Enum):
    BG = 0,
    BTN = 1


class BtnState(Enum):
    PRESSED = 0,
    FORBIDDEN = 1,
    HOVER = 2,
    NORMAL = 3
