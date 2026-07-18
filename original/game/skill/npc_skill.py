from math import sqrt

import pygame.time

from game.const import game as G
from game.effect.effect_instance import EffectInstance, EffectState
from game.level import level
from game.skill.skill import Skill, IceSlow, GotPoisonSmoke50x3, GotPoisonSmoke80x2
from game.sound import sound_player


class Skill21000(Skill):

    # 1x1冰球下落，击中玩家减速
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.ice_down = True  # 火焰开始下落
        self.ice_down_finish = True  # 火焰开始完成
        self.ice_explode = True  # 火焰触碰到地面
        self.to_xy = dict()  # 火焰提示时玩家的xy
        self.effect_ice_down = list()  # 火焰下落动画的effect_instances列表
        self.finish_y = 0  # 底端火焰的最终y值
        self.hit = False  # 是否命中了玩家

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 3000:
            self.kill()
        if self.ice_explode and not self.ice_down_finish:
            # 冰球最终爆炸
            self.ice_explode = False
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("splash", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.to_xy[0], self.to_xy[1])
            self.effect_instances.append(an_effect)
            if self.hit:
                IceSlow(self.to, self.to.skill_instances)
        if not self.ice_down and self.ice_down_finish:
            # 冰球下落过程
            for e in self.effect_ice_down:
                e.set_xy_pos(e.x_pos, e.y_pos + 35)
                if e.y >= self.finish_y:
                    self.ice_down_finish = False
        if self.current_time - self.skill_time_init > 1000 and self.ice_down:
            # 冰球开始下落
            self.ice_down = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            # 伤害判断
            if self.to_xy[0] == self.to.x and self.to_xy[1] == self.to.y:
                self.hit = True
            an_effect = EffectInstance("ice_down", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.to_xy[0], (level.current_level.scroll_y_pos // G.GAME_SQUARE) - 2)
            self.effect_instances.append(an_effect)
            self.effect_ice_down.append(an_effect)
        if self.loaded:
            # npc施法阵
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("launch", self.user, False, self.user.effects_behind)
            )
            self.effect_instances.append(
                EffectInstance("ice_hint", self.to, False, level.current_level.effects_behind)
            )
            # 记录玩家初始位置与冰球结束位置
            self.to_xy = (self.to.x, self.to.y)
            self.finish_y = self.to.y
            sound_player.play("launch")


class Skill21002(Skill):

    # 1x1火球下落，击中玩家HP-100
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.fire_down = True  # 火焰开始下落
        self.fire_down_finish = True  # 火焰开始完成
        self.fire_explode = True  # 火焰触碰到地面
        self.to_xy = dict()  # 火焰提示时玩家的xy
        self.effect_fire_down = list()  # 火焰下落动画的effect_instances列表
        self.finish_y = 0  # 底端火焰的最终y值
        self.hit = False  # 是否命中了玩家

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 3000:
            self.kill()
        if self.fire_explode and not self.fire_down_finish:
            # 火球最终爆炸
            self.fire_explode = False
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("fire_explode", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.to_xy[0], self.to_xy[1])
            self.effect_instances.append(an_effect)
            if self.hit:
                self.to.try_damage(100)
                sound_player.play("cry")
        if not self.fire_down and self.fire_down_finish:
            # 火球下落过程
            for e in self.effect_fire_down:
                e.set_xy_pos(e.x_pos, e.y_pos + 35)
                if e.y >= self.finish_y:
                    self.fire_down_finish = False
        if self.current_time - self.skill_time_init > 1000 and self.fire_down:
            # 火球开始下落
            self.fire_down = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            # 击中判断
            if self.to_xy[0] == self.to.x and self.to_xy[1] == self.to.y:
                self.hit = True
            an_effect = EffectInstance("fire_down", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.to_xy[0], (level.current_level.scroll_y_pos // G.GAME_SQUARE) - 2)
            self.effect_instances.append(an_effect)
            self.effect_fire_down.append(an_effect)
        if self.loaded:
            # npc施法阵
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("launch", self.user, False, self.user.effects_behind)
            )
            self.effect_instances.append(
                EffectInstance("fire_hint", self.to, False, level.current_level.effects_behind)
            )
            # 记录玩家初始位置与火球结束位置
            self.to_xy = (self.to.x, self.to.y)
            self.finish_y = self.to.y
            sound_player.play("launch")


class Skill21003(Skill):

    # 1x3毒 命中减速30%
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.to_xy = None
        self.orient = ""
        self.orient_map = {"R": ((1, -1), (1, 0), (1, 1)), "U": ((-1, -1), (0, -1), (1, -1)),
                           "L": ((-1, -1), (-1, 0), (-1, 1)), "D": ((-1, 1), (0, 1), (1, 1))}
        self.effect_instances = list()
        self.loaded = True
        self.hint_finish = True
        self.poison_explode = True

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1500 and self.poison_explode:
            self.poison_explode = False
            if self.user.remain_blood == 0:
                self.kill()
                return
            for i in range(3):
                target_xy = (self.to_xy[0] + self.orient_map[self.orient][i][0], self.to_xy[1] + self.orient_map[self.orient][i][1])
                an_effect = EffectInstance("poison_explode_once", self.to, False, level.current_level.effects_front)
                an_effect.set_xy(*target_xy)
                # 判断击中
                if (self.to.x, self.to.y) == target_xy:
                    self.to.slow_for(3000, 0.3)
                    EffectInstance("dizzy_explode", self.to, True, self.to.effects_behind)
            self.user.rooted -= 1
        if self.current_time - self.skill_time_init > 800 and self.hint_finish:
            self.hint_finish = False
            for e in self.effect_instances:
                e.state = EffectState.DEAD
        if self.loaded:
            self.loaded = False
            self.to_xy = (self.to.x, self.to.y)
            self.orient = self.to.orientation
            EffectInstance("poison_charge", self.user, False, self.user.effects_front)
            for i in range(3):
                an_effect = EffectInstance("poison_hint", self.to, False, level.current_level.effects_behind)
                an_effect.set_xy(self.to_xy[0] + self.orient_map[self.orient][i][0], self.to_xy[1] + self.orient_map[self.orient][i][1])
                self.effect_instances.append(an_effect)
            self.user.rooted += 1
            self.user.align_xy()
            sound_player.play("launch")


class Skill21005(Skill):

    # 霜冻傀儡1x1冰锥（实际5x5）
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True  # 0ms
        self.ice_judge = True  # 300ms
        self.ice_explode = True  # 1500ms
        self.to_xy = None  # 冰霜提示时玩家的xy
        self.hit = False  # 是否命中玩家
        self.root_duration = 500  # 击中后眩晕时长

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 10000:
            if self.hit:
                self.to.speed /= 0.7
            self.kill()
        if self.current_time - self.skill_time_init > 1500 and self.ice_explode:
            if self.user.remain_blood == 0:
                self.kill()
                return
            self.ice_explode = False
            self.user.rooted -= 1
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("ice_explode", self.to, False, self.to.effects_front)
            an_effect.set_xy(self.to_xy[0], self.to_xy[1])
            self.effect_instances.append(an_effect)
            sound_player.play("explode2")
            if self.hit:
                self.effect_instances.append(EffectInstance("ice_slowed", self.to, True, self.to.effects_front))
                sound_player.play("cry")
                self.to.speed *= 0.7
        if self.current_time - self.skill_time_init > 800 and self.ice_judge:
            self.ice_judge = False
            # 判断是否击中玩家
            if abs(self.to_xy[0] - self.to.x) < 3 and abs(self.to_xy[1] - self.to.y) < 3:
                self.hit = True
        if self.loaded:
            self.loaded = False
            sound_player.play("launch")
            self.user.rooted += 1
            self.user.align_xy()
            self.to_xy = (self.to.x, self.to.y)
            self.effect_instances.append(EffectInstance("ice_charge", self.user, False, self.user.effects_front))
            self.effect_instances.append(EffectInstance("ice_hint", self.to, False, level.current_level.effects_behind))


class Skill21006(Skill):

    # 1x1燃烧火陷阱，踩中HP-200
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.to_already_on = False
        self.loaded = True

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 25000:
            self.kill()
            return
        if not self.loaded:
            if self.to.x == self.user_x and self.to.y == self.user_y:
                if not self.to_already_on:
                    self.to.try_damage(200)
                    EffectInstance("thunder_explode", self.to, True, self.to.effects_front)
                    sound_player.play("explode")
                    self.kill()
            else:
                self.to_already_on = False
        if self.loaded:
            self.loaded = False
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("got_fire_1", self.user, False, level.current_level.effects_behind)
            )
            if self.to.x == self.user_x and self.to.y == self.user_y:
                self.to_already_on = True


class Skill21007(Skill):

    # 1x1毒雾陷阱，踩中HP-50*3
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.to_already_on = False
        self.loaded = True

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 25000:
            self.kill()
            return
        if not self.loaded:
            if self.to.x == self.user_x and self.to.y == self.user_y:
                if not self.to_already_on:
                    # 踩中毒雾
                    GotPoisonSmoke50x3(self.to, self.to.skill_instances)
                    sound_player.play("explode2")
                    self.kill()
            else:
                self.to_already_on = False
        if self.loaded:
            self.loaded = False
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("poison_explode", self.user, False, level.current_level.effects_behind)
            )
            if self.to.x == self.user_x and self.to.y == self.user_y:
                self.to_already_on = True


class Skill21008(Skill):

    # 1x1冰球下落（Npc脚下），击中玩家减速
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.ice_down = True  # 火焰开始下落
        self.ice_down_finish = True  # 火焰开始完成
        self.ice_explode = True  # 火焰触碰到地面
        self.effect_ice_down = list()  # 火焰下落动画的effect_instances列表
        self.finish_y = 0  # 底端火焰的最终y值
        self.hit = False  # 是否命中了玩家

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 3000:
            self.kill()
        if self.ice_explode and not self.ice_down_finish:
            # 冰球最终爆炸
            self.ice_explode = False
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("splash", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.user_x, self.user_y)
            self.effect_instances.append(an_effect)
            if self.hit:
                IceSlow(self.to, self.to.skill_instances)
        if not self.ice_down and self.ice_down_finish:
            # 冰球下落过程
            for e in self.effect_ice_down:
                e.set_xy_pos(e.x_pos, e.y_pos + 35)
                if e.y >= self.finish_y:
                    self.ice_down_finish = False
        if self.current_time - self.skill_time_init > 800 and self.ice_down:
            # 冰球开始下落
            self.ice_down = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            # 伤害判断
            if abs(self.user_x - self.to.x) < 2 and abs(self.user_y - self.to.y) < 2:
                self.hit = True
            an_effect = EffectInstance("ice_down", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.user_x, (level.current_level.scroll_y_pos // G.GAME_SQUARE) - 2)
            self.effect_instances.append(an_effect)
            self.effect_ice_down.append(an_effect)
        if self.loaded:
            # npc施法阵
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("ice_charge", self.user, False, self.user.effects_behind)
            )
            self.effect_instances.append(
                EffectInstance("ice_hint", self.user, False, level.current_level.effects_behind)
            )
            # 记录玩家初始位置与冰球结束位置
            self.finish_y = self.user.y
            sound_player.play("launch")


class Skill21011(Skill):

    # 1x1火球下落（Npc脚下），击中玩家HP-100
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.fire_down = True  # 火焰开始下落
        self.fire_down_finish = True  # 火焰开始完成
        self.fire_explode = True  # 火焰触碰到地面
        self.effect_fire_down = list()  # 火焰下落动画的effect_instances列表
        self.finish_y = 0  # 底端火焰的最终y值
        self.hit = False  # 是否命中了玩家

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 3000:
            self.kill()
        if self.fire_explode and not self.fire_down_finish:
            # 火球最终爆炸
            self.fire_explode = False
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("fire_explode", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.user_x, self.user_y)
            self.effect_instances.append(an_effect)
            if self.hit:
                self.to.try_damage(100)
        if not self.fire_down and self.fire_down_finish:
            # 火球下落过程
            for e in self.effect_fire_down:
                e.set_xy_pos(e.x_pos, e.y_pos + 35)
                if e.y >= self.finish_y:
                    self.fire_down_finish = False
        if self.current_time - self.skill_time_init > 1000 and self.fire_down:
            # 火球开始下落
            self.fire_down = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            # 击中判断
            if abs(self.user_x - self.to.x) < 2 and abs(self.user_y - self.to.y) < 2:
                self.hit = True
            an_effect = EffectInstance("fire_down", self.user, False, level.current_level.effects_front)
            an_effect.set_xy(self.user_x, (level.current_level.scroll_y_pos // G.GAME_SQUARE) - 2)
            self.effect_instances.append(an_effect)
            self.effect_fire_down.append(an_effect)
        if self.loaded:
            # npc施法阵
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("launch", self.user, False, self.user.effects_behind)
            )
            self.effect_instances.append(
                EffectInstance("fire_hint", self.user, False, level.current_level.effects_behind)
            )
            # 记录玩家初始位置与火球结束位置
            self.finish_y = self.user.y
            sound_player.play("launch")


class Skill21014(Skill):

    # 5x5毒，命中玩家HP-100*3
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.hint_cancel = True
        self.poison_explode = True
        self.poison_rooted_effect = None

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 2500:
            self.kill()
        if self.current_time - self.skill_time_init > 1000 and self.poison_explode:
            # 眩晕爆炸
            self.poison_explode = False
            self.user.rooted -= 1
            # 检查死亡
            if self.user.remain_blood == 0:
                self.kill()
                return
            for x in range(-2, 3):
                for y in range(-2, 3):
                    an_effect = EffectInstance("poison_explode_once", self.user, False, level.current_level.effects_front)
                    an_effect.set_xy(self.user_x + x, self.user_y + y)
                    self.effect_instances.append(an_effect)
                    if self.to.x == self.user_x + x and self.to.y == self.user_y + y:
                        GotPoisonSmoke50x3(self.to, self.to.skill_instances)
                        sound_player.play("cry")
        if self.current_time - self.skill_time_init > 700 and self.hint_cancel:
            self.hint_cancel = False
            for e in self.effect_instances:
                e.state = EffectState.DEAD
        if self.loaded:
            # npc施法阵与眩晕范围提示
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            EffectInstance("poison_charge", self.user, False, self.user.effects_front)
            # 眩晕范围提示
            for x in range(-2, 3):
                for y in range(-2, 3):
                    an_effect = EffectInstance("poison_hint", self.user, False, level.current_level.effects_behind)
                    an_effect.set_xy(self.user_x + x, self.user_y + y)
                    self.effect_instances.append(an_effect)
            sound_player.play("launch")


class Skill21017(Skill):

    # 寒冰元素加速
    def __init__(self, user, skill_instances):
        super().__init__(user, None, skill_instances)
        self.loaded = True
        self.speed_add = 0

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 4000:
            self.user.speed -= self.speed_add
            self.kill()
        if self.loaded:
            self.loaded = False
            self.speed_add = 0.3 * self.user.speed
            self.user.speed += self.speed_add
            self.effect_instances.append(
                EffectInstance("defect_repeat", self.user, True, self.user.effects_front)
            )
            sound_player.play("explode2")
            sound_player.play("cry")


class Skill21018(Skill):

    # 粗线偶人近身3x3
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.damage = True

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1200:
            self.kill()
        if self.current_time - self.skill_time_init > 800 and self.damage:
            self.damage = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            if abs(self.to.x - self.user_x) < 2 and abs(self.to.y - self.user_y) < 2:
                self.to.try_damage(200)
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            EffectInstance("scope_3", self.user, False, level.current_level.effects_front)
            sound_player.play("launch")
            sound_player.play("explode2")


class Skill21019(Skill):

    # 冰霜之王面前1x7
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.explode = True
        self.direction = None
        self.direction_to_adder = {"R": (1, 0), "U": (0, -1), "L": (-1, 0), "D": (0, 1)}

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 2000:
            self.kill()
        if self.current_time - self.skill_time_init > 1000 and self.explode:
            self.explode = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            point = [self.user_x, self.user_y]
            for i in range(7):
                point[0] += self.direction_to_adder[self.direction][0]
                point[1] += self.direction_to_adder[self.direction][1]
                if self.to.x == point[0] and self.to.y == point[1]:
                    self.to.try_damage(1000)
                an_effect = EffectInstance("dizzy_explode", self.user, False, level.current_level.effects_front)
                an_effect.set_xy(*point)
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.direction = self.user.orientation
            point = [self.user_x, self.user_y]
            for i in range(7):
                point[0] += self.direction_to_adder[self.direction][0]
                point[1] += self.direction_to_adder[self.direction][1]
                an_effect = EffectInstance("dizzy_hint", self.user, False, level.current_level.effects_behind)
                an_effect.set_xy(*point)
            sound_player.play("launch")


class Skill21022(Skill):

    # 深寒元素冲击波
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.launch = True
        self.end = True
        self.knife_effect = None
        self.direction = None
        self.direction_to_adder = {"R": (0.4, 0), "U": (0, -0.4), "L": (-0.4, 0), "D": (0, 0.4)}
        self.eff_names = {"R": "air_knife_r", "U": "air_knife_u", "L": "air_knife_l", "D": "air_knife_d"}
        self.old_time = pygame.time.get_ticks()
        self.counter = 0

    def load(self):
        super().load()

    def update(self):
        super().update()
        if not self.end:
            EffectInstance("dizzy_explode", self.user, False, self.user.effects_front)
            self.knife_effect.state = EffectState.DEAD
            sound_player.play("explode")
            self.kill()
        if self.current_time - self.skill_time_init > 800 and self.launch:
            self.launch = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            self.effect_instances[0].state = EffectState.DEAD
            self.direction = self.user.orientation
            self.knife_effect = EffectInstance(self.eff_names[self.direction], self.user, False, level.current_level.effects_front)
            self.old_time = self.current_time
        if self.current_time - self.skill_time_init > 800 and self.end:
            delta_time = self.current_time - self.old_time  # 计算两次调用update的间隔
            self.knife_effect.set_xy_pos(
                self.knife_effect.x_pos + delta_time * self.direction_to_adder[self.direction][0],
                self.knife_effect.y_pos + delta_time * self.direction_to_adder[self.direction][1]
            )
            self.old_time = self.current_time
            if self.to.x == self.knife_effect.x and self.to.y == self.knife_effect.y:
                self.to.try_damage(200)
                self.end = False
            bombs = level.current_level.get_bomb_instance(self.knife_effect.x, self.knife_effect.y)
            if len(bombs) > 0:
                bombs[0].explode()
                self.end = False
            self.counter += 1
            if self.counter > 90:
                self.end = False
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("launch", self.user, False, self.user.effects_behind)
            )
            sound_player.play("launch")


class Skill21025(Skill):

    # 魔法僧侣紫刀
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.knife_charge = True  # 火苗充能
        self.knife_begin = True  # 火苗飞出
        self.knife_end = True  # 火苗到达
        self.to_xy = None  # 火苗目标
        self.delta_x = 0  # 火苗x增量
        self.delta_y = 0  # 火苗y增量
        self.delta_len = 0  # 火苗运行长度
        self.old_time = pygame.time.get_ticks()
        self.effect_fire = None
        self.damage_blood = 200

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 4000:
            self.kill()
        if not self.knife_begin and self.knife_end:
            e = self.effect_fire
            if self.delta_len != 0:
                delta_time = self.current_time - self.old_time  # 计算两次调用update的间隔
                e.set_xy_pos(e.x_pos + 0.6 * delta_time * self.delta_x / self.delta_len,
                             e.y_pos + 0.6 * delta_time * self.delta_y / self.delta_len)
                self.old_time = self.current_time
            if e.x == self.to_xy[0] and e.y == self.to_xy[1]:
                # 飞火到达目的地
                self.knife_end = False
                self.kill()
                sound_player.play("crash")
                # 造成伤害
                if self.to.x == self.to_xy[0] and self.to.y == self.to_xy[1]:
                    self.to.try_damage(self.damage_blood)
                # 引爆糖泡
                bombs = level.current_level.get_bomb_instance(self.to_xy[0], self.to_xy[1])
                if len(bombs) > 0:
                    bombs[0].explode()
        if not self.knife_charge and self.knife_begin:
            self.knife_begin = False
            if self.user.remain_blood == 0:
                self.kill()
                return
            self.old_time = self.current_time
            self.delta_x = self.to_xy[0] - self.user_x
            self.delta_y = self.to_xy[1] - self.user_y
            self.delta_len = sqrt(self.delta_x * self.delta_x + self.delta_y * self.delta_y)
            if self.delta_x > 0:
                self.effect_fire = EffectInstance("purple_knife_r", self.user, False, self.user.effects_front)
            else:
                self.effect_fire = EffectInstance("purple_knife_l", self.user, False, self.user.effects_front)
            self.effect_instances.append(self.effect_fire)
        if self.current_time - self.skill_time_init > 1000 and self.knife_charge:
            self.knife_charge = False
            self.user.rooted -= 1
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            sound_player.play("launch")
            self.to_xy = (self.to.x, self.to.y)


class Skill21027(Skill):

    # 红衣僧侣变猪
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.polymorphed = True

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 6500 and not self.polymorphed:
            self.kill()
        if self.current_time - self.skill_time_init > 500 and self.polymorphed:
            self.polymorphed = False
            self.user.rooted -= 1
            self.to.polymorph_for(6000)
            self.to.slow_for(6000, 0.1)
            self.effect_instances.append(
                EffectInstance("dizzy_explode", self.to, False, self.to.effects_front)
            )
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            sound_player.play("launch")
            self.effect_instances.append(
                EffectInstance("fire_charge", self.user, False, self.user.effects_front)
            )


class Skill21044(Skill):

    # 剑气5x5 HP-300
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.sword_again = True

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("sword", self.user, True, self.user.effects_front)
        )
        self.user.align_xy()
        if abs(self.to.x - self.user.x) < 3 and abs(self.to.y - self.user.y) < 3:
            self.to.try_damage(300)
            EffectInstance("thunder_explode", self.to, True, self.to.effects_front)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 800:
            self.kill()
        if self.current_time - self.skill_time_init > 650 and self.sword_again:
            self.sword_again = False
            self.effect_instances.append(
                EffectInstance("sword", self.user, True, self.user.effects_front)
            )


class Skill21049(Skill):

    # 恶魔反向0.5s
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.reverse = True

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("poison_charge", self.user, False, self.user.effects_front)
        )
        self.user.rooted += 1
        self.user.align_xy()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1500:
            self.kill()
        if self.current_time - self.skill_time_init > 1000 and self.reverse:
            if self.user.remain_blood == 0:
                self.kill()
                return
            self.reverse = False
            self.to.reverse_for(500)
            self.effect_instances.append(
                EffectInstance("monster", self.to, True, self.to.effects_front)
            )
            self.user.rooted -= 1


class Skill21054(Skill):

    # 蓬头树回血
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.recovery_trigger = [True, True, True, True, True]

    def load(self):
        super().load()
        for npc in self.to:
            self.effect_instances.append(
                EffectInstance("transform", npc, True, npc.effects_front)
            )
            self.effect_instances.append(
                EffectInstance("launch", npc, True, npc.effects_behind)
            )
        self.user.align_xy()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 10000:
            self.kill()
        at = min(len(self.recovery_trigger) - 1, (self.current_time - self.skill_time_init) // 2000)
        if self.recovery_trigger[at]:
            self.recovery_trigger[at] = False
            for npc in self.to:
                npc.heal(1000)


class Skill21065(Skill):

    # 剑气5x5 HP-100
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("sword", self.user, True, self.user.effects_front)
        )
        self.user.align_xy()
        if abs(self.to.x - self.user.x) < 3 and abs(self.to.y - self.user.y) < 3:
            self.to.try_damage(100)
            EffectInstance("thunder_explode", self.to, True, self.to.effects_front)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 500:
            self.kill()


class Skill21066(Skill):

    # 黑龙毒泡泡的毒陷阱-20HP
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.poison_trap = True
        self.to_already_on = False
        self.hero_got_trapped = False

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("poison_charge", self.user, False, self.user.effects_front)
        )
        sound_player.play("trap")
        self.user.rooted += 1
        self.user.align_xy()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 5000 and not self.hero_got_trapped:
            self.kill()
            return
        if self.current_time - self.skill_time_init > 950 and self.poison_trap:
            self.poison_trap = False
            self.effect_instances.append(
                EffectInstance("poison_trap", self.user, False, level.current_level.effects_behind)
            )
            self.user.rooted -= 1
            if self.to.x == self.user_x and self.to.y == self.user_y:
                self.to_already_on = True
            if self.user.remain_blood == 0:
                self.kill()
        if self.current_time - self.skill_time_init > 950:
            # 判断玩家是否踩中陷阱
            if self.to.x == self.user_x and self.to.y == self.user_y:
                if not self.to_already_on:
                    self.to.try_damage(20)
                    EffectInstance("poison_explode_twice", self.to, True, self.to.effects_front)
                    self.kill()
            else:
                self.to_already_on = False


class Skill21067(Skill):

    # 黑龙毒泡泡的毒雾陷阱-80HP*2
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.poison_trap = True
        self.to_already_on = False
        self.hero_got_trapped = False

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("poison_charge", self.user, False, self.user.effects_front)
        )
        sound_player.play("trap")
        self.user.rooted += 1
        self.user.align_xy()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 21000 and not self.hero_got_trapped:
            self.kill()
            return
        if self.current_time - self.skill_time_init > 950 and self.poison_trap:
            self.poison_trap = False
            self.effect_instances.append(
                EffectInstance("poison_explode", self.user, False, level.current_level.effects_behind)
            )
            self.user.rooted -= 1
            if self.to.x == self.user_x and self.to.y == self.user_y:
                self.to_already_on = True
            if self.user.remain_blood == 0:
                self.kill()
        if self.current_time - self.skill_time_init > 950:
            # 判断玩家是否踩中陷阱
            if self.to.x == self.user_x and self.to.y == self.user_y:
                if not self.to_already_on:
                    # 给玩家增加debuff
                    GotPoisonSmoke80x2(self.to, self.to.skill_instances)
                    self.kill()
            else:
                self.to_already_on = False


class Skill21069(Skill):

    # 剑气5x5 HP-500
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("sword", self.user, True, self.user.effects_front)
        )
        self.user.align_xy()
        if abs(self.to.x - self.user.x) < 3 and abs(self.to.y - self.user.y) < 3:
            self.to.try_damage(500)
            EffectInstance("thunder_explode", self.to, True, self.to.effects_front)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 500:
            self.kill()


class Skill21072(Skill):

    # 黑龙电法师3x3电 -500HP
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.thunder_down = True
        self.thunder_explode = True
        self.hit = False

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1500:
            self.kill()
        if self.current_time - self.skill_time_init > 600 and self.thunder_explode:
            self.thunder_explode = False
            if self.hit:
                self.to.try_damage(500)
            for x in range(-1, 2):
                for y in range(-1, 2):
                    an_effect = EffectInstance("thunder_explode", self.user, False, level.current_level.effects_front)
                    an_effect.set_xy(self.to_x + x, self.to_y + y)
        if self.current_time - self.skill_time_init > 300 and self.thunder_down:
            self.thunder_down = False
            if self.user.remain_blood == 0:
                self.kill()
                return
            self.user.rooted -= 1
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            if abs(self.to.x - self.to_x) < 2 and abs(self.to.y - self.to_y) < 2:
                self.hit = True
            for x in range(-1, 2):
                for y in range(-1, 2):
                    an_effect = EffectInstance("thunder_down", self.to, False, level.current_level.effects_front)
                    an_effect.set_xy(self.to_x + x, self.to_y + y)
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(EffectInstance("poison_charge", self.user, False, self.user.effects_front))
            sound_player.play("launch")


