import json
import os
import sys
from json import JSONDecodeError
import asyncio

import pygame

from game.const import window as W, color as C, game as G
from game.effect import effect
from game.frame import character, flame
from game.level.level import Level
from game.sprite.hero import Hero


class Control:

    def __init__(self):
        self.screen = None
        # 游戏配置
        self.cfg_json = None
        self.your_name = None  # 玩家名称
        self.map_set_json = None
        self.map_set_at = None  # 当前在map_set的第几关 从0开始
        self.music_volume = None  # 游戏音乐音量大小
        self.sound_volume = None  # 游戏音效音量大小
        self.frame_rate = None  # 游戏帧速率
        self.display_frame_rate = None  # 显示帧率
        self.grid_damage_duration = None  # 网格伤害持续时间
        self.display_flags = 0  # 画面显示特征

        # 游戏值
        self.me = None  # 玩家Hero对象
        self.current_level = None  # 当前关卡Level对象
        self.orientations = dict()  # 方向键与字符串的映射
        self.walking_stack = []  # 方向键栈
        self.bomb_old = 0  # 连按空格键标志
        self.f6_old = False  # 连按F6键标志
        self.reset_old = False  # 连按reset键标志
        self.skills_old = [False, False, False, False, False, False, False]  # 连按技能键标志
        self.key2idx = dict()  # 数字键与技能下标的映射
        self.cfg_space = None  # 用户自定义空格
        self.cfg_f6 = None  # 用户自定义f6
        self.cfg_reset = None  # 用户自定义重启0
        self.text_font = None
        self.description_shown = False

        # 初始化pygame
        pygame.init()
        pygame.display.set_caption(W.WINDOW_CAPTION)
        self.init_game()
        self.preload()
        self.proceed_game()

    def get_file(self, file_name):
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

    def init_game(self):
        # 游戏初始化 读取配置文件
        file_path = self.get_file("config.json")
        
        try:
            with open(file_path, encoding="utf-8") as f:
                self.cfg_json = json.load(f)
        except JSONDecodeError:
            with open("config.json", encoding="utf-8_sig") as f:
                self.cfg_json = json.load(f)
        self.map_set_at = -1
        G.DISPLAY_NPC_NAME_CARD = self.cfg_json["display_npc_name_card"]
        G.DISPLAY_NPC_BLOOD = self.cfg_json["display_npc_blood"]
        self.music_volume = self.cfg_json["music_volume"]
        self.frame_rate = int(self.cfg_json["frame_rate"])
        # print("FRRRR:", self.frame_rate)
        G.SOUND_VOLUME = self.cfg_json["sound_volume"]
        G.DISPLAY_FRAME_RATE = self.cfg_json["display_frame_rate"]
        G.FIRST_FRAME_SHORTEN_RATE = int(self.cfg_json["first_frame_shorten_rate"])
        G.LOW_CONFIG_MODE = bool(self.cfg_json["low_config_mode"])
        self.grid_damage_duration = int(self.cfg_json["grid_damage_duration"])
        self.your_name = self.cfg_json["your_name"]
        self.init_keys(self.cfg_json["keys"])
        self.text_font = pygame.font.Font(self.get_file("res/font/simsun.ttc"), 16)
        if not self.cfg_json["frame_screen"]:
            self.display_flags = pygame.NOFRAME
        if self.cfg_json["full_screen"]:
            self.display_flags = pygame.FULLSCREEN | pygame.HWSURFACE | pygame.DOUBLEBUF
        try:
            with open(self.get_file("game/map_set/" + self.cfg_json["map_set"] + ".json"), encoding="utf-8") as f:
                self.map_set_json = json.load(f)
        except JSONDecodeError:
            with open("game/map_set/" + self.cfg_json["map_set"] + ".json", encoding="utf-8_sig") as f:
                self.map_set_json = json.load(f)

        self.screen = pygame.display.set_mode(W.WINDOW_SIZE, flags=self.display_flags)
        pygame.display.set_icon(pygame.image.load(self.get_file("res/img/ui/icon.png")).convert_alpha())

    def init_keys(self, keys_root):
        # 加载自定义按键
        self.orientations[keys_root["RIGHT"]] = "R"
        self.orientations[keys_root["UP"]] = "U"
        self.orientations[keys_root["LEFT"]] = "L"
        self.orientations[keys_root["DOWN"]] = "D"
        self.key2idx[keys_root["1"]] = 0
        self.key2idx[keys_root["2"]] = 1
        self.key2idx[keys_root["3"]] = 2
        self.key2idx[keys_root["4"]] = 3
        self.key2idx[keys_root["5"]] = 4
        self.key2idx[keys_root["6"]] = 5
        self.key2idx[keys_root["7"]] = 6
        self.cfg_space = keys_root["SPACE"]
        self.cfg_f6 = keys_root["F6"]
        self.cfg_reset = keys_root["RESET"]

    def preload(self):
        if not self.cfg_json["allow_preload"]:
            return
        ch_root = self.get_file("game/frame/character/")
        for f in os.listdir(ch_root):
            with open(ch_root + f) as tf:
                jf = json.load(tf)
                character.get_character(jf, C.CHARACTER_WHITE, dict())
        eff_root = self.get_file("game/effect/effect")
        for e in os.listdir(eff_root):
            name = e.split('.')[0]
            effect.get_effect(name)
        for orientation in flame.ORIENTATIONS:
            flame.get_flame(orientation)

    def proceed_game(self, is_reset=False):
        # 进入下一个关卡
        self.map_set_at += 1
        map_name = self.map_set_json["maps"][self.map_set_at]
        hero_name = self.cfg_json["your_hero"]
        character_color = self.cfg_json["your_character_color"]
        self.set_level(self.your_name, map_name, hero_name, character_color, is_reset)

    def set_level(self, your_name, map_name, hero_name, character_color, is_reset=False):
        # 改变当前关卡
        character_colors = {
            "Red": C.CHARACTER_RED, "Blue": C.CHARACTER_BLUE, "Yellow": C.CHARACTER_YELLOW, "Green": C.CHARACTER_GREEN,
            "Orange": C.CHARACTER_ORANGE, "Pink": C.CHARACTER_PINK, "Purple": C.CHARACTER_PURPLE,
            "Black": C.CHARACTER_BLACK
        }
        character_color = character_colors[character_color]
        # 保留我的技能剩余数
        me = Hero(hero_name, (0, 0), character_color)
        if self.me is not None and not is_reset:
            me.skill_remains = self.me.skill_remains
        self.me = me
        # 设置新关卡
        self.current_level = Level(your_name, map_name, self.me, self.music_volume, self.grid_damage_duration)

    async def update(self):
        # 事件处理
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.display.quit()
                    pygame.quit()
                    sys.exit()

            # 更新关卡
            if self.current_level is not None:
                if self.current_level.finish_flag:
                    # 如果过关
                    self.proceed_game()
                else:
                    # 正常刷新
                    if not self.description_shown:
                        self.current_level.update(self.screen)

            # 键盘事件
            self.key_pressed()

            # 刷新显示
            pygame.display.flip()
            await asyncio.sleep(0)

            # 设置帧率
            # pygame.time.Clock().tick(self.frame_rate)

    def key_pressed(self):
        # 键盘事件检测
        keys = pygame.key.get_pressed()
        self.player_bomb(keys)
        self.player_move(keys)
        self.player_f6(keys)
        self.player_reset(keys)
        self.player_skill(keys)

    def player_move(self, keys):
        # 玩家移动
        # 取放按键栈
        for enum in self.orientations.keys():
            if keys[enum]:
                if enum not in self.walking_stack:
                    self.walking_stack.insert(0, enum)
            else:
                if enum in self.walking_stack:
                    self.walking_stack.remove(enum)
        # 取栈顶元素first
        first = 0
        if len(self.walking_stack) > 0:
            first = self.walking_stack[0]
        # 判断first是哪个方向
        if first == 0:
            self.me.set_motion()
        else:
            self.me.set_motion(self.orientations[first])

    def player_bomb(self, keys):
        if keys[self.cfg_space]:
            if self.bomb_old == 0:
                self.me.set_bomb()
            self.bomb_old += 1
        else:
            self.bomb_old = 0

    def player_f6(self, keys):
        if keys[self.cfg_f6]:
            if self.f6_old is True:
                return
            # 按下F6键
            G.DISPLAY_NPC_NAME_CARD = not G.DISPLAY_NPC_NAME_CARD
            self.f6_old = True
        else:
            self.f6_old = False

    def player_reset(self, keys):
        if keys[self.cfg_reset]:
            if self.reset_old is True:
                return
            self.init_game()
            self.proceed_game(is_reset=True)
            self.reset_old = True
        else:
            self.reset_old = False

    def player_skill(self, keys):
        for k in self.key2idx.keys():
            idx = self.key2idx[k]  # 常量转索引
            if keys[k]:
                if self.skills_old[idx]:
                    return
                self.me.use_skill(idx)
                self.skills_old[idx] = True
            else:
                self.skills_old[idx] = False
