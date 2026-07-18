import random

from game.skill.skill import Skill
from game.effect.effect_instance import EffectState, EffectInstance
from game.frame import bomb
from game.level import level
from game.sound import sound_player
from game.sprite.bomb_instance import BombInstance, BombInstanceBlack, BombInstanceGold


class RevengeDash(Skill):

    # 复仇冲刺：受到伤害后获得150%的移动速度加成，持续1.5s
    def __init__(self, user, skill_instances):
        super().__init__(user, None, skill_instances)
        self.loaded = True
        self.speed_add = 0  # 速度增量
        self.speed_add_rate = 1.5  # 速度增量比率
        self.dashing_begin_time = 0  # 冲刺起始时刻
        self.is_dashing = False  # 是否正在冲刺
        self.dashing_time = 1500  # 冲刺持续时间

    def update(self):
        super().update()
        if self.loaded:
            self.loaded = False
            self.speed_add = self.speed_add_rate * self.user.speed
        if self.user.get_damage_frame:
            self.is_dashing = True
            self.dashing_begin_time = self.current_time
            self.user.speed += self.speed_add
            self.effect_instances.append(
                EffectInstance("defect", self.user, True, self.user.effects_front)
            )
            sound_player.play("cry")
        if self.current_time - self.dashing_begin_time > self.dashing_time and self.is_dashing:
            self.is_dashing = False
            self.user.speed -= self.speed_add


class RevengeDash3s(RevengeDash):

    # 复仇冲刺：受到伤害后获得300%的移动速度加成，持续3s
    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.speed_add_rate = 3
        self.dashing_time = 3000


class ContactStun(Skill):

    # 电晕
    def __init__(self, user, to, skill_instances):
        self.stun_begin = 0
        self.is_stun = False
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        if not self.is_stun and self.user.x == self.to.x and self.user.y == self.to.y and self.user.remain_blood > 0:
            self.is_stun = True
            self.stun_begin = self.current_time
            self.to.rooted_for(2000)
            EffectInstance("seduce", self.to, True, level.current_level.effects_front)
        if self.is_stun and self.current_time - self.stun_begin > 5000:
            self.is_stun = False


class TemporaryHidden(Skill):

    # 小幽灵隐身：进入隐身状态，持续3秒
    def __init__(self, user, to, skill_instances):
        self.alpha = 255  # 不透明度0-255
        self.is_hidden = True  # True 隐身 / False 恢复
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 4000:
            self.kill()
        if self.current_time - self.skill_time_init > 3000:
            self.is_hidden = False

        if self.to.remain_blood <= 0:
            self.user.temporary_alpha = 255
            self.kill()
            return

        if self.is_hidden and self.alpha > 0:
            self.alpha = max(0, self.alpha - 32)
        elif not self.is_hidden and self.alpha < 255:
            self.alpha = min(255, self.alpha + 32)
        self.user.temporary_alpha = self.alpha


class PermanentlyHidden(Skill):

    # 幽灵隐身：进入隐身状态，受到伤害或近身玩家时暂时现身3s
    def __init__(self, user, to, skill_instances):
        self.alpha = 255  # 不透明度0-255
        self.is_hidden = True  # True 隐身 / False 恢复
        self.show_begin = -32768  # 临时现身
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.to.remain_blood <= 0:
            self.alpha = self.user.temporary_alpha = 255
            return
        if self.user.get_damage_frame:
            self.show_begin = self.current_time
        self.is_hidden = self.current_time - self.show_begin > 3000  # 造成伤害3s内现身
        if self.is_hidden and self.alpha > 0:
            self.alpha = max(0, self.alpha - 32)
        elif not self.is_hidden and self.alpha < 255:
            self.alpha = min(255, self.alpha + 32)
        self.user.temporary_alpha = self.alpha


class PutBomb(Skill):

    # 放置糖泡：在当前位置放置一颗糖泡，3秒后爆炸，造成100HP伤害
    def __init__(self, user, skill_instances):
        super().__init__(user, None, skill_instances)

    def load(self):
        super().load()
        self.user.set_bomb()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 500:
            self.kill()


class BombThrow(Skill):

    # 点抛糖泡
    def __init__(self, user, to, skill_instances):
        self.bis = level.current_level.bomb_instances
        self.bomb_gene_fin = False
        self.to_xy = None
        self.effect_launch = None
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.user.align_xy()
        self.user.rooted_for(500)
        self.effect_launch = EffectInstance("launch", self.user, False, self.user.effects_behind)
        self.effect_instances.append(self.effect_launch)
        self.to_xy = [self.to.x, self.to.y]
        sound_player.play("launch")

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1000:
            self.kill()
        if self.current_time - self.skill_time_init > 500 and not self.bomb_gene_fin:
            self.bomb_gene_fin = True
            a_bomb = self.gene_bomb()
            a_bomb.throw_to(self.to_xy[0], self.to_xy[1], self.get_directions(), True)
            self.effect_launch.state = EffectState.DEAD

    def gene_bomb(self):
        return BombInstance(self.user.x, self.user.y, self.bis, bomb.get_bomb("bomb1"), 3, 0)

    def get_directions(self):
        user_p = [self.user.x, self.user.y]
        to_p = [self.to_xy[0], self.to_xy[1]]
        if user_p[0] == to_p[0]:
            if user_p[1] > to_p[1]:
                return "U"
            else:
                return "D"
        if to_p[0] > user_p[0]:
            return "R"
        else:
            return "L"


class BombThrowGold(BombThrow):

    # 点抛糖泡（金色）
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.bomb_skin = bomb.get_bomb("bomb497")

    def gene_bomb(self):
        return BombInstanceGold(self.user.x, self.user.y, self.bis, bomb.get_bomb("bomb497"), 3, 0)


class BombThrowBlack(BombThrow):

    # 点抛糖泡（黑色）
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def gene_bomb(self):
        return BombInstanceBlack(self.user.x, self.user.y, self.bis, bomb.get_bomb("bomb462"), 3, 0)


class BombJail(Skill):

    # 天牢
    def __init__(self, user, to, skill_instances):
        self.bomb_skin = bomb.get_bomb("bomb1")
        self.bis = level.current_level.bomb_instances
        self.bomb_gene_fin = False
        self.to_xy = None
        self.effect_launch = None
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.user.align_xy()
        self.user.rooted_for(500)
        self.effect_launch = EffectInstance("launch", self.user, False, self.user.effects_behind)
        self.effect_instances.append(self.effect_launch)
        self.to_xy = [self.to.x, self.to.y]
        sound_player.play("launch")
        EffectInstance("tian_lao", self.user, False, self.user.effects_front)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1000:
            self.kill()
        if self.current_time - self.skill_time_init > 500 and not self.bomb_gene_fin:
            self.bomb_gene_fin = True
            a_bomb = self.gene_bomb()
            a_bomb.throw_to(self.to_xy[0] + 1, self.to_xy[1], self.get_directions("R"), True)
            a_bomb = self.gene_bomb()
            a_bomb.throw_to(self.to_xy[0], self.to_xy[1] - 1, self.get_directions("U"), True)
            a_bomb = self.gene_bomb()
            a_bomb.throw_to(self.to_xy[0] - 1, self.to_xy[1], self.get_directions("L"), True)
            a_bomb = self.gene_bomb()
            a_bomb.throw_to(self.to_xy[0], self.to_xy[1] + 1, self.get_directions("D"), True)
            self.effect_launch.state = EffectState.DEAD

    def gene_bomb(self):
        return BombInstance(self.user.x, self.user.y, self.bis, self.bomb_skin, 3, 500)

    def get_directions(self, pos):
        user_p = [self.user.x, self.user.y]
        to_p = [self.to_xy[0], self.to_xy[1]]
        if pos == "R":
            to_p[0] += 1
        elif pos == "U":
            to_p[1] -= 1
        elif pos == "L":
            to_p[0] -= 1
        elif pos == "D":
            to_p[1] += 1
        if user_p[0] == to_p[0]:
            if user_p[1] > to_p[1]:
                return "U"
            else:
                return "D"
        if to_p[0] > user_p[0]:
            return "R"
        else:
            return "L"


class BombEscape(Skill):

    # 金蝉脱壳：当自身上下左右邻位均存在糖泡时，立即传送到玩家身边没有障碍和糖泡的任一位置
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        cl = level.current_level
        right_bomb_num = len(cl.get_bomb_instance(self.user.x + 1, self.user.y))
        up_bomb_num = len(cl.get_bomb_instance(self.user.x, self.user.y - 1))
        left_bomb_num = len(cl.get_bomb_instance(self.user.x - 1, self.user.y))
        down_bomb_num = len(cl.get_bomb_instance(self.user.x, self.user.y + 1))
        if right_bomb_num > 0 and up_bomb_num > 0 and left_bomb_num > 0 and down_bomb_num > 0:
            # npc传送
            safe_grids = self.cal_to_available(cl)  # 计算全部安全格子
            if len(safe_grids) == 0:
                return
            safe_point = random.choice(safe_grids)  # 随机抽取安全格子
            self.effect_instances.append(
                EffectInstance("blue_dots_reverse", self.user, False, self.user.effects_front)
            )
            self.user.set_xy(*safe_point)
            self.effect_instances.append(
                EffectInstance("blue_dots", self.user, False, self.user.effects_front)
            )
            sound_player.play("X08_01")

    def cal_to_available(self, cl):
        # 计算玩家周围的安全格子
        safe_grids = []
        right_block = cl.block[1][self.to.x + 1][self.to.y]
        top_block = cl.block[0][self.to.x][self.to.y]
        left_block = cl.block[1][self.to.x][self.to.y]
        bottom_block = cl.block[0][self.to.x][self.to.y + 1]
        right_bomb_num = len(cl.get_bomb_instance(self.to.x + 1, self.to.y))
        up_bomb_num = len(cl.get_bomb_instance(self.to.x, self.to.y - 1))
        left_bomb_num = len(cl.get_bomb_instance(self.to.x - 1, self.to.y))
        down_bomb_num = len(cl.get_bomb_instance(self.to.x, self.to.y + 1))
        if not right_block and right_bomb_num == 0 and self.to.x + 1 < cl.map_x:
            safe_grids.append((self.to.x + 1, self.to.y))
        if not top_block and up_bomb_num == 0 and self.to.y > 0:
            safe_grids.append((self.to.x, self.to.y - 1))
        if not left_block and left_bomb_num == 0 and self.to.x > 0:
            safe_grids.append((self.to.x - 1, self.to.y))
        if not bottom_block and down_bomb_num == 0 and self.to.y + 1 < cl.map_y:
            safe_grids.append((self.to.x, self.to.y + 1))
        return safe_grids


class LandQuake(Skill):

    # 余震
    def __init__(self, user, to, skill_instances):
        self.defense_add: int = 0  # 防御增量
        self.defense_begin = -32768
        self.is_defense = False
        self.effect_shield = None  # 盾动画
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.defense_add = int(1.5 * self.user.defense)

    def update(self):
        super().update()
        if self.user.remain_blood == 0 and self.effect_shield is not None:
            self.effect_shield.state = EffectState.DEAD
        if not self.is_defense and self.current_time - self.defense_begin > 20000 and self.user.x == self.to.x and self.user.y == self.to.y:
            self.is_defense = True
            self.defense_begin = self.current_time
            self.user.defense += self.defense_add
            self.effect_shield = EffectInstance("shield", self.user, True, level.current_level.effects_front)
            sound_player.play("X27_01")
        if self.is_defense and self.current_time - self.defense_begin > 5000:
            self.is_defense = False
            self.user.defense -= self.defense_add
            # 5x5伤害
            if abs(self.user.x - self.to.x) < 3 and abs(self.user.y - self.to.y) < 3:
                self.to.try_damage(1000)
            for x in range(-2, 3):
                for y in range(-2, 3):
                    an_effect = EffectInstance("dizzy_explode", self.user, False, level.current_level.effects_front)
                    an_effect.set_xy(self.user.x + x, self.user.y + y)
                    self.effect_instances.append(an_effect)
            if self.effect_shield is not None:
                self.effect_shield.state = EffectState.DEAD
            sound_player.play("X22_01")


