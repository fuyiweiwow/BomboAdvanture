import json
import random

import pygame
import os
import sys

from game.algo import aStar
from game.const import color as C
from game.const import game as G
from game.frame import bomb, item
from game.level import level
from game.skill.jidi_skill import FengBaoIceSlow1x1, FengBaoSword100
from game.skill.mizhidi_skill import MiZhiDiSword500, MiZhiDiSword800, MonsterReverse, MiZhiDiThunder1x1HP800
from game.skill.npc_skill import Skill21065, Skill21069, Skill21044, Skill21049, Skill21054, Skill21087, Skill21082, \
    Skill21000, Skill21002, Skill21003, Skill21006, Skill21007, Skill21066, Skill21067, Skill21014, Skill21025, \
    Skill21027, Skill21008, Skill21011, Skill21017, Skill21018, Skill21005, Skill21019, Skill21022, Skill21072, \
    Skill21073, Skill21074
from game.skill.new_skill import RevengeDash, TemporaryHidden, PutBomb, BombEscape, ContactStun, LandQuake, \
    PermanentlyHidden, ColorfulSmoke, \
    DistantIce5x5, SlowSword, DirtyPath, NearSlow, NearAccelerate, BombJail, RevengeDash3s, BombThrowGold, \
    BombThrowBlack, IceFireSwitch, BombThrowRainRandom, BombThrowRainPlayer, LoomingFire, SpawnMinions, \
    SlowSmoke7x7, MinionChase, BloodAccelerate
from game.skill.skill import ThunderAttack, HeiLongBlackWizardPutFireTrap, \
    HeiLongBlackWizardPutIceTrap, HeiLongAbyssDragonSword, HeiLongAbyssDragonDistantFire, HeiLongAbyssDragonCharge, \
    HeiLongDistantFire5x5, HeiLongDistantFire3x3, HeiLongDizzy9x9, \
    HeiLongThunder3x3HP800, HeiLongRedWizardPutFireTrap, HeiLongReverse, BloodElixirMiddle, \
    HeiLongFloatingFire, HeiLongHellDragonDistantFire, HeiLongHellDragonCharge, HeiLongHellDragonScope, \
    HeiLongAbyssDragonRecovery, HeiLongPutFireTrap, HeiLongSkeletonKnightPutThunderTrap, HeiLongSkeletonKnightEnhance, \
    HeiLongPutIceTrap, Protect3s
from game.sound import sound_player
from game.sprite.bomb_instance import BombInstance
from game.sprite.ghost import Ghost
from game.sprite.hero import Hero
from game.sprite.item_instance import ItemInstance
from game.sprite.player import Player, PlayerState
from game.sprite.throwable import Throwable


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

