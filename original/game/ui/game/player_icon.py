import pygame
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

class PlayerIcon(pygame.sprite.Sprite):

    def __init__(self, name):
        self.image = pygame.image.load(get_file("res/img/ui/game/" + name + ".png")).convert_alpha()
        self.rect = self.image.get_rect()
        self.rect.y = 78

    def draw(self, screen: pygame.Surface):
        screen.blit(self.image, self.rect)
