from game.effect.effect_instance import EffectInstance
from game.level import level
from game.skill.skill import Skill


class Firework(Skill):

    def __init__(self, user, skill_instances):
        super().__init__(user, None, skill_instances)
        self.firework_type = None
        self.loaded = True

    def update(self):
        super().update()
        if self.loaded:
            self.loaded = False
            EffectInstance(self.firework_type, self.user, False, level.current_level.effects_front)
        self.kill()


class FireworkRed(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_red"


class FireworkYellow(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_yellow"


class FireworkBlue(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_blue"


class FireworkGreen(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_green"


class FireworkPurple(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_purple"


class FireworkRound(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_round"


class FireworkHeart(Firework):

    def __init__(self, user, skill_instances):
        super().__init__(user, skill_instances)
        self.firework_type = "firework_heart"
