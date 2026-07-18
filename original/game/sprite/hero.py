import json
from json import JSONDecodeError
import os
import sys

import pygame

from game.const import color as C
from game.const import game as G
from game.effect.effect_instance import EffectInstance
from game.frame import bomb
from game.level import level
from game.skill.hero_skill import FireworkRed, FireworkYellow, FireworkBlue, FireworkGreen, FireworkPurple, \
    FireworkRound, FireworkHeart
from game.skill.skill import Protect3s, Indicator, BloodElixirMiddle, BloodElixirSmall, BloodElixirLarge, PowerElixir, \
    MockingElixir, FriendlyElixir, RevivalCard
from game.sound import sound_player
from game.sprite.bomb_instance import BombInstance
from game.sprite.player import Player, PlayerState


DECORATION_CATEGORIES = ("cap", "hair", "eye", "ear", "mouth", "cladorn", "fpack", "npack", "thadorn", "footprint")

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


class Hero(Player):

    def __init__(self, hero_name, xy, color=C.CHARACTER_RED):

        super(Hero, self).__init__(hero_name, xy, color)
        self.color = color
        self.hero_json = None
        self.bomb_skin = None  # Hero糖泡皮肤（get_bomb的返回值）
        self.bomb_decoration = None  # Hero糖泡特效（文本）
        self.icon_img = None  # Hero左侧图片
        self.bomb = 0  # Hero糖泡数
        self.power = 0  # Hero糖泡威力
        self.restore = 0  # Hero糖泡回复速度（ms/个）
        self.damage = 0  # Hero糖泡单倍伤害
        self.remain_bombs = 0  # 当前Hero剩余可放糖泡数
        self.bomb_time_old = pygame.time.get_ticks()  # 上次放置糖泡的时刻

        self.rooted = 1
        self.rooted_begin = pygame.time.get_ticks()
        self.rooted_duration = 3000

        self.load_hero(hero_name)
        Protect3s(self, self.skill_instances)
        Indicator(self, self.skill_instances)

    def load_hero(self, hero_name):
        # 加载人物hero的json文件
        with open(get_file("game/hero/" + hero_name + ".json")) as f:
            try:
                self.hero_json = json.load(f)
            except JSONDecodeError:
                self.hero_json = json.load(open("game/hero/" + hero_name + ".json", encoding="utf-8_sig"))
            self.bomb_skin = bomb.get_bomb(self.hero_json["decorations"]["bomb_skin"])
            self.icon_img = self.hero_json["icon_img"]
            self.blood = self.hero_json["blood"]
            self.speed = (self.hero_json["speed"] * G.GAME_SQUARE) / 1000
            self.bomb = self.hero_json["bomb"]
            self.power = self.hero_json["power"]
            self.restore = self.hero_json["restore"]
            self.damage = self.hero_json["damage"]
            self.defense = self.hero_json["defense"]
            self.remain_blood = self.blood
            self.remain_bombs = self.bomb
            # 技能
            for s in self.hero_json["skills"]:
                self.skill_names.append(s["name"])
                self.skill_init_times.append(s["init"] + pygame.time.get_ticks())
                self.skill_intervals.append(s["interval"])
                self.skill_remains.append(s["max"])
            # 装饰
            decorations = self.load_decorations()
            # 加载character
            self.character = self.load_character(self.hero_json["character"], self.color, decorations)
            # for orient in self.character:
            #     if self.hero_json["decorations"]["disable_foot_and_leg"]:
            #         if "Foot" in self.character[orient]:
            #             del self.character[orient]["Foot"]
            #         if "Leg" in self.character[orient]:
            #             del self.character[orient]["Leg"]
            #         if "Leg_m" in self.character[orient]:
            #             del self.character[orient]["Leg_m"]
            # 特效
            if self.hero_json["decorations"]["head_effect"] is not None:
                EffectInstance(self.hero_json["decorations"]["head_effect"], self, True, self.effects_front)
            if self.hero_json["decorations"]["body_effect"] is not None:
                EffectInstance(self.hero_json["decorations"]["body_effect"], self, True, self.effects_front)
            if "bomb_effect" in self.hero_json["decorations"].keys() and self.hero_json["decorations"]["bomb_effect"] is not None:
                self.bomb_decoration = self.hero_json["decorations"]["bomb_effect"]

    def load_decorations(self):
        decorations = dict()
        for component in DECORATION_CATEGORIES:
            if self.hero_json["decorations"][component] is not None:
                if component == "footprint":
                    self.allow_footprint = True
                with open(get_file("game/frame/" + component + '/' + self.hero_json["decorations"][component] + ".json")) as ff:
                    decorations[component.capitalize()] = json.load(ff)
        return decorations

    def set_bomb(self):
        # 尝试放置一个糖泡
        if self.state != PlayerState.NORMAL:
            return
        if self.remain_bombs <= 0:
            return
        if self.polymorph > 0:
            return
        p = (self.x, self.y)
        bis = level.current_level.bomb_instances
        bs = level.current_level.get_bomb_instance(*p)
        if len(bs) > 0:  # 当前位置有糖泡
            return
        sound_player.play("bomb")
        b = BombInstance(self.x, self.y, bis, self.bomb_skin, self.power, self.damage, self)
        if self.bomb_decoration is not None:
            EffectInstance(self.bomb_decoration, b, True, b.effects_front)
        self.remain_bombs -= 1
        self.bomb_time_old = pygame.time.get_ticks()

    def update(self):
        super().update()
        current_time = pygame.time.get_ticks()
        self.time_restore_a_bomb(current_time)
        self.check_district_lock()

    def stimulate_x_y_changed_trigger(self):
        super().stimulate_x_y_changed_trigger()
        if self.x_y_changed_trigger:
            level.current_level.recal_npc_paths = True
            level.current_level.recal_ghost_paths = True
            level.current_level.obstacle_instances_need_to_update = True

    def time_restore_a_bomb(self, current_time):
        if current_time - self.bomb_time_old > self.restore:
            self.bomb_time_old = current_time
            self.restore_a_bomb()

    def restore_a_bomb(self):
        if self.remain_bombs >= self.bomb:
            return
        self.remain_bombs += 1

    def half_body_damage(self, point, cl, current_time):
        if not self.half_body_safe(point, cl, current_time):
            self.try_damage(cl.grid_damage_blood[point])

    def half_body_safe(self, point, cl, current_time):
        # 四个方向判断是否处在半身位置，以像素点<=2来判断无伤位置
        is_safe = False
        # 处在伤害格子的左侧，且同时右侧格子无伤害
        l_pos = self.x_pos - self.x * G.GAME_SQUARE
        l_point = (point[0] - 1, point[1])
        if 0 <= l_pos <= G.HALF_BODY_PIXEL:
            if current_time - cl.grid_damage_time[l_point] >= cl.accumulation_time:
                is_safe = True
        # 处在伤害格子的右侧，且同时左侧格子无伤害
        r_pos = ((self.x + 1) * G.GAME_SQUARE) - self.x_pos
        r_point = (point[0] + 1, point[1])
        if 0 <= r_pos <= G.HALF_BODY_PIXEL:
            if current_time - cl.grid_damage_time[r_point] >= cl.accumulation_time:
                is_safe = True
        # 处在伤害格子的下侧，且同时下侧格子无伤害
        d_pos = ((self.y + 1) * G.GAME_SQUARE) - self.y_pos
        d_point = (point[0], point[1] + 1)
        if 0 <= d_pos <= G.HALF_BODY_PIXEL:
            if current_time - cl.grid_damage_time[d_point] >= cl.accumulation_time:
                is_safe = True
        # 处在伤害格子的上侧，且同时上侧格子无伤害
        u_pos = self.y_pos - (self.y * G.GAME_SQUARE)
        u_point = (point[0], point[1] - 1)
        if 0 <= u_pos <= G.HALF_BODY_PIXEL:
            if current_time - cl.grid_damage_time[u_point] >= cl.accumulation_time:
                is_safe = True
        return is_safe

    def polymorph_for(self, duration):
        if self.polymorph_begin != 0:
            return
        self.polymorph += 1
        self.polymorph_begin = pygame.time.get_ticks()
        self.polymorph_duration = duration
        self.character = self.load_character("Character15701", "Red", dict())

    def check_polymorph_time(self, current_time):
        if self.polymorph_begin != 0 and current_time - self.polymorph_begin > self.polymorph_duration:
            self.polymorph = max(0, self.polymorph - 1)
            self.polymorph_begin = 0
            self.character = self.load_character(self.hero_json["character"], self.color, self.load_decorations())

    def check_district_lock(self):
        if self.district_locked:
            return
        square = level.current_level.district_square
        if square is None:
            return
        if square["x1"] <= self.x_pos <= square["x2"] and square["y1"] <= self.y_pos <= square["y2"]:
            self.district_locked = True
            self.collide_district()

    def collide_district(self):
        # Hero碰撞区域 红色提示
        level.current_level.alarm_district()

    def try_push(self, direction, offset=(0, 0)):
        # 对玩家当前位置(self.x, self.y)的direction方向上，加上offset后的障碍进行推
        oi = level.current_level.obstacle_instances
        d2p = {'R': (self.x + 1, self.y), 'U': (self.x, self.y - 1), 'L': (self.x - 1, self.y), 'D': (self.x, self.y + 1)}
        p = (d2p[direction][0] + offset[0], d2p[direction][1] + offset[1])
        if p in oi:
            oi[p].push(direction)

    def if_take_item(self):
        if super().if_take_item():
            sound_player.play("item")

    def die(self):
        super().die()
        sound_player.play("hero_dead")
        for n in level.current_level.npcs:
            n.resentful = False

    def use_skill(self, idx: int):
        if idx > len(self.skill_names) - 1:
            # 技能越界返回
            return
        if self.state == PlayerState.LOSE and self.skill_names[idx] != "RevivalCard":
            # 人物死亡返回
            return
        if self.polymorph > 0:
            # 变形返回
            return
        current_time = pygame.time.get_ticks()
        if current_time < self.skill_init_times[idx] or self.skill_remains[idx] == 0:
            # 未到初始时间 或技能冷却中 或次数已用完（-1则可以无限使用）
            return
        name = self.skill_names[idx]
        if name == "BloodElixirSmall":
            BloodElixirSmall(self, self.skill_instances)
        elif name == "BloodElixirMiddle":
            BloodElixirMiddle(self, self.skill_instances)
        elif name == "BloodElixirLarge":
            BloodElixirLarge(self, self.skill_instances)
        elif name == "PowerElixir":
            PowerElixir(self, self.skill_instances)
        elif name == "FriendlyElixir":
            FriendlyElixir(self, level.current_level.npcs, self.skill_instances)
        elif name == "MockingElixir":
            MockingElixir(self, level.current_level.npcs, self.skill_instances)
        elif name == "RevivalCard":
            RevivalCard(self, self.skill_instances)
        elif name == "FireworkRed":
            FireworkRed(self, self.skill_instances)
        elif name == "FireworkYellow":
            FireworkYellow(self, self.skill_instances)
        elif name == "FireworkBlue":
            FireworkBlue(self, self.skill_instances)
        elif name == "FireworkGreen":
            FireworkGreen(self, self.skill_instances)
        elif name == "FireworkPurple":
            FireworkPurple(self, self.skill_instances)
        elif name == "FireworkRound":
            FireworkRound(self, self.skill_instances)
        elif name == "FireworkHeart":
            FireworkHeart(self, self.skill_instances)
        self.skill_remains[idx] -= 1  # 剩余数量-1
        self.skill_init_times[idx] = current_time + self.skill_intervals[idx]  # 冷却时间累加