class ColorfulSmoke(Skill):
    SMOKE_RED = 0
    SMOKE_BLUE = 1
    SMOKE_WHITE = 2

    # 属性雾
    def __init__(self, user, to, skill_instances):
        self.smoke_type_to_charge_eff = {
            ColorfulSmoke.SMOKE_RED: ("dizzy_explode_red_hint", "dizzy_explode_red"),
            ColorfulSmoke.SMOKE_BLUE: ("dizzy_explode_blue_hint", "dizzy_explode_blue"),
            ColorfulSmoke.SMOKE_WHITE: ("dizzy_explode_white_hint", "dizzy_explode_white")
        }
        self.smoke_list = (0, 0, 0, 0, 1, 1, 1, 1, 2, 2)
        self.smoke_type = None
        self.smoke_launched = False  # 雾已经爆发
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.smoke_type = random.choice(self.smoke_list)
        self.effect_instances.append(
            EffectInstance(self.smoke_type_to_charge_eff[self.smoke_type][0], self.user, False,
                           level.current_level.effects_front)
        )
        self.user.align_xy()
        self.user.rooted_for(1000)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 30000:
            self.kill()
            return
        if self.current_time - self.skill_time_init > 1000 and not self.smoke_launched:
            self.smoke_launched = True
            dizzy_explode_type = self.smoke_type_to_charge_eff[self.smoke_type][1]
            for x in range(-1, 2):
                for y in range(-1, 2):
                    bomb_num = len(level.current_level.get_bomb_instance(self.to.x + x, self.to.y + y))
                    if bomb_num > 0:
                        continue
                    an_effect = EffectInstance(dizzy_explode_type, self.to, False, level.current_level.effects_front)
                    an_effect.set_xy(self.to.x + x, self.to.y + y)
                    self.effect_instances.append(an_effect)
                    if self.to.x == self.to.x + x and self.to.y == self.to.y + y:
                        pass

    def kill(self):
        super().kill()


class DistantIce5x5(Skill):

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True
        self.hint_again = True
        self.ice_up = True  # 火焰开始下落
        self.to_xy = None  # 玩家原位置

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 2500:
            self.kill()
        if self.current_time - self.skill_time_init > 1500 and self.ice_up and self.to.remain_blood > 0:
            # 冰山攻击瞬间
            self.ice_up = False
            self.user.rooted -= 1
            # 伤害判断
            if abs(self.to_xy[0] - self.to.x) < 3 and abs(self.to_xy[1] - self.to.y) < 3:
                self.to.slow_for(3000, 0.5)
                EffectInstance("dizzy_explode_blue", self.to, True, self.to.effects_front)
            # 播放动画
            for x in range(-2, 3):
                for y in range(-2, 3):
                    an_effect = EffectInstance("ice_explode", self.user, False, level.current_level.effects_front)
                    an_effect.set_xy(self.to_xy[0] + x, self.to_xy[1] + y)
                    self.effect_instances.append(an_effect)
        if self.current_time - self.skill_time_init > 1000 and self.hint_again:
            # 再次显示寒冰提示
            self.hint_again = False
            self.effect_instances.append(
                EffectInstance("ice_charge", self.user, False, self.user.effects_behind)
            )
        if self.loaded:
            # 显示寒冰提示与npc施法特效
            self.loaded = False
            self.user.rooted += 1
            self.user.align_xy()
            self.effect_instances.append(
                EffectInstance("ice_charge", self.user, False, self.user.effects_behind)
            )
            for x in range(-2, 3):
                for y in range(-2, 3):
                    an_effect = EffectInstance("ice_hint", self.user, False, level.current_level.effects_behind)
                    an_effect.set_xy(self.to.x + x, self.to.y + y)
                    self.effect_instances.append(an_effect)
            self.to_xy = (self.to.x, self.to.y)
            sound_player.play("launch")


class SlowSword(Skill):

    # 缓速剑
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        self.effect_instances.append(
            EffectInstance("sword", self.user, True, self.user.effects_front)
        )
        self.user.align_xy()
        if abs(self.to.x - self.user.x) < 3 and abs(self.to.y - self.user.y) < 3:
            self.to.slow_for(500, 0.7)
            EffectInstance("dizzy_explode_blue", self.to, True, self.to.effects_front)

    def update(self):
        if self.current_time - self.skill_time_init > 500:
            self.kill()