class Npc(Player, Throwable):

    def __init__(self, npc_name, xy, color=C.CHARACTER_RED):
        super(Npc, self).__init__(npc_name, xy, color)
        self.npc_json = None
        self.chs_name = None  # Npc中文名
        self.idx_motion = {0: "R", 1: "U", 2: "L", 3: "D"}
        self.contact = 0  # Npc接触伤害
        self.resent_dist = None  # Npc仇恨范围（几格以内）
        self.resentful = False  # Npc玩家仇恨
        self.mocking = False  # Npc受到嘲笑药水的作用暂时仇恨
        self.friendly = False  # Npc受到玫瑰药水的作用暂时解除仇恨
        self.boss_mode = False  # Boss模式
        self.npc_time_init = None  # Npc初始化时刻
        self.wander_random = 10  # Npc在无仇恨时的闲逛时间
        self.district_locked = True
        self.chase_path = None  # Npc追踪路径
        self.npc_skill_time = pygame.time.get_ticks()  # npc施放技能时的时刻 设为成员变量是为了统一多个技能的时间
        self.chs_name_bg = pygame.image.load(get_file("res/img/ui/game/misc171.png")).convert_alpha()  # Npc姓名牌背景
        self.chs_name_font = pygame.font.Font(get_file("res/font/simsun.ttc"), 13)  # Npc姓名牌字体
        self.chs_name_text = None  # Npc姓名牌前景文字
        self.chs_name_text_shadow = None  # Npc姓名牌背景文字
        self.chs_name_text_half_width = None  # Npc姓名牌文字的半宽 用于居中显示文字
        self.bomb_skin = bomb.get_bomb("bomb1")
        self.gifts = None  # 爆装备
        self.death = None  # 死亡状态

        self.load_npc(npc_name, color)

    def load_npc(self, npc_name, color):
        # 加载npc的json文件
        with open(get_file("game/npc/" + npc_name + ".json"), encoding="utf-8") as f:
            self.npc_json = json.load(f)
            self.chs_name = self.npc_json["chs_name"]
            self.blood = self.npc_json["blood"]
            if "self_damage_blood" in self.npc_json.keys():
                self.self_damage_blood = self.npc_json["self_damage_blood"]
            self.speed = (self.npc_json["speed"] * G.GAME_SQUARE) / 1000
            self.contact = self.npc_json["contact"]
            self.defense = self.npc_json["defense"]
            if "boss_mode" in self.npc_json.keys():
                self.boss_mode = bool(self.npc_json["boss_mode"])
            if "gifts" in self.npc_json.keys():
                self.gifts = self.npc_json["gifts"]
            if "death" in self.npc_json.keys():
                self.death = self.npc_json["death"]
            self.resent_dist = self.npc_json["resent_dist"] * G.GAME_SQUARE  # 仇恨距离（像素）
            for s in self.npc_json["skills"]:
                self.skill_names.append(s["name"])
                self.skill_init_times.append(s["init"])
                self.skill_intervals.append(s["interval"])
                self.skill_remains.append(s["max"])
                self.skill_params.append(s["params"] if "params" in s else [])

            self.remain_blood = self.blood
            self.chase_path = dict()
            self.chs_name_text = self.chs_name_font.render(self.chs_name, True, (255, 255, 0))
            self.chs_name_text_shadow = self.chs_name_font.render(self.chs_name, True, (0, 0, 0))
            self.chs_name_text_half_width = self.chs_name_text.get_width() // 2
            self.character = self.load_character(self.npc_json["character"], color, dict())
            self.npc_time_init = pygame.time.get_ticks()

    def update(self):
        super().update()
        current_time = pygame.time.get_ticks()
        if G.DISPLAY_NPC_BLOOD:
            self.update_npc_blood_display()
        self.wander_and_detect(current_time)
        self.chase_hero()
        self.contact_damage()
        self.try_using_skills()
        self.throw()

    def update_npc_blood_display(self):
        if G.DISPLAY_NPC_NAME_CARD:
            self.chs_name_text = self.chs_name_font.render(str(self.remain_blood), True, (255, 255, 0))
            self.chs_name_text_shadow = self.chs_name_font.render(str(self.remain_blood), True, (0, 0, 0))
            self.chs_name_text_half_width = self.chs_name_text.get_width() // 2

    def wander_and_detect(self, current_time):
        # 游走并检测玩家距离
        if (self.resentful or self.mocking) and not self.friendly:
            return
        # 初始化时刻小于0.3s
        if current_time - self.npc_time_init < 300:
            return
        # 随机运动时间
        if current_time % 15 == 0:
            motion = self.idx_motion[random.randint(0, 3)]
            self.set_motion(motion)
        else:
            self.set_motion(self.orientation)
        # 技能初始时间更新
        for i in range(len(self.skill_names)):
            # 游荡状态下，技能初始时间永远等于当前时刻加init值
            self.skill_init_times[i] = self.npc_json["skills"][i]["init"] + current_time
        # 检测与玩家的距离
        me: Hero = level.current_level.me
        if me.district_locked and me.state == PlayerState.NORMAL:
            if abs(me.x_pos - self.x_pos) < self.resent_dist and abs(me.y_pos - self.y_pos) < self.resent_dist:
                # 如果玩家活着、已进入区域锁，并且距离小于临界值 则产生玩家仇恨
                self.resentful = True
                level.current_level.recal_npc_paths = True

    def chase_hero(self):
        if not self.resentful and not self.mocking or self.friendly:
            return
        me = (level.current_level.me.x, level.current_level.me.y)
        # 玩家在糖泡中 定身Npc
        if len(level.current_level.get_bomb_instance(*me)) > 0:
            self.set_motion()
            return
        now = (self.x, self.y)
        # 如果重新计算路径标志为True则重新追踪玩家
        if level.current_level.recal_npc_paths:
            self.chase_path = aStar.cal_path(
                now, me,
                (level.current_level.district_square_grid["x1"], level.current_level.district_square_grid["y1"]),
                (level.current_level.district_square_grid["x2"], level.current_level.district_square_grid["y2"])
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

    def half_body_damage(self, point, cl, current_time):
        self.try_damage(cl.grid_damage_blood[point])

    def contact_damage(self):
        # 检查npc与人物的接触伤害
        if level.current_level.me.x == self.x and level.current_level.me.y == self.y:
            level.current_level.me.try_damage(self.contact, "C")

    def die(self):
        super().die()
        sound_player.play("npc_dead")
        self.gene_gifts()
        self.gene_ghost()

    def gene_gifts(self):
        if self.gifts is None:
            return
        cl = level.current_level
        for gift in self.gifts:
            rand = gift["possibility"] - random.uniform(0, 1)
            if rand > 0:
                grids = list()
                for x in range(max(0, self.x - 2), min(self.x + 3, cl.map_x_pos)):
                    for y in range(max(0, self.y - 2), min(self.y + 3, cl.map_y_pos)):
                        a = (x, y) not in cl.obstacle_instances.keys()
                        b = (x, y) not in cl.item_instances.keys()
                        if a and b and len(cl.get_bomb_instance(x, y)) == 0:
                            grids.append((x, y))
                if len(grids) == 0:
                    continue
                random.shuffle(grids)
                point = grids[0]
                an_item = ItemInstance(self.x, self.y, level.current_level.item_instances, item.get_item(gift["name"]))
                an_item.throw_to(point[0], point[1], an_item.get_direction(point[0], point[1]))

    def gene_ghost(self):
        if self.death is None:
            return
        for gene in self.death:
            if "ghost" in gene.keys():
                # 生成幽灵Ghost，指定生存时间，速度，接触伤害（自身无敌 + 穿墙穿泡、无视区域）
                level.current_level.ghosts.append(
                    Ghost(gene["name"], (self.x, self.y), gene["ghost"]["time"],
                          gene["ghost"]["speed"], gene["ghost"]["contact"]))
            else:
                # 生成普通Npc，并给予无敌防护
                an_npc = Npc(gene["name"], (self.x, self.y))
                Protect3s(an_npc, an_npc.skill_instances)
                level.current_level.npcs.append(an_npc)

    def collide_wall(self):
        # npc 游走时撞墙 则改变方向
        if self.orientation == "U":
            self.set_motion("D")
        if self.orientation == "D":
            self.set_motion("U")
        if self.orientation == "L":
            self.set_motion("R")
        if self.orientation == "R":
            self.set_motion("L")

    def try_push(self, direction, offset=(0, 0)):
        pass

    def try_using_skills(self):
        # npc 循环使用技能
        if not self.resentful and not self.mocking or self.friendly:
            return
        # npc 技能时间更新
        self.npc_skill_time = pygame.time.get_ticks()
        # 每一帧都尝试使用全部技能
        for i in range(len(self.skill_names)):
            self.use_skill(i)

    def use_skill(self, idx: int):
        cl = level.current_level
        if self.npc_skill_time < self.skill_init_times[idx] or self.skill_remains[idx] == 0:
            # 未到初始时间 或技能冷却中 或次数已用完（-1则可以无限使用）
            return
        name = self.skill_names[idx]
        if name == "Skill21000":
            Skill21000(self, cl.me, cl.skill_instances)
        elif name == "Skill21002":
            Skill21002(self, cl.me, cl.skill_instances)
        elif name == "Skill21003":
            Skill21003(self, cl.me, cl.skill_instances)
        elif name == "Skill21005":
            Skill21005(self, cl.me, cl.skill_instances)
        elif name == "Skill21006":
            Skill21006(self, cl.me, cl.skill_instances)
        elif name == "Skill21007":
            Skill21007(self, cl.me, cl.skill_instances)
        elif name == "Skill21008":
            Skill21008(self, cl.me, cl.skill_instances)
        elif name == "Skill21011":
            Skill21011(self, cl.me, cl.skill_instances)
        elif name == "Skill21014":
            Skill21014(self, cl.me, cl.skill_instances)
        elif name == "Skill21017":
            Skill21017(self, self.skill_instances)
        elif name == "Skill21018":
            Skill21018(self, cl.me, cl.skill_instances)
        elif name == "Skill21019":
            Skill21019(self, cl.me, cl.skill_instances)
        elif name == "Skill21022":
            Skill21022(self, cl.me, cl.skill_instances)
        elif name == "Skill21025":
            Skill21025(self, cl.me, cl.skill_instances)
        elif name == "Skill21027":
            Skill21027(self, cl.me, cl.skill_instances)
        elif name == "Skill21044":
            Skill21044(self, cl.me, self.skill_instances)
        elif name == "Skill21049":
            Skill21049(self, cl.me, self.skill_instances)
        elif name == "Skill21054":
            Skill21054(self, cl.npcs, self.skill_instances)
        elif name == "Skill21065":
            Skill21065(self, cl.me, self.skill_instances)
        elif name == "Skill21066":
            Skill21066(self, cl.me, cl.skill_instances)
        elif name == "Skill21067":
            Skill21067(self, cl.me, cl.skill_instances)
        elif name == "Skill21069":
            Skill21069(self, cl.me, self.skill_instances)
        elif name == "Skill21072":
            Skill21072(self, cl.me, cl.skill_instances)
        elif name == "Skill21073":
            Skill21073(self, cl.me, cl.skill_instances)
        elif name == "Skill21074":
            Skill21074(self, cl.me, cl.skill_instances)
        elif name == "Skill21082":
            Skill21082(self, cl.me, self.skill_instances)
        elif name == "Skill21087":
            Skill21087(self, cl.me, self.skill_instances)
        elif name == "ThunderAttack":
            ThunderAttack(self, self.skill_instances)
        elif name == "BloodElixirMiddle":
            BloodElixirMiddle(self, self.skill_instances)
        elif name == "HeiLongReverse":
            HeiLongReverse(self, cl.me, cl.skill_instances)
        elif name == "HeiLongBlackWizardPutIceTrap":
            HeiLongBlackWizardPutIceTrap(self, cl.me, cl.skill_instances)
        elif name == "HeiLongBlackWizardPutFireTrap":
            HeiLongBlackWizardPutFireTrap(self, cl.me, cl.skill_instances)
        elif name == "HeiLongAbyssDragonDistantFire":
            HeiLongAbyssDragonDistantFire(self, cl.me, cl.skill_instances)
        elif name == "HeiLongAbyssDragonCharge":
            HeiLongAbyssDragonCharge(self, self.skill_instances)
        elif name == "HeiLongAbyssDragonSword":
            HeiLongAbyssDragonSword(self, [cl.me], self.skill_instances)
        elif name == "HeiLongAbyssDragonRecovery":
            HeiLongAbyssDragonRecovery(self, self.skill_instances)
        elif name == "HeiLongPutFireTrap":
            HeiLongPutFireTrap(self, cl.me, cl.skill_instances)
        elif name == "HeiLongPutIceTrap":
            HeiLongPutIceTrap(self, cl.me, cl.skill_instances)
        elif name == "HeiLongDistantFire5x5":
            HeiLongDistantFire5x5(self, [cl.me], cl.skill_instances)
        elif name == "HeiLongDistantFire3x3":
            HeiLongDistantFire3x3(self, [cl.me], cl.skill_instances)
        elif name == "HeiLongDizzy9x9":
            HeiLongDizzy9x9(self, cl.me, cl.skill_instances)
        elif name == "HeiLongThunder3x3HP800":
            HeiLongThunder3x3HP800(self, cl.me, cl.skill_instances)
        elif name == "HeiLongSkeletonKnightPutThunderTrap":
            HeiLongSkeletonKnightPutThunderTrap(self, cl.me, cl.skill_instances)
        elif name == "HeiLongSkeletonKnightEnhance":
            HeiLongSkeletonKnightEnhance(self, cl.skill_instances)
        elif name == "HeiLongRedWizardPutFireTrap":
            HeiLongRedWizardPutFireTrap(self, cl.me, cl.skill_instances)
        elif name == "HeiLongFloatingFire":
            HeiLongFloatingFire(self, cl.me, self.skill_instances)
        elif name == "HeiLongHellDragonDistantFire":
            HeiLongHellDragonDistantFire(self, cl.me, cl.skill_instances)
        elif name == "HeiLongHellDragonCharge":
            HeiLongHellDragonCharge(self, self.skill_instances)
        elif name == "HeiLongHellDragonScope":
            HeiLongHellDragonScope(self, cl.me, self.skill_instances)
        elif name == "MiZhiDiSword500":
            MiZhiDiSword500(self, [cl.me], self.skill_instances)
        elif name == "MiZhiDiSword800":
            MiZhiDiSword800(self, [cl.me], self.skill_instances)
        elif name == "MonsterReverse":
            MonsterReverse(self, cl.me, cl.skill_instances)
        elif name == "MiZhiDiThunder1x1HP800":
            MiZhiDiThunder1x1HP800(self, cl.me, cl.skill_instances)
        elif name == "FengBaoIceSlow1x1":
            FengBaoIceSlow1x1(self, cl.me, cl.skill_instances)
        elif name == "FengBaoSword100":
            FengBaoSword100(self, [cl.me], self.skill_instances)
        elif name == "RevengeDash":
            RevengeDash(self, self.skill_instances)
        elif name == "RevengeDash3s":
            RevengeDash3s(self, self.skill_instances)
        elif name == "TemporaryHidden":
            TemporaryHidden(self, cl.me, self.skill_instances)
        elif name == "PermanentlyHidden":
            PermanentlyHidden(self, cl.me, self.skill_instances)
        elif name == "PutBomb":
            PutBomb(self, self.skill_instances)
        elif name == "BombJail":
            BombJail(self, cl.me, self.skill_instances)
        elif name == "BombThrowGold":
            BombThrowGold(self, cl.me, self.skill_instances)
        elif name == "BombThrowBlack":
            BombThrowBlack(self, cl.me, self.skill_instances)
        elif name == "BombEscape":
            BombEscape(self, cl.me, self.skill_instances)
        elif name == "ContactStun":
            ContactStun(self, cl.me, self.skill_instances)
        elif name == "LandQuake":
            LandQuake(self, cl.me, self.skill_instances)
        elif name == "ColorfulSmoke":
            ColorfulSmoke(self, cl.me, self.skill_instances)
        elif name == "DistantIce5x5":
            DistantIce5x5(self, cl.me, self.skill_instances)
        elif name == "SlowSword":
            SlowSword(self, cl.me, self.skill_instances)
        elif name == "DirtyPath":
            DirtyPath(self, cl.me, cl.skill_instances)
        elif name == "NearSlow":
            NearSlow(self, cl.me, self.skill_instances)
        elif name == "NearAccelerate":
            NearAccelerate(self, cl.me, self.skill_instances)
        elif name == "SlowSmoke7x7":
            SlowSmoke7x7(self, cl.me, self.skill_instances)
        elif name == "BombThrowRainPlayer":
            BombThrowRainPlayer(self, cl.me, self.skill_instances)
        elif name == "BombThrowRainRandom":
            BombThrowRainRandom(self, cl.me, self.skill_instances)
        elif name == "IceFireSwitch":
            IceFireSwitch(self, cl.me, self.skill_instances)
        elif name == "SpawnMinions":
            SpawnMinions(self, cl.me, self.skill_params[idx], self.skill_instances)
        elif name == "BloodAccelerate":
            BloodAccelerate(self, cl.me, self.skill_instances)
        elif name == "LoomingFire":
            LoomingFire(self, cl.me, cl.skill_instances)
        elif name == "MinionChase":
            MinionChase(self, cl.me, self.skill_instances)

        self.skill_remains[idx] -= 1
        self.skill_init_times[idx] += self.skill_intervals[idx]

    def set_bomb(self):
        # npc尝试放置一个糖泡
        if self.state != PlayerState.NORMAL:
            return
        p = (self.x, self.y)
        bis = level.current_level.bomb_instances
        bs = level.current_level.get_bomb_instance(*p)
        if len(bs) > 0:  # 当前位置有糖泡
            return
        BombInstance(*p, bis, self.bomb_skin, 3, 1000)

    def set_restoration(self, to_x, to_y):
        self.x = to_x
        self.y = to_y

    def draw(self, screen: pygame.Surface):
        super().draw(screen)
        if G.DISPLAY_NPC_NAME_CARD:
            self.chs_name_bg.set_alpha(self.temporary_alpha)
            screen.blit(self.chs_name_bg, (self.x_pos - 40, self.y_pos - 100))
            self.chs_name_text_shadow.set_alpha(self.temporary_alpha)
            screen.blit(self.chs_name_text_shadow, (self.x_pos + 3 - self.chs_name_text_half_width, self.y_pos - 95))
            self.chs_name_text.set_alpha(self.temporary_alpha)
            screen.blit(self.chs_name_text, (self.x_pos + 2 - self.chs_name_text_half_width, self.y_pos - 95))
