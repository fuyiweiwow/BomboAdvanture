import pygame
import os
import sys

current_music = ""

# def play(name, volume):
#     global current_music
#     if current_music == name:
#         return
#     pygame.mixer.music.load("res/music/" + name)
#     pygame.mixer.music.set_volume(volume)
#     pygame.mixer.music.play(loops=-1, fade_ms=1000)
#     current_music = name

sound_cache = {}

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

def play(name, volume):
    global current_music
    if current_music == name:
        return
    
    if name not in sound_cache:
        sound_cache[name] = pygame.mixer.Sound(get_file("res/music/" + name))
    
    sound = sound_cache[name]
    sound.set_volume(volume)
    sound.play(loops=-1, fade_ms=1000)
    current_music = name