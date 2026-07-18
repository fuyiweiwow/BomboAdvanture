from game.effect.effect_instance import EffectInstance, EffectState
from game.level import level
from game.skill.skill import Sword5x5, Skill
from game.sound import sound_player


class FengBaoIceSlow1x1(Skill):

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
            sound_player.play("X18_01")
            if self.hit:
                self.effect_instances.append(
                    EffectInstance("ice_slowed", self.to, True, self.to.effects_front)
                )
                sound_player.play("cry")
                self.to.speed *= 0.7
        if self.current_time - self.skill_time_init > 300 and self.ice_judge:
            self.ice_judge = False
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
                EffectInstance("ice_charge", self.user, False, self.user.effects_front)
            )
            self.effect_instances.append(
                EffectInstance("ice_hint", self.to, False, level.current_level.effects_behind)
            )


class FengBaoSword100(Sword5x5):

    def __init__(self, user, to, skill_instances):
        self.damage_blood = 100
        super().__init__(user, to, skill_instances)
