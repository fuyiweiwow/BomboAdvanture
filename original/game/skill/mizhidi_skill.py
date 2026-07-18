from game.effect.effect_instance import EffectInstance, EffectState
from game.skill.skill import Sword5x5, Skill
from game.sound import sound_player


class MiZhiDiSword500(Sword5x5):

    def __init__(self, user, to, skill_instances):
        self.damage_blood = 500
        super().__init__(user, to, skill_instances)


class MiZhiDiSword800(Sword5x5):

    def __init__(self, user, to, skill_instances):
        self.damage_blood = 800
        super().__init__(user, to, skill_instances)


class MonsterReverse(Skill):

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


class MiZhiDiThunder1x1HP800(Skill):

    def __init__(self, user, to, skill_instances):
        super().__init__(user, to, skill_instances)
        self.loaded = True  # 0ms
        self.thunder_down = True  # 250ms
        self.thunder_explode = True  # 600ms
        self.to_xy = None  # 火焰提示时玩家的xy
        self.hit = False  # 是否命中玩家
        self.damage_blood = 800  # 击中后伤血量
        self.root_duration = 0  # 击中后眩晕时长

    def load(self):
        super().load()

    def update(self):
        super().update()
        if self.current_time - self.skill_time_init > 1000:
            self.kill()
        if self.current_time - self.skill_time_init > 600 and self.thunder_explode:
            self.thunder_explode = False
            an_effect = EffectInstance("thunder_explode", self.user, False, self.user.effects_front)
            an_effect.set_xy(self.to_xy[0], self.to_xy[1])
            self.effect_instances.append(an_effect)
            if self.hit and self.user.remain_blood > 0:
                self.to.try_damage(self.damage_blood)
                self.to.rooted_for(self.root_duration)
        if self.current_time - self.skill_time_init > 250 and self.thunder_down:
            self.thunder_down = False
            self.user.rooted -= 1
            for e in self.effect_instances:
                e.state = EffectState.DEAD
            an_effect = EffectInstance("thunder_down", self.user, False, self.user.effects_front)
            an_effect.set_xy(self.to_xy[0], self.to_xy[1])
            self.effect_instances.append(an_effect)
            # 判断是否击中玩家
            if self.to_xy[0] == self.to.x and self.to_xy[1] == self.to.y:
                self.hit = True
        if self.loaded:
            self.loaded = False
            sound_player.play("launch")
            self.user.rooted += 1
            self.user.align_xy()
            self.to_xy = (self.to.x, self.to.y)
            self.effect_instances.append(
                EffectInstance("thunder_charge", self.user, False, self.user.effects_front)
            )
            self.effect_instances.append(
                EffectInstance("thunder_trap", self.to, False, self.to.effects_behind)
            )