class DirtyPath(Skill):

    def __init__(self, user, to, skill_instances):
        self.dirty_points_list = list()
        self.dirty_points_set = set()
        self.last_dirty_time = -32768
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        user_point = (self.user.x, self.user.y)
        if user_point not in self.dirty_points_set and self.current_time - self.last_dirty_time > 100 and self.user.remain_blood > 0:
            an_effect = EffectInstance("dirty_path", self.user, False, level.current_level.effects_behind)
            self.dirty_points_list.append((self.current_time, user_point, an_effect))
            self.dirty_points_set.add(user_point)
            self.effect_instances.append(an_effect)
            self.last_dirty_time = self.current_time
        if len(self.dirty_points_list) > 0 and self.current_time - self.dirty_points_list[0][0] > 3000:
            first_dirty = self.dirty_points_list[0]
            self.dirty_points_list.remove(first_dirty)
            if first_dirty[1] in self.dirty_points_set:
                self.dirty_points_set.remove(first_dirty[1])
            first_dirty[2].state = EffectState.DEAD
        if (self.to.x, self.to.y) in self.dirty_points_set:
            self.to.slow_for(100, 0.5)


class NearSlow(Skill):

    # 近身自身缓速
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        if abs(self.user.x - self.to.x) < 4 and abs(self.user.y - self.to.y) < 4:
            self.user.slow_for(100, 0.4)


class NearAccelerate(Skill):

    # 近身自身加速
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()

    def update(self):
        super().update()
        if abs(self.user.x - self.to.x) < 4 and abs(self.user.y - self.to.y) < 4:
            self.user.slow_for(100, -0.5)


class SlowSmoke7x7(Skill):

    # 近身减速雾7x7，命中损失95%的移速，持续200ms
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.user.align_xy()
        for x in range(-3, 4):
            for y in range(-3, 4):
                an_effect = EffectInstance("dizzy_hint", self.user, False, level.current_level.effects_behind)
                an_effect.set_xy(self.user_x + x, self.user_y + y)
                self.effect_instances.append(an_effect)
        if abs(self.to.x - self.user.x) < 4 and abs(self.to.y - self.user.y) < 4:
            self.to.slow_for(200, 0.95)


class BombThrowRain(Skill):

    # 点抛糖泡雨
    def __init__(self, user, to, skill_instances):
        self.bis = level.current_level.bomb_instances
        self.bomb_gene_at = 0
        self.bomb_gene_time = (1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800, 3000, 3200, 3400, 3600, 3800)
        self.to_xy = None
        self.effect_launch = None
        super().__init__(user, to, skill_instances)

    def load(self):
        super().load()
        self.user.align_xy()
        self.user.rooted_for(4000)
        self.effect_launch = EffectInstance("launch", self.user, False, self.user.effects_behind)
        self.effect_instances.append(self.effect_launch)
        self.to_xy = [self.to.x, self.to.y]
        sound_player.play("launch")

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 3800:
            self.kill()
        if self.current_time - self.skill_time_init > self.bomb_gene_time[self.bomb_gene_at]:
            self.bomb_gene_at = min(self.bomb_gene_at + 1, len(self.bomb_gene_time) - 1)  # 当前糖泡位置+1
            point = self.gene_point()
            if point is None:
                return
            a_bomb = self.gene_bomb()
            a_bomb.throw_to(point[0], point[1], self.get_directions([point[0], point[1]]), True)
            self.effect_launch.state = EffectState.DEAD

    def gene_point(self):
        return None

    def gene_bomb(self):
        return BombInstance(self.user.x, self.user.y, self.bis, bomb.get_bomb("bomb1"), 8, 2000)

    def get_directions(self, to_p):
        user_p = [self.user.x, self.user.y]
        if user_p[0] == to_p[0]:
            if user_p[1] > to_p[1]:
                return "U"
            else:
                return "D"
        if to_p[0] > user_p[0]:
            return "R"
        else:
            return "L"


class BombThrowRainPlayer(BombThrowRain):

    # 点抛糖泡雨
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)

    def gene_point(self):
        return self.to.x, self.to.y


class BombThrowRainRandom(BombThrowRain):

    # 点抛糖泡雨
    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.grid_list = list()
        self.first()
        self.size = int(len(self.grid_list) / 4)

    def first(self):
        grid = level.current_level.district_square_grid
        for x in range(grid["x1"], grid["x2"] + 1):
            for y in range(grid["y1"], grid["y2"] + 1):
                self.grid_list.append((x, y))
        random.shuffle(self.grid_list)

    def gene_point(self):
        if self.size > 0:
            self.size -= 1
            return self.grid_list.pop(0)
        else:
            return None