class Skill21073(Skill):

    # 黑龙电法师1x1电
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.thunder_down = True
        self.thunder_explode = True
        self.hit = False  # 是否命中玩家

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1000:
            self.kill()
        if self.current_time - self.skill_time_init > 600 and self.thunder_explode:
            self.thunder_explode = False
            an_effect = EffectInstance("thunder_explode", self.to, False, level.current_level.effects_front)
            an_effect.set_xy(self.to_x, self.to_y)
            if self.hit:
                self.to.try_damage(800)
                self.to.rooted_for(500)
        if self.current_time - self.skill_time_init > 300 and self.thunder_down:
            self.thunder_down = False
            self.user.rooted -= 1
            if self.user.remain_blood == 0:
                self.kill()
                return
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("thunder_down", self.to, False, level.current_level.effects_front)
            an_effect.set_xy(self.to_x, self.to_y)
            # 判断是否击中玩家
            if self.to_x == self.to.x and self.to_y == self.to.y:
                self.hit = True
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(EffectInstance("thunder_charge", self.user, False, self.user.effects_front))
            self.effect_instances.append(EffectInstance("thunder_trap", self.to, False, self.to.effects_behind))
            sound_player.play("launch")


class Skill21074(Skill):

    # 黑龙电法师电陷阱
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.damage_blood = 0
        self.thunder_trap = True
        self.to_already_on = False

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 10000:
            self.kill()
        if self.current_time - self.skill_time_init > 1000 and self.thunder_trap:
            self.thunder_trap = False
            if self.user.remain_blood == 0:
                self.kill()
                return
            self.user.rooted -= 1
            self.effect_instances.append(EffectInstance("thunder_trap", self.user, False, level.current_level.effects_behind))
            if self.to.x == self.user_x and self.to.y == self.user_y:
                self.to_already_on = True
        if self.current_time - self.skill_time_init > 1000:
            # 判断玩家是否踩中陷阱
            if self.to.x == self.user_x and self.to.y == self.user_y:
                if not self.to_already_on:
                    self.to.try_damage(299)
                    self.to.rooted_for(3000)
                    EffectInstance("thunder_fixed", self.to, True, self.to.effects_behind)
                    self.kill()
            else:
                self.to_already_on = False
        if self.loaded:
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("thunder_charge", self.user, False, self.user.effects_front)
            )
            sound_player.play("trap")


