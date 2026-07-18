import enum

import pygame

from game.const import game as G
from game.level import level
from game.sprite.updatable import Updatable


class ObstacleInstance(Updatable):

    def __init__(self, x, y, obstacle_instances_dict: dict, obstacle):
        super(ObstacleInstance, self).__init__(x, y)

        self.obstacle = obstacle
        self.state = ObstacleState.NORMAL
        self.obstacle_can_hide = False
        self.obstacle_is_background = False
        self.obstacle_can_push = False
        self.obstacle_trigger = False
        self.obstacle_instances_dict: dict = obstacle_instances_dict
        self.has_drawn = False  # 当前帧已经draw过了，避免长宽大于1的障碍在1帧中多次draw，在update中复原
        self.has_updated = False  # 当前帧已经update过了，避免长宽大于1的障碍在1帧中多次update，在draw中复原

        self.is_pushing = 0  # 当前是否正在推？每帧先False一次，如果正在推就再True，这样push方法就觉得“推”是连续的
        self.push_begin = 0
        self.push_time = 500
        self.contact_damage = 0  # 接触伤害

        self.setup()

        self.obstacle_timer = 0  # obstacle帧计时器
        self.obstacle_frame_idx = 0  # obstacle帧索引
        self.cx = self.cy = 0  # obstacle显示的偏移

        self.image = pygame.Surface((1, 1))
        self.rect = self.image.get_rect()
        self.update()

    def setup(self):

        # 添加obstacle_instances字典映射
        for x in range(self.obstacle["WIDTH"]):
            for y in range(self.obstacle["HEIGHT"]):
                self.obstacle_instances_dict[(x + self.x), (y + self.y)] = self

        # 添加block三维数组
        for orient in range(2):
            for x in range(len(self.obstacle["BLOCK"][orient])):
                for y in range(len(self.obstacle["BLOCK"][orient][x])):
                    level.current_level.block[orient][x + self.x][y + self.y] += self.obstacle["BLOCK"][orient][x][y]
                    level.current_level.block_flame[orient][x + self.x][y + self.y] += self.obstacle["BLOCK_FLAME"][orient][x][y]

        if self.obstacle["CAN_HIDE"]:
            self.obstacle_can_hide = True

        if "SLIDE" in self.obstacle.keys():
            level.current_level.slide_orientation[(self.x, self.y)] = (self.obstacle["SLIDE"][0], self.obstacle["SLIDE"][1])

        if "TRIGGER" in self.obstacle:
            self.obstacle_trigger = True

        if "BACKGROUND" in self.obstacle.keys() and self.obstacle["BACKGROUND"]:
            self.obstacle_is_background = True

        if "CAN_PUSH" in self.obstacle.keys() and self.obstacle["CAN_PUSH"]:
            self.obstacle_can_push = True
            if "PUSH_TIME" in self.obstacle.keys():
                self.push_time = int(self.obstacle["PUSH_TIME"])

        if "CONTACT" in self.obstacle.keys():
            self.contact_damage = int(self.obstacle["CONTACT"])

    def trigger(self):
        # 激活障碍
        if "TRIGGER" not in self.obstacle:
            return
        if self.state == ObstacleState.DEAD or self.state == ObstacleState.DYING:
            return
        self.switch_state(ObstacleState.TRIGGERING)

    def update(self):
        if self.state == ObstacleState.DEAD:
            return
        if not self.has_updated:
            current_time = level.current_level.current_time
            self.update_frame(current_time)
            self.update_push()
            self.update_contact_damage()
            self.has_updated = True
            self.has_drawn = False

    def update_frame(self, current_time):
        if current_time - self.obstacle_timer > self.obstacle["INTERVAL"]:
            category = self.get_category()
            LEN = len(self.obstacle[category])
            if LEN == 0:
                self.frame_loop()
                return
            if self.obstacle_frame_idx + 1 == LEN:
                self.frame_loop()
            self.obstacle_frame_idx = (self.obstacle_frame_idx + 1) % LEN
            self.cx = self.obstacle[category][self.obstacle_frame_idx].cx
            self.cy = self.obstacle[category][self.obstacle_frame_idx].cy
            self.obstacle_timer = current_time
            self.image = self.obstacle[category][self.obstacle_frame_idx].image
            self.rect.x = self.x * G.GAME_SQUARE + self.obstacle[category][self.obstacle_frame_idx].cx
            self.rect.y = self.y * G.GAME_SQUARE + self.obstacle[category][self.obstacle_frame_idx].cy

    def push(self, direction):
        if self.state == ObstacleState.DYING or self.state == ObstacleState.DEAD:
            return
        # 由player调用，主动推障碍物
        if not self.obstacle_can_push:
            return
        # 障碍物接触伤害
        level.current_level.me.try_damage(self.contact_damage)
        if self.is_pushing == 0:
            self.is_pushing = 1  # 防止下面的update_push方法将push_begin归零
            self.push_begin = pygame.time.get_ticks()  # 开始计时
            self.switch_state(ObstacleState.PUSHING)
        self.is_pushing += 1
        if pygame.time.get_ticks() - self.push_begin >= self.push_time:
            # 达到阈值时间
            if direction == 'R':
                if (self.x + 1, self.y) not in self.obstacle_instances_dict and len(level.current_level.get_bomb_instance(self.x + 1, self.y)) == 0:
                    self.uninstall()
                    self.x += 1
                    self.setup()
            elif direction == 'U':
                if (self.x, self.y - 1) not in self.obstacle_instances_dict and len(level.current_level.get_bomb_instance(self.x, self.y - 1)) == 0:
                    self.uninstall()
                    self.y -= 1
                    self.setup()
            elif direction == 'L':
                if (self.x - 1, self.y) not in self.obstacle_instances_dict and len(level.current_level.get_bomb_instance(self.x - 1, self.y)) == 0:
                    self.uninstall()
                    self.x -= 1
                    self.setup()
            elif direction == 'D':
                if (self.x, self.y + 1) not in self.obstacle_instances_dict and len(level.current_level.get_bomb_instance(self.x, self.y + 1)) == 0:
                    self.uninstall()
                    self.y += 1
                    self.setup()
            level.current_level.obstacle_instances_need_to_update = True

    def update_push(self):
        if not self.obstacle_can_push:
            return
        if self.is_pushing == 0:
            self.push_begin = 0
            self.switch_state(ObstacleState.NORMAL)
        else:
            self.is_pushing -= 1

    def update_contact_damage(self):
        if self.state == ObstacleState.DYING or self.state == ObstacleState.DEAD:
            return
        if not self.obstacle_can_push:
            return
        me = level.current_level.me
        if me.x == self.x and me.y == self.y:
            me.try_damage(self.contact_damage)

    def get_category(self):
        # 根据obstacle状态枚举 获取帧类型str
        category = "STAND"
        if self.state == ObstacleState.DYING:
            category = "DIE"
        if self.state == ObstacleState.TRIGGERING:
            category = "TRIGGER"
        if self.state == ObstacleState.PUSHING:
            if "PUSH" not in self.obstacle:
                category = "STAND"  # 避免PUSH没有对应帧序列
            else:
                category = "PUSH"
        return category

    def frame_loop(self):
        # 帧循环即将回到第1帧
        if self.state == ObstacleState.DYING:
            self.switch_state(ObstacleState.DEAD)
            self.uninstall()
            level.current_level.obstacle_instances_need_to_update = True
        if self.state == ObstacleState.TRIGGERING:
            self.switch_state(ObstacleState.NORMAL)

    def switch_state(self, new_state):
        if self.state == ObstacleState.DYING and new_state != ObstacleState.DEAD:
            return  # 如果当前在DYING但是新状态非DEAD，则不允许切换状态
        # 切换到指定状态 并重置帧索引
        self.state = new_state
        self.obstacle_frame_idx = -1
        self.obstacle_timer = 0

    def die(self):
        # 摧毁障碍 尝试进入DYING状态
        if self.state == ObstacleState.DEAD or self.state == ObstacleState.DYING:
            return
        if self.obstacle["BREAKABLE"] is False:
            return
        self.switch_state(ObstacleState.DYING)
        self.obstacle_can_hide = False

    def draw(self, screen: pygame.Surface):
        if not self.has_drawn:
            super().draw(screen)
            self.has_updated = False
            self.has_drawn = True

    def get_y(self):
        if not self.obstacle_is_background:
            return super().get_y()
        else:
            return 0

    def uninstall(self):

        # 取消obstacle_instances字典映射
        for x in range(self.obstacle["WIDTH"]):
            for y in range(self.obstacle["HEIGHT"]):
                self.obstacle_instances_dict.pop((x + self.x, y + self.y))

        for orient in range(2):
            for x in range(len(self.obstacle["BLOCK"][orient])):
                for y in range(len(self.obstacle["BLOCK"][orient][x])):
                    level.current_level.block[orient][x + self.x][y + self.y] -= self.obstacle["BLOCK"][orient][x][y]
                    level.current_level.block_flame[orient][x + self.x][y + self.y] -= self.obstacle["BLOCK_FLAME"][orient][x][y]

        if "SLIDE" in self.obstacle.keys():
            del level.current_level.slide_orientation[(self.x, self.y)]

        level.current_level.recal_npc_paths = True


class ObstacleState(enum.Enum):
    DEAD = -2
    DYING = -1
    NORMAL = 0
    TRIGGERING = 1
    PUSHING = 2