class IceFireSwitch(Skill):

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.bis = level.current_level.bomb_instances
        self.trap_gene_last_time = 0
        self.trap_gene_at = 0
        self.trap_gene_max = 0
        self.trap_gene_duration = 500
        self.trap_dict = {True: ("ice_hint", "ice_explode"), False: ("fire_hint", "fire_explode")}
        self.loaded = True
        self.points = None
        self.launch_eff = None

    def update(self):
        super().update()
        if self.loaded:
            self.loaded = False
            self.trap_gene_max = random.randint(4, 10)
            self.user.rooted += 1
            self.launch_eff = EffectInstance("launch", self.user, True, self.user.effects_behind)
        if self.current_time - self.trap_gene_last_time > self.trap_gene_duration:
            # 删除上一轮的陷阱
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            # 检查死亡
            if self.to.remain_blood == 0:
                self.kill()
                return
            # 是否可以引爆当前陷阱
            if self.trap_gene_at == self.trap_gene_max:
                is_even = self.trap_gene_at % 2 == 0
                for p in self.points:
                    EffectInstance(self.trap_dict[is_even][1], self.user, False, level.current_level.effects_behind) \
                        .set_xy(p[0], p[1])
                    if self.to.x == p[0] and self.to.y == p[1]:
                        if is_even:
                            self.to.rooted_for(1000)
                            self.to.try_damage(1000)
                        else:
                            self.to.slow_for(1000, 0.5)
                            self.to.try_damage(1500)
                self.launch_eff.state = EffectState.DEAD
                sound_player.play("X22_01")
                self.kill()
                return
            # 陷阱轮次计数+1
            self.trap_gene_last_time = self.current_time
            self.trap_gene_at += 1
            # 生成新点
            is_even = self.trap_gene_at % 2 == 0
            self.get_traps_points(is_even)
            # 生成新陷阱
            for p in self.points:
                an_effect = EffectInstance(self.trap_dict[is_even][0], self.user, False,
                                           level.current_level.effects_behind)
                an_effect.set_xy(p[0], p[1])
                self.effect_instances.append(an_effect)
            sound_player.play("X27_01")

    def get_traps_points(self, is_even: bool):
        grid = level.current_level.district_square_grid
        list_odd = list()
        list_even = list()
        for x in range(grid["x1"], grid["x2"] + 1):
            for y in range(grid["y1"], grid["y2"] + 1):
                if x % 2 == 0 and y % 2 == 0 or x % 2 == 1 and y % 2 == 1:
                    list_even.append((x, y))
                else:
                    list_odd.append((x, y))
        if is_even:
            self.points = list_even
        else:
            self.points = list_odd

    def kill(self):
        super().kill()
        self.user.rooted -= 1


class BloodAccelerate(Skill):

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.accelerate = [True, True, True, True]

    def update(self):
        super().update()
        if self.user.remain_blood <= 0.8 * self.user.blood and self.accelerate[0]:
            self.accelerate[0] = False
            self.user.speed += 0.08
            self.user.defense += 3500
        if self.user.remain_blood <= 0.6 * self.user.blood and self.accelerate[1]:
            self.accelerate[1] = False
            self.user.speed += 0.02
            self.user.defense += 3500
        if self.user.remain_blood <= 0.4 * self.user.blood and self.accelerate[2]:
            self.accelerate[2] = False
            self.user.speed += 0.02
            self.user.defense += 3500
        if self.user.remain_blood <= 0.2 * self.user.blood and self.accelerate[3]:
            self.accelerate[3] = False
            self.user.speed += 0.02


