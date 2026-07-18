import json
import math

import numpy as np
import pygame

from game.const import game as G
from game.frame import floor
from game.frame import obstacle
from game.music import music_loader
from game.sprite import obstacle_instance as oi
from game.sprite.flame_instance import FlameState as FS
from game.sprite.hero import Hero
from game.sprite.item_instance import ItemState as IS
from game.sprite.bomb_instance import BombInstance
from game.effect.effect_instance import ReadyGo, DistrictAlarm
from game.sprite.npc import Npc
from game.ui.game.blood_bar import BloodBar
from game.ui.game.dlg_pveFunc import DlgPveFunc
from game.ui.game.game_top import GameTop
from game.ui.game.misc_510 import Misc510
from game.ui.game.player_icon import PlayerIcon
from game.ui.game.score_board import ScoreBoard
from game.ui.game.status_bar import StatusBar
import os
import sys

current_level = None


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

def get_y(elem):
    return elem.get_y()


class Level:

    def __init__(self, your_name: str, map_name: str, me: Hero, music_volume, accumulation_time):

        global current_level
        current_level = self
        self.times_num = 0  # 秒计数器，每秒累加
        self.frames_num = 0  # 帧计数器，每秒清空
        self.frame_rate_text_font = pygame.font.Font(get_file("res/font/century.ttf"), 14)
        self.me = me
        self.your_name = your_name
        self.map_name = map_name
        self.map_json = None
        self.map_x = None  # 关卡横向格子数
        self.map_y = None  # 关卡纵向格子数
        self.map_x_pos = None  # 关卡最大x坐标
        self.map_y_pos = None  # 关卡最大y坐标
        self.map_grids = None  # 关卡全部的点坐标集合
        self.scroll_x_pos = None  # 卷轴滚动x像素
        self.scroll_y_pos = None  # 卷轴滚动y像素
        self.scroll_x_pos_max = None  # 卷轴最大滚动x像素
        self.scroll_y_pos_max = None  # 卷轴最大滚动y像素
        self.map_title = None  # 关卡中文名称
        self.map_time = 0  # 关卡总时长
        self.map_init_time = None  # 关卡加载时刻
        self.map_remaining_time = None  # 关卡剩余时间
        self.map_music = None  # 关卡背景音乐
        self.map_music_volume = music_volume  # 关卡背景音乐音量大小
        self.finish_at = None  # 地图过关点(x, y)

        self.current_time = pygame.time.get_ticks()
        self.floor_image = None  # 游戏主区域的地板背景
        self.flame_instances = None  # FlameInstance对象列表
        self.item_instances = None  # (x, y) --> ItemInstance对象
        self.obstacle_instances = None  # (x, y) --> ObstacleInstance对象
        self.obstacle_instances_update = None  # 屏幕范围内的ObstacleInstance对象列表
        self.obstacle_instances_need_to_update = True  # 需要更新列表
        self.bomb_instances = None  # BombInstance对象列表
        self.ui_instances_bot = None  # 位于main_area下的UIInstance对象列表
        self.ui_instances_top = None  # 位于main_area上的UIInstance对象列![](C:/Users/dell/AppData/Local/Temp/previewfile_2896918733.gif)表
        self.block = None  # 三维NumPy对象，阻挡玩家
        self.block_flame = None  # 三维NumPy对象，阻挡糖跑
        self.slide_orientation = dict()  # (x, y) --> (m, n) m网格传送带方向 0无 1右 2上 3左 4下 n速度
        self.grid_damage_blood = dict()  # 网格伤害血量
        self.grid_damage_time = dict()  # 网格伤害时刻 只有糖泡爆炸时才会增加
        self.grid_damage_orientations = dict()  # 网格伤害方向
        self.grid_damage_frame = False  # 用于判断糖泡伤害瞬间与玩家位置是否重合 只有爆炸帧才是True
        self.accumulation_time = accumulation_time  # 网格伤害延迟时间
        self.main_area = None  # 游戏主区域
        self.main_area_offset = None  # 游戏主区域相对左上角的偏移
        self.skill_instances = list()  # 交予level托管的skill_instances，例如陷阱，不随npc死亡而消失
        self.effects_behind = list()  # 关卡底层技能特效
        self.effects_front = list()  # 关卡顶层技能特效
        self.effects_screen = list()  # 屏幕级的技能特效 不随卷轴移动
        self.left_black = None  # 屏幕右侧黑条

        self.grid_bomb_time_at = dict()  # 糖泡伤害时刻

        self.blood_bar = None
        self.status_bar = None
        self.score_board = None
        self.npcs = list()  # 存活npc列表
        self.ghosts = list()  # 存活僵尸列表
        self.recal_npc_paths = True  # 重新计算Npc路径的标志位 仅当玩家进入区域、糖泡施放与爆炸、玩家网格位置发生变化、障碍被摧毁时置为True
        self.recal_ghost_paths = True  # 重新计算Ghost路径的标志位 仅当玩家移动
        self.display_name_card = False  # 显示npc姓名牌
        self.display_npc_blood = False  # 显示npc姓名牌
        self.district_idx = 0  # 当前区域 从1开始
        self.district_square = None  # 当前区域 左上右下点像素坐标
        self.district_square_grid = None  # 当前区域 左上右下点坐标
        self.district_alarming = False  # 当前正在显示警戒
        self.district_all_finished = False  # 已完成全部区域的标志
        self.finish_flag = False  # 当前map结束的标志位

        self.load_map_json()  # 加载地图
        self.load_ui()  # 加载ui界面
        self.load_floor()  # 加载地板
        self.load_obstacle()  # 加载障碍
        self.load_music()  # 加载音乐

        ReadyGo(self.effects_screen)

    def load_map_json(self):
        # 加载关卡json文件
        with open(get_file("game/map/" + self.map_name + ".json")) as map_file:
            map_json = json.load(map_file)
            self.map_json = map_json
            self.me.set_xy(map_json["basic"]["begin"][0], map_json["basic"]["begin"][1])
            # 地图大小-像素
            self.map_x = int(map_json["basic"]["width"])
            self.map_y = int(map_json["basic"]["height"])
            self.map_x_pos = self.map_x * G.GAME_SQUARE - 1
            self.map_y_pos = self.map_y * G.GAME_SQUARE - 1
            self.map_grids = set()
            for x in range(self.map_x):
                for y in range(self.map_y):
                    self.map_grids.add((x, y))
            self.scroll_x_pos = map_json["basic"]["scroll"][0] * G.GAME_SQUARE
            self.scroll_y_pos = map_json["basic"]["scroll"][1] * G.GAME_SQUARE
            self.scroll_x_pos_max = max(0, self.map_x_pos - G.MAIN_AREA_X * G.GAME_SQUARE)
            self.scroll_y_pos_max = max(0, self.map_y_pos - G.MAIN_AREA_Y * G.GAME_SQUARE)
            self.map_init_time = pygame.time.get_ticks()
            self.map_music = map_json["basic"]["music"]
            self.flame_instances = list()
            self.item_instances = dict()
            self.obstacle_instances = dict()
            self.obstacle_instances_update = list()
            self.bomb_instances = list()
            self.ui_instances_bot = list()
            self.ui_instances_top = list()
            self.block = np.zeros((2, self.map_x + 1, self.map_y + 1), dtype=np.int64)
            self.block_flame = np.zeros((2, self.map_x + 1, self.map_y + 1), dtype=np.int64)
            # 生成网格伤害二元组映射
            for x in range(self.map_x):
                for y in range(self.map_y):
                    self.grid_damage_blood[(x, y)] = 0
                    self.grid_damage_time[(x, y)] = 0
                    self.grid_damage_orientations[(x, y)] = set()
                    self.grid_bomb_time_at[(x, y)] = 0
            self.district_square_grid = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
            self.district_square = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
            if "finish" in self.map_json["basic"].keys():
                self.finish_at = (self.map_json["basic"]["finish"][0], self.map_json["basic"]["finish"][1])
            self.main_area = pygame.Surface((self.map_x_pos, self.map_y_pos))
            self.left_black = pygame.Surface((1, 600))

    def load_ui(self):
        self.ui_instances_bot.append(GameTop())
        self.status_bar = StatusBar()
        self.status_bar.set_prop_imgs(self.me)
        if self.map_x < 16:
            self.score_board = ScoreBoard()
            self.score_board.set_time(300)
            self.ui_instances_bot.append(self.score_board)
        else:
            self.ui_instances_top.append(DlgPveFunc())
        self.ui_instances_top.append(self.status_bar)
        self.ui_instances_top.append(Misc510())
        self.ui_instances_top.append(PlayerIcon(self.me.icon_img))
        self.blood_bar = BloodBar(self.me)
        self.blood_bar.set_name(self.your_name)
        self.ui_instances_top.append(self.blood_bar)

    def load_floor(self):
        # 加载地板floor
        self.floor_image = pygame.Surface((self.map_x_pos, self.map_y_pos), flags=pygame.HWSURFACE)
        # 块区域加载
        for f in self.map_json["floors"]:
            for square in f["squares"]:
                for x in range(square["x1"], square["x2"] + 1):
                    for y in range(square["y1"], square["y2"] + 1):
                        img = floor.get_floor(f["type"], f["name"])
                        self.floor_image.blit(img, (x * G.GAME_SQUARE, y * G.GAME_SQUARE))
        # 单个加载
        for f in self.map_json["floor"]:
            img = floor.get_floor(f["type"], f["name"])
            for point in f["points"]:
                self.floor_image.blit(img, (point["x"] * G.GAME_SQUARE, point["y"] * G.GAME_SQUARE))

    def load_obstacle(self):
        # 加载障碍obstacle_instance
        # 块区域加载
        for o in self.map_json["obstacles"]:
            obs = obstacle.get_obstacle(o["type"], o["name"])
            for square in o["squares"]:
                for x in range(square["x1"], square["x2"] + 1):
                    for y in range(square["y1"], square["y2"] + 1):
                        oi.ObstacleInstance(x, y, self.obstacle_instances, obs)

        # 单个加载
        for o in self.map_json["obstacle"]:
            obs = obstacle.get_obstacle(o["type"], o["name"])
            for point in o["points"]:
                oi.ObstacleInstance(point["x"], point["y"], self.obstacle_instances, obs)

    def load_music(self):
        music_loader.play(self.map_music, self.map_music_volume)

    def load_district_and_enemies(self):
        if len(self.npcs) > 0:  # npc还没有被杀光
            return
        self.me.district_locked = False  # 解除玩家区域锁
        if self.district_idx >= len(self.map_json["districts"]):  # 已完成最后一个区域
            self.district_square = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
            self.district_square_grid = {"x1": 0, "x2": 0, "y1": 0, "y2": 0}
            self.district_all_finished = True
            return
        self.district_idx += 1
        a_district = self.map_json["districts"][self.district_idx - 1]
        self.district_square = a_district["square"]
        self.district_square_grid["x1"] = self.district_square["x1"]
        self.district_square_grid["x2"] = self.district_square["x2"]
        self.district_square_grid["y1"] = self.district_square["y1"]
        self.district_square_grid["y2"] = self.district_square["y2"]
        # 将district_square的四个点转化为像素坐标
        self.district_square["x1"] = self.district_square["x1"] * G.GAME_SQUARE + G.HALF_GAME_SQUARE
        self.district_square["x2"] = self.district_square["x2"] * G.GAME_SQUARE + G.HALF_GAME_SQUARE
        self.district_square["y1"] = self.district_square["y1"] * G.GAME_SQUARE + G.HALF_GAME_SQUARE
        self.district_square["y2"] = self.district_square["y2"] * G.GAME_SQUARE + G.HALF_GAME_SQUARE
        for g in self.ghosts:
            # 加载新区域时删除旧区域的幽灵，以及新加载出来的幽灵
            if g.time == 0:
                self.ghosts.remove(g)
        for n in a_district["npcs"]:
            # 载入新区域的npc
            self.npcs.append(Npc(n["name"], (n["x"], n["y"])))

    def update(self, screen: pygame.Surface):

        # a = pygame.time.get_ticks()
        self.current_time = pygame.time.get_ticks()

        # 刷新帧率
        self.display_frame_rate(self.current_time, screen)

        # 刷新剩余时间
        if self.score_board is not None:
            map_remaining_time = math.ceil(
                (self.map_time * 1000 - self.current_time + self.map_init_time) // 1000) + 1
            self.score_board.set_time(map_remaining_time)

        # 刷新区域
        if self.current_time - self.map_init_time > 3000:
            self.load_district_and_enemies()

        # 恢复帧爆炸位
        self.grid_damage_frame -= 1

        # 刷新糖泡
        for b in self.bomb_instances:
            b.update()

        # 刷新npc
        for n in self.npcs:
            if n.remain_blood <= 0:
                self.npcs.remove(n)
            else:
                n.update()
        self.recal_npc_paths = False

        # 刷新ghost
        for g in self.ghosts:
            if g.remain_time <= 0:
                self.ghosts.remove(g)
            else:
                g.update()
        self.recal_ghost_paths = False

        # 刷新人物
        self.me.update()

        # 检测过关
        self.pass_map()

        # 刷新糖浆
        for f in self.flame_instances:
            if f.state == FS.DEAD:
                self.flame_instances.remove(f)
            else:
                f.update()

        # 刷新item
        for key in list(self.item_instances.keys()):
            i = self.item_instances[key]
            if i.state == IS.DEAD:
                self.item_instances.pop(key)
            else:
                i.update()

        # 刷新障碍
        if self.obstacle_instances_need_to_update:
            self.update_obstacles_update_list()
        for o in self.obstacle_instances_update:
            o.update()

        # 刷新技能
        for s in self.skill_instances:
            s.update()

        # 刷新特效
        for e in self.effects_behind:
            e.update()
        for e in self.effects_front:
            e.update()
        for e in self.effects_screen:
            e.update()

        # 刷新ui
        for u in self.ui_instances_top:
            u.update()
        for u in self.ui_instances_bot:
            u.update()

        # 显示地板
        self.main_area.blit(
            self.floor_image,
            (self.scroll_x_pos, self.scroll_y_pos),
            (self.scroll_x_pos, self.scroll_y_pos, G.MAIN_AREA_X_POS, G.MAIN_AREA_Y_POS)
        )

        # 显示底层特效
        for e in self.effects_behind:
            e.draw(self.main_area)

        # 显示人物和障碍
        draw_seq = [self.me] + \
                   self.npcs + \
                   self.ghosts + \
                   self.bomb_instances + \
                   self.obstacle_instances_update + \
                   self.flame_instances + \
                   list(self.item_instances.values())
        draw_seq.sort(key=get_y)

        for d in draw_seq:
            d.draw(self.main_area)

        # 显示顶层特效
        for e in self.effects_front:
            e.draw(self.main_area)

        # 显示下ui
        for u in self.ui_instances_bot:
            u.draw(screen)

        # 显示主区域
        screen.blit(self.main_area, (0, 21), (self.scroll_x_pos - 1, self.scroll_y_pos, G.MAIN_AREA_X_POS, G.MAIN_AREA_Y_POS))

        # 显示上ui
        for u in self.ui_instances_top:
            u.draw(screen)

        # 显示屏幕特效
        for e in self.effects_screen:
            e.draw(screen)

        # 左侧黑条
        screen.blit(self.left_black, (0, 0))

        # 重置糖泡爆炸音效位
        BombInstance.sound_played = False

        # 重置糖泡爆炸方向记录
        for x in range(self.map_x):
            for y in range(self.map_y):
                self.grid_damage_orientations[(x, y)] = set()

        # print(pygame.time.get_ticks() - a)

    def update_obstacles_update_list(self):
        self.obstacle_instances_need_to_update = False
        self.obstacle_instances_update.clear()
        for x in range(int(self.scroll_x_pos / G.GAME_SQUARE), int((self.scroll_x_pos + G.MAIN_AREA_X_POS) / G.GAME_SQUARE) + 1):
            for y in range(int(self.scroll_y_pos / G.GAME_SQUARE), int((self.scroll_y_pos + G.MAIN_AREA_Y_POS) / G.GAME_SQUARE) + 1):
                if (x, y) in self.obstacle_instances.keys():
                    an_obstacle = self.obstacle_instances[(x, y)]
                    self.obstacle_instances_update.append(an_obstacle)

    def display_frame_rate(self, current_time, screen):
        self.frames_num += 1
        current_time_div_1000 = current_time // 1000
        if current_time_div_1000 > self.times_num:
            self.times_num = current_time_div_1000
            if G.DISPLAY_FRAME_RATE:
                img = self.frame_rate_text_font.render(str(self.frames_num), False, (255, 255, 255), (0, 0, 0))
                screen.blit(img, (100, 0))
            self.frames_num = 0

    def pass_map(self):
        # 尝试置finish_flag为True
        if self.district_all_finished and self.finish_at is not None:
            if self.me.x == self.finish_at[0] and self.me.y == self.finish_at[1]:
                self.finish_flag = True

    def scroll_map(self):
        # 滚动地图
        if self.me.x_pos > self.scroll_x_pos + G.R_SCROLL:
            # 向右滚动
            self.scroll_x_pos = max(0, min(self.me.x_pos - G.R_SCROLL, self.scroll_x_pos_max))
        elif self.me.x_pos < self.scroll_x_pos + G.L_SCROLL:
            # 向左滚动
            self.scroll_x_pos = max(0, min(self.me.x_pos - G.L_SCROLL, self.scroll_x_pos_max))
        if self.me.y_pos > self.scroll_y_pos + G.D_SCROLL:
            # 向下滚动
            self.scroll_y_pos = max(0, min(self.me.y_pos - G.D_SCROLL, self.scroll_y_pos_max))
        elif self.me.y_pos < self.scroll_y_pos + G.U_SCROLL:
            # 向上滚动
            self.scroll_y_pos = max(0, min(self.me.y_pos - G.U_SCROLL, self.scroll_y_pos_max))

    def alarm_district(self):
        # 显示当前区域的警戒
        if self.district_alarming:
            return
        DistrictAlarm(self.effects_behind)

    def get_bomb_instance(self, x, y):
        # 获取(x, y)处的所有糖泡list
        bs = list()
        for b in self.bomb_instances:
            if b.x == x and b.y == y and not b.throwing:
                bs.append(b)
        return bs

    def get_an_npc(self, name, point):
        return Npc(name, point)
