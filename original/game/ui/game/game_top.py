import pygame
from game.ui.ui import UIInstance
import os
import sys


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


class GameTop(UIInstance):

    def __init__(self):
        super().__init__("game", "gameTop")
        self.font = pygame.font.Font(get_file("res/font/simsun.ttc"), 16)
        self.rend = self.font.render("v20230428", True, (0, 196, 255))

    def draw(self, screen: pygame.Surface):
        super().draw(screen)
        screen.blit(self.rend, (0, 0))