class LoomingFire(Skill):

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.grid = level.current_level.district_square_grid
        self.grid_damage = list()
        self.outer = True
        self.looming = True
        self.looming_at = 0
        self.last_looming_time = 0

    def update(self):
        super().update()
        if self.user.remain_blood <= 0:
            self.kill()
            return
        if self.user.remain_blood <= 0.3 * self.user.blood and self.outer:
            self.outer = False
            for x in range(self.grid["x1"], self.grid["x2"] + 1):
                for y in range(self.grid["y1"], self.grid["y2"] + 1):
                    if x == self.grid["x1"] or x == self.grid["x2"] or y == self.grid["y1"] or y == self.grid["y2"]:
                        an_effect = EffectInstance("got_fire_1", self.user, False, level.current_level.effects_behind)
                        an_effect.set_xy(x, y)
                        self.effect_instances.append(an_effect)
                        self.grid_damage.append((x, y))
        if self.user.remain_blood <= 0.1 * self.user.blood and self.looming:
            self.looming = False
            self.last_looming_time = self.current_time
        if not self.looming and self.current_time - self.last_looming_time > 2000:
            self.looming_at += 1
            self.last_looming_time = self.current_time
            for x in range(self.grid["x1"] + self.looming_at, self.grid["x2"] + 1 - self.looming_at):
                for y in range(self.grid["y1"] + self.looming_at, self.grid["y2"] + 1 - self.looming_at):
                    if self.grid["x1"] + self.looming_at >= self.grid["x2"] - self.looming_at + 1 or self.grid["y1"] + self.looming_at >= self.grid["y2"] - self.looming_at + 1:
                        break
                    if x == self.grid["x1"] + self.looming_at or x == self.grid["x2"] - self.looming_at or +\
                            y == self.grid["y1"] + self.looming_at or y == self.grid["y2"] - self.looming_at:
                        an_effect = EffectInstance("got_fire_2", self.user, False, level.current_level.effects_behind)
                        an_effect.set_xy(x, y)
                        self.effect_instances.append(an_effect)
                        self.grid_damage.append((x, y))
        if (self.to.x, self.to.y) in self.grid_damage:
            self.to.try_damage(1000)


class SpawnMinions(Skill):

    def __init__(self, user, to, skill_params, skill_instances):
        self.grid_list = list()
        super().__init__(user, to, skill_instances)
        self.skill_params = skill_params
        self.loaded = True
        self.loaded_eff = None
        self.spawned = True

    def load(self):
        super().load()
        grid = level.current_level.district_square_grid
        for x in range(grid["x1"], grid["x2"] + 1):
            for y in range(grid["y1"], grid["y2"] + 1):
                self.grid_list.append((x, y))
        random.shuffle(self.grid_list)

    def update(self):
        super().update()
        if self.loaded:
            self.loaded = False
            if len(self.skill_params) == 0:
                self.skill_params = ["JourneyBatMinion", 4, True]
            self.loaded_eff = EffectInstance("launch2", self.user, False, self.user.effects_behind)
            self.user.rooted += 1
            sound_player.play("launch")
        if self.current_time - self.skill_time_init > 800 and self.spawned:
            self.spawned = False
            self.user.rooted -= 1
            self.loaded_eff.state = EffectState.DEAD
            cl = level.current_level
            for i in range(self.skill_params[1]):
                an_npc = cl.get_an_npc(self.skill_params[0], (self.user.x, self.user.y))
                cl.npcs.append(an_npc)
                if self.skill_params[2]:
                    point = self.grid_list.pop()
                    an_npc.throw_to(point[0], point[1], self.get_directions(point), True)

    def get_directions(self, to_p):
        user_p = [self.user.x, self.user.y]
        if user_p[0] == to_p[0]:
            if user_p[1] > to_p[1]:
                return "U"
            else:
                return "D"
        if to_p[0] > user_p[0]:
            return "R"
        else:
            return "L"


class MinionChase(Skill):

    # 自身跳向玩家所在的格子

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.to_xy = None
        self.recording = True
        self.jumping = True

    def load(self):
        super().load()
        self.user.rooted_for(600)
        EffectInstance("surprise", self.user, True, self.user.effects_front)

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1000:
            self.kill()
        if self.current_time - self.skill_time_init > 600 and self.jumping:
            self.jumping = False
            self.user.throw_to(self.to_xy[0], self.to_xy[1], self.get_directions(), True)
        if self.current_time - self.skill_time_init > 400 and self.recording:
            self.recording = False
            self.to_xy = (self.to.x, self.to.y)

    def get_directions(self):
        user_p = [self.user.x, self.user.y]
        if user_p[0] == self.to_xy[0]:
            if user_p[1] > self.to_xy[1]:
                return "U"
            else:
                return "D"
        if self.to_xy[0] > user_p[0]:
            return "R"
        else:
            return "L"

