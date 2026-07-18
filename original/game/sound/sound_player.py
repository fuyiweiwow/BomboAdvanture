import pygame
from game.const import game as G
import os
import sys

pygame.mixer.init()
PATH = "res/sound"


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

def play(name):
    sound = pygame.mixer.Sound(get_file(PATH + '/' + name + ".ogg"))
    sound.set_volume(G.SOUND_VOLUME)
    sound.play()
