import enum
import json
import pygame
import os
import sys

from game.const import game as G
from game.const import color as C
from game.frame import character
from game.level import level
from game.skill.skill import Protect3s
from game.sprite import updatable


class Player(updatable.Updatable):

    shadow = None

    def __init__(self, character_name, xy, color=C.CHARACTER_RED):
        super(Player, self).__init__(*xy)

        self.color = color
        self.state = PlayerState.NORMAL
        self.x_old, self.y_old = xy
        self.x_y_changed_trigger = False  # x或y发生变化的标志位

        self.walking = self.walking_old = False
        self.orientation = "D"
        self.orientation_old = ""
        self.motion_changed = False
        self.update_time_old = pygame.time.get_ticks()  # 上次update的时刻

        self.blood = 0  # 玩家血量
        self.self_damage_blood = 0  # 临界值
        self.speed = 0  # 玩家移动速度（pixel/ms）
        self.defense = 0  # 玩家防御力
        self.protected = 0  # 正在受金钟罩保护
        self.remain_blood = 0  # 当前玩家剩余血量
        self.district_locked = False  # 当前区域 是否锁住玩家

        self.slow = 0  # 大于0时减速
        self.slow_begin = 0  # 减速开始时刻ms
        self.slow_duration = 0  # 减速持续时间
        self.slow_speed = 0  # 损失的速度
        self.rooted = 0  # 大于0时定身 方向键无效
        self.rooted_begin = 0  # 时长定身开始时刻ms
        self.rooted_duration = 0  # 时长定身持续时间ms
        self.reverse = 0  # 大于0时反向 方向键倒置
        self.reverse_begin = 0
        self.reverse_duration = 0
        self.polymorph = 0  # 大于0时变形
        self.polymorph_begin = 0
        self.polymorph_duration = 0
        self.get_damage_frame = False  # 受到伤害帧
        self.temporary_alpha = 255  # 临时透明度
        self.can_kick = False  # 可以踢糖泡
        self.slide_forces = dict()  # 玩家滑动力，id --> (m, n)
        self.skill_names = list()  # 技能名
        self.skill_init_times = list()  # 技能初始可以施放时刻tick
        self.skill_intervals = list()  # 技能冷却时间ms
        self.skill_remains = list()  # 技能剩余次数 -1表示无限
        self.skill_params = list()  # 技能自定义参数
        self.skill_instances = list()  # 玩家当前技能
        self.effects_behind = list()
        self.effects_front = list()
        self.allow_footprint = False  # 启用脚印追踪
        self.footprint_instances = list()  # 脚印对象列表

        self.character = None

        self.character_frame_idxs = dict()  # 组件当前帧
        self.character_frame_timers = dict()  # 组件当前帧计时器
        self.character_frame_intervals = dict()  # 组件当前帧间隔
        self.character_frame_intervals_stand = dict()  # 组件当前帧间隔stand
        self.character_frame_intervals_walk = dict()  # 组件当前帧间隔walk
        self.character_frame_trigger = False  # 重新显示character的标志位
        self.cx = self.cy = 0  # character显示的偏移
        self.STAND = ""
        self.text_font = pygame.font.Font(self.get_file("res/font/simsun.ttc"), 13)
        self.text_img = None
        self.text_init_time = 0
        self.text_duration = 0

        self.image = pygame.Surface((1, 1))
        self.rect = self.image.get_rect()

        if Player.shadow is None:
            Player.shadow = pygame.image.load(self.get_file("res/img/misc/misc131_stand_0_0.png")).convert_alpha()

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

    def load_character(self, character_name, color, decorations: dict, is_ghost=False):
        # 加载角色character
        with open(self.get_file("game/frame/character/" + character_name + ".json")) as f:
            character_json = json.load(f)
        t = pygame.time.get_ticks()
        for component in character.CHARACTER_COMPONENTS["D"]:
            # 初始化帧、帧计时器、帧间隔
            self.character_frame_idxs[component] = 0
            self.character_frame_timers[component] = t
            self.character_frame_intervals[component] = character_json["INTERVAL"]
            self.character_frame_intervals_stand[component] = 200
            self.character_frame_intervals_walk[component] = 100
            if component in decorations:
                self.character_frame_intervals[component] = decorations[component]["INTERVAL"]
                self.character_frame_intervals_stand[component] = 200
                self.character_frame_intervals_walk[component] = 100

        return character.get_character(character_json, color, decorations, is_ghost)

    def align_xy(self):
        # 标齐当前xy 用于npc和玩家施法立正
        self.set_xy(self.x, self.y)

    def set_xy(self, x, y):
        self.x = x
        self.y = y
        self.x_pos = x * G.GAME_SQUARE + G.HALF_GAME_SQUARE
        self.y_pos = y * G.GAME_SQUARE + G.HALF_GAME_SQUARE

    def set_motion(self, motion=None):
        # 设置人物运动状态motion 可以是R U L D None
        if motion is None or motion == "None" or self.speed == 0:
            self.walking = False
            self.motion_changed = False
            return
        if self.rooted > 0:
            return
        if self.reverse > 0:
            if motion == "U":
                motion = "D"
            elif motion == "D":
                motion = "U"
            elif motion == "L":
                motion = "R"
            elif motion == "R":
                motion = "L"
        self.motion_changed = not self.walking or self.orientation != motion
        self.walking = True
        self.orientation = motion

    def set_text(self, text, duration):
        self.text_img = self.text_font.render(text, True, G.PLAYER_TEXT_COLOR)
        self.text_init_time = pygame.time.get_ticks()
        self.text_duration = duration

    def stimulate_character_frame_trigger(self):
        # 判断运动状态是否发生改变，每一帧都必须调用，修改trigger值，并更新old值
        if self.orientation_old != self.orientation or self.walking_old != self.walking:
            self.character_frame_trigger = True
        else:
            self.character_frame_trigger = False
        self.orientation_old = self.orientation
        self.walking_old = self.walking

    def stimulate_x_y_changed_trigger(self):
        # 判断x或y坐标发生变化的标志，每一帧都必须调用，修改trigger值，并更新old值
        if self.x != self.x_old or self.y != self.y_old:
            self.x_y_changed_trigger = True
            if self.allow_footprint and self.polymorph == 0:  # 添加一个脚印
                self.footprint_instances.append(FootprintInstance(self.x_pos - 20, self.y_pos - 10, self.orientation))
        else:
            self.x_y_changed_trigger = False
        self.x_old = self.x
        self.y_old = self.y

    def update(self):

        current_time = pygame.time.get_ticks()
        if self.state == PlayerState.NORMAL:
            self.update_footprints(current_time)
            self.stimulate_x_y_changed_trigger()
            self.update_frame(current_time)
            self.update_pos()
            self.if_obstacle_trigger()
            self.if_take_item()
            self.check_slow_time(current_time)
            self.check_rooted_time(current_time)
            self.check_reverse_time(current_time)
            self.check_polymorph_time(current_time)
        if self.state == PlayerState.LOSE:
            self.update_frame_dead(current_time)
        self.update_skills()
        self.update_effects()
        self.get_damage_frame = False  # 复原伤害帧
        self.grid_damage(current_time)
        self.stimulate_character_frame_trigger()
        self.update_time_old = current_time

    def update_footprints(self, current_time):
        if self.polymorph > 0:
            return
        for a_footprint in self.footprint_instances:
            if current_time - a_footprint.frame_timer > 100:
                a_footprint.frame_timer = current_time
                a_footprint.frame_idx += 1
                if a_footprint.frame_idx == len(self.character["STAND_" + a_footprint.orient]["Footprint"]):
                    self.footprint_instances.remove(a_footprint)

    def update_skills(self):
        for s in self.skill_instances:
            s.update()

    def update_effects(self):
        # 刷新玩家技能
        for e in self.effects_behind:
            e.update()
        for e in self.effects_front:
            e.update()

    def update_frame(self, current_time):

        if self.walking:
            self.character_frame_intervals = self.character_frame_intervals_walk
        else:
            self.character_frame_intervals = self.character_frame_intervals_stand

        for component in self.character_frame_idxs.keys():
            if component not in self.character[self.STAND + self.orientation]:
                continue
            if self.motion_changed:
                self.character_frame_idxs[component] = 0
            if self.character_frame_trigger or current_time - self.character_frame_timers[component] > self.character_frame_intervals[component]:
                # 如果 (1)时间到 或 (2)运动发生改变 则切换帧
                STAND = ""
                if not self.walking:
                    STAND = "STAND_"
                self.STAND = STAND
                self.cx = self.character[STAND + self.orientation]["Cx"]
                self.cy = self.character[STAND + self.orientation]["Cy"]
                self.character_frame_idxs[component] = (self.character_frame_idxs[component] + 1) % len(self.character[STAND + self.orientation][component])
                self.character_frame_timers[component] = current_time

        self.rect.x = self.x_pos + self.cx
        self.rect.y = self.y_pos + self.cy
        # 注意 self.image是每隔INTERVAL更新一次 而self.rect的x,y是每帧更新一次

    def update_frame_dead(self, current_time):
        if "LOSE" not in self.character:
            return
        for component in self.character_frame_idxs.keys():
            if component not in self.character["LOSE"]:
                continue
            if current_time - self.character_frame_timers[component] > 200:
                self.cx = self.character["LOSE"]["Cx"]
                self.cy = self.character["LOSE"]["Cy"]
                self.character_frame_idxs[component] = (self.character_frame_idxs[component] + 1) % len(self.character["LOSE"][component])
                self.character_frame_timers[component] = current_time
        self.rect.x = self.x_pos + self.cx
        self.rect.y = self.y_pos + self.cy

    def update_pos(self):

        if self.rooted > 0:
            self.set_motion()

        cl = level.current_level
        block = cl.block

        # 主动移动
        if self.walking:
            speed = self.speed * (pygame.time.get_ticks() - self.update_time_old)  # self.speed 是每毫秒的移动步长，要乘上time
            speed = min(20, speed)  # 防止卡进墙壁里
            if self.motion_changed:
                speed *= G.FIRST_FRAME_SHORTEN_RATE
            right, right_grid, top, top_grid, left, left_grid, bottom, bottom_grid = self.get_ruld_block()
            if self.orientation == "R":
                self.movement_right(self.district_locked, speed, top, bottom, right, block, top_grid, bottom_grid, cl)
            if self.orientation == "U":
                self.movement_up(self.district_locked, speed, top, left, right, block, left_grid, right_grid, cl)
            if self.orientation == "L":
                self.movement_left(self.district_locked, speed, top, bottom, left, block, top_grid, bottom_grid, cl)
            if self.orientation == "D":
                self.movement_down(self.district_locked, speed, bottom, left, right, block, left_grid, right_grid, cl)
            self.x, self.y = updatable.current_grid(self.x_pos, self.y_pos)

        # 传送带移动
        if (self.x, self.y) in cl.slide_orientation.keys():
            right, right_grid, top, top_grid, left, left_grid, bottom, bottom_grid = self.get_ruld_block()
            orientation, slide_speed = cl.slide_orientation[(self.x, self.y)]
            self.slide(self.update_time_old, self.district_locked, orientation, slide_speed, top, bottom, left, right, block, top_grid, bottom_grid, left_grid, right_grid, cl)

        # 受力移动
        for orientation, slide_speed in self.slide_forces.values():
            right, right_grid, top, top_grid, left, left_grid, bottom, bottom_grid = self.get_ruld_block()
            self.slide(self.update_time_old, self.district_locked, orientation, slide_speed, top, bottom, left, right, block, top_grid, bottom_grid, left_grid, right_grid, cl)

        self.x, self.y = updatable.current_grid(self.x_pos, self.y_pos)

    def if_obstacle_trigger(self):
        # 判断player是否激活障碍
        if self.x_y_changed_trigger is not True:
            return  # 必须在xy发生变化的那一帧激活障碍
        ois = level.current_level.obstacle_instances
        if (self.x, self.y) in ois.keys():
            an_obstacle = ois[(self.x, self.y)]
            if an_obstacle.obstacle_trigger:
                an_obstacle.trigger()

    def if_take_item(self):
        # player获取item
        if self.x_y_changed_trigger is not True:
            return False
        if (self.x, self.y) in level.current_level.item_instances:
            level.current_level.item_instances[(self.x, self.y)].player_get(self)
            return True
        return False

    def grid_damage(self, current_time):
        # 每一帧都尝试吸收当前地板上的伤害，如果时间值相同（在同一帧），则造成伤害
        point = (self.x, self.y)
        cl = level.current_level
        if point[0] < 0 or point[1] < 0:
            return
        if cl.grid_damage_frame >= 0 and current_time - cl.grid_damage_time[point] < cl.accumulation_time:
            self.half_body_damage(point, cl, current_time)

    def half_body_damage(self, point, cl, current_time):
        pass

    def try_damage(self, damage_blood: int, direction="C"):
        if self.state != PlayerState.NORMAL:
            return
        if self.protected > 0:
            return
        if damage_blood > self.defense:
            self.real_damage(damage_blood - self.defense)

    def real_damage(self, damage_blood: int):
        # 真实对玩家扣减damage_blood血量
        self.remain_blood -= max(damage_blood, self.self_damage_blood)
        self.self_damage_blood = 0  # 临界值归零
        if self.remain_blood <= 0:
            # 角色死亡
            self.remain_blood = 0
            self.switch_state(PlayerState.LOSE)
            self.die()
            return
        if not self.protected > 0:
            Protect3s(self, self.skill_instances)
        if damage_blood > 0:
            self.set_text("HP-" + str(damage_blood), 2000)
            self.get_damage_frame = True

    def die(self):
        self.polymorph = 0
        self.footprint_instances.clear()
        for component in self.character_frame_idxs.keys():
            self.character_frame_idxs[component] = 0

    def revive(self, heal_blood: int):
        # 人物复活
        self.switch_state(PlayerState.NORMAL)
        self.heal(heal_blood)
        self.real_damage(0)

    def heal(self, heal_blood: int):
        if self.state != PlayerState.NORMAL:
            return
        # 血量恢复
        self.remain_blood = min(self.blood, self.remain_blood + heal_blood)
        # 破临界值
        self.remain_blood -= self.self_damage_blood
        self.self_damage_blood = 0

    def slow_for(self, duration, speed_rate):
        # slow_rate介于0-1之间
        if self.slow_begin != 0:
            return
        self.slow += 1
        self.slow_begin = pygame.time.get_ticks()
        self.slow_duration = duration
        self.slow_speed = speed_rate * self.speed
        self.speed -= self.slow_speed

    def check_slow_time(self, current_time):
        if self.slow_begin != 0 and current_time - self.slow_begin > self.slow_duration:
            self.slow -= 1
            self.slow_begin = 0
            self.speed += self.slow_speed

    def rooted_for(self, duration):
        if self.rooted_begin == 0:
            self.rooted += 1
        self.rooted_begin = pygame.time.get_ticks()
        self.rooted_duration = duration

    def check_rooted_time(self, current_time):
        if self.rooted_begin != 0 and current_time - self.rooted_begin > self.rooted_duration:
            self.rooted -= 1
            self.rooted_begin = 0

    def reverse_for(self, duration):
        if self.reverse_begin != 0:
            return
        self.reverse += 1
        self.reverse_begin = pygame.time.get_ticks()
        self.reverse_duration = duration

    def check_reverse_time(self, current_time):
        if self.reverse_begin != 0 and current_time - self.reverse_begin > self.reverse_duration:
            self.reverse -= 1
            self.reverse_begin = 0

    def polymorph_for(self, duration):
        # Player重写变形
        pass

    def check_polymorph_time(self, current_time):
        # Player重写变形时间检查
        pass

    def collide_wall(self):
        # Player碰撞墙体（包括糖泡）
        pass

    def collide_district(self):
        # Player碰撞区域边界
        pass

    def try_push(self, direction, offset=(0, 0)):
        pass

    def switch_state(self, new_state):
        # 切换到指定状态 并重置帧索引
        self.state = new_state
        self.character_frame_idx = 0
        self.character_frame_trigger = True
        if new_state == PlayerState.LOSE:
            for s in self.skill_instances:
                self.skill_instances.remove(s)

    def get_y(self):
        return self.y + 0.1

    def draw(self, screen: pygame.Surface):
        # 如果人物隐藏，则不绘图
        display = not super().if_hide()

        if display:
            # 显示背景特效
            for s in self.effects_behind:
                s.draw(screen)
            if self.polymorph == 0:
                for a_footprint in self.footprint_instances:
                    frame = self.character["STAND_" + a_footprint.orient]["Footprint"][a_footprint.frame_idx]
                    screen.blit(frame.image, (frame.cx + a_footprint.x_pos, frame.cy + a_footprint.y_pos))
            # 显示阴影
            Player.shadow.set_alpha(self.temporary_alpha)
            screen.blit(Player.shadow, (self.x_pos - 17, self.y_pos - 7))
            if self.state == PlayerState.NORMAL:
                for component in character.CHARACTER_COMPONENTS[self.orientation]:
                    if component not in self.character[self.STAND + self.orientation]:
                        continue
                    if self.character_frame_idxs[component] >= len(self.character[self.STAND + self.orientation][component]):
                        self.character_frame_idxs[component] = 0
                    frame = self.character[self.STAND + self.orientation][component][self.character_frame_idxs[component]]
                    frame.image.set_alpha(self.temporary_alpha)
                    screen.blit(frame.image, (frame.cx + self.x_pos + self.cx, frame.cy + self.y_pos + self.cy))
            elif self.state == PlayerState.LOSE and "LOSE" in self.character:
                for component in character.CHARACTER_COMPONENTS[self.orientation]:
                    if component not in self.character["LOSE"]:
                        continue
                    frame = self.character["LOSE"][component][self.character_frame_idxs[component]]
                    screen.blit(frame.image, (frame.cx + self.x_pos + self.cx, frame.cy + self.y_pos + self.cy))
        # 显示前景特效
        for s in self.effects_front:
            s.draw(screen)
        # 显示文字
        if pygame.time.get_ticks() - self.text_init_time < self.text_duration:
            screen.blit(self.text_img, (self.x_pos - G.HALF_GAME_SQUARE, self.y_pos - G.GAME_SQUARE - G.GAME_SQUARE))


class PlayerState(enum.Enum):

    NORMAL = 0
    WIN = 1
    LOSE = -1


class FootprintInstance:

    def __init__(self, x_pos, y_pos, orient):
        self.frame_idx = 0
        self.frame_timer = pygame.time.get_ticks()
        self.x_pos = x_pos
        self.y_pos = y_pos
        self.orient = orient