class Skill21082(Skill):

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.flame_charge = True  # 火苗充能
        self.flame_begin = True  # 火苗飞出
        self.flame_end = True  # 火苗到达
        self.to_xy = None  # 火苗目标
        self.delta_x = 0  # 火苗x增量
        self.delta_y = 0  # 火苗y增量
        self.delta_len = 0  # 火苗运行长度
        self.effect_fire = None
        self.old_time = pygame.time.get_ticks()
        self.damage_blood = 1000

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 3000:
            self.kill()
        if not self.flame_begin and self.flame_end:
            e = self.effect_fire
            if self.delta_len != 0:
                delta_time = self.current_time - self.old_time
                e.set_xy_pos(e.x_pos + delta_time * 0.6 * self.delta_x / self.delta_len,
                             e.y_pos + delta_time * 0.6 * self.delta_y / self.delta_len)
                self.old_time = self.current_time
            if e.x == self.to_xy[0] and e.y == self.to_xy[1]:
                # 飞火到达目的地
                self.flame_end = False
                self.kill()
                sound_player.play("crash")
                # 造成伤害
                if self.to.x == self.to_xy[0] and self.to.y == self.to_xy[1]:
                    self.to.try_damage(self.damage_blood)
                # 引爆糖泡
                bombs = level.current_level.get_bomb_instance(self.to_xy[0], self.to_xy[1])
                if len(bombs) > 0:
                    bombs[0].explode()
        if not self.flame_charge and self.flame_begin:
            self.flame_begin = False
            self.delta_x = self.to_xy[0] - self.user_x
            self.delta_y = self.to_xy[1] - self.user_y
            self.delta_len = sqrt(self.delta_x * self.delta_x + self.delta_y * self.delta_y)
            if self.delta_x > 0:
                self.effect_fire = EffectInstance("floating_fire_r", self.user, False, self.user.effects_front)
            else:
                self.effect_fire = EffectInstance("floating_fire_l", self.user, False, self.user.effects_front)
            self.effect_instances.append(self.effect_fire)
        if self.current_time - self.skill_time_init > 1000 and self.flame_charge:
            self.flame_charge = False
            self.old_time = self.current_time
            if self.user.remain_blood == 0:
                self.kill()
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            self.user.rooted -= 1
        if self.loaded:
            # npc施法阵与眩晕范围提示
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("launch2", self.user, True, self.user.effects_front)
            )
            sound_player.play("launch")
            self.to_xy = (self.to.x, self.to.y)


class Skill21087(Skill):

    # 剑气5x5 HP-800
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.sword_again = True

    def load(self):
        super().load()
        self.effect_instances.append(
            EffectInstance("sword", self.user, True, self.user.effects_front)
        )
        self.user.align_xy()
        if abs(self.to.x - self.user.x) < 3 and abs(self.to.y - self.user.y) < 3:
            self.to.try_damage(800)
            EffectInstance("thunder_explode", self.to, True, self.to.effects_front)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 800:
            self.kill()
        if self.current_time - self.skill_time_init > 650 and self.sword_again:
            self.sword_again = False
            self.effect_instances.append(
                EffectInstance("sword", self.user, True, self.user.effects_front)
            )
