import json

import pygame
from game.algo import aStar
from game.const import game as G
from game.const import color as C
from game.level import level
from game.sprite.player import Player


# 死亡npc的
class Ghost(Player):

    def __init__(self, npc_name, xy, time, speed, contact, color=C.CHARACTER_RED):
        super(Ghost, self).__init__(npc_name, xy, color)
        self.npc_json = None
        self.ghost_time_init = 0
        self.time = int(time)  # 总存活时间
        self.remain_time = 0  # 剩余存活时间
        self.speed = speed * G.GAME_SQUARE / 1000  # 移动速度
        self.contact = int(contact)  # 接触伤害
        self.me = level.current_level.me
        self.chase_path = dict()
        self.load_ghost(npc_name, color)
        self.wall_walking = True
        level.current_level.recal_ghost_paths = True

    def load_ghost(self, npc_name, color):
        with open("game/npc/" + npc_name + ".json", encoding="utf-8") as f:
            self.npc_json = json.load(f)
            self.character = self.load_character(self.npc_json["character"], color, dict(), True)
        self.ghost_time_init = pygame.time.get_ticks()
        self.remain_time = 1 if self.time <= 0 else self.time

    def update(self):
        super().update()
        current_time = pygame.time.get_ticks()
        self.chase_hero(current_time)
        self.contact_damage()
        self.update_remain_time(current_time)

    def chase_hero(self, current_time):
        me = (level.current_level.me.x, level.current_level.me.y)
        now = (self.x, self.y)
        # 如果重新计算路径标志为True则重新追踪玩家
        if level.current_level.recal_ghost_paths:
            self.chase_path = aStar.cal_path(
                now,
                me,
                (level.current_level.district_square_grid["x1"], level.current_level.district_square_grid["y1"]),
                (level.current_level.district_square_grid["x2"], level.current_level.district_square_grid["y2"]),
                True
            )
        if now in self.chase_path.keys():
            next = self.chase_path[now]
            if next is None:
                self.set_motion()
            elif next[0] > self.x:
                self.set_motion("R")
            elif next[1] < self.y:
                self.set_motion("U")
            elif next[0] < self.x:
                self.set_motion("L")
            elif next[1] > self.y:
                self.set_motion("D")
        else:
            self.set_motion()

    def contact_damage(self):
        # 检查npc与人物的接触伤害
        if level.current_level.me.x == self.x and level.current_level.me.y == self.y:
            level.current_level.me.try_damage(self.contact, "C")

    def update_remain_time(self, current_time):
        if self.time <= 0:
            # 如果区域计时或永存，则不计算剩余时间
            return
        self.remain_time = self.time - (current_time - self.ghost_time_init)

    def try_push(self, direction, offset=(0, 0)):
        pass

    def set_restoration(self, to_x, to_y):
        self.x = to_x
        self.y = to_y

    def draw(self, screen: pygame.Surface):
        super().draw(screen)
