import enum
import pygame

from game.const import game as G
from game.level import level
from game.sprite.throwable import Throwable


class ItemInstance(Throwable):

    def __init__(self, x, y, item_instances_dict: dict, item):

        super(ItemInstance, self).__init__(x, y)

        self.item_instances_dict: dict = item_instances_dict
        self.item = item

        self.state = ItemState.NORMAL

        self.item_timer = 0  # item帧计时器
        self.item_frame_idx = 0  # item帧索引0
        self.cx = self.cy = 0  # item显示的偏移
        self.setup()

        self.image = pygame.Surface((1, 1))
        self.rect = self.image.get_rect()
        self.update()

    def setup(self):
        self.item_instances_dict[(self.x, self.y)] = self

    def update(self):

        if self.state == ItemState.DEAD:
            return
        current_time = pygame.time.get_ticks()
        if self.state == ItemState.NORMAL:
            self.throw()
            self.update_frame(current_time)
            self.if_hide()
        if self.state == ItemState.DYING:
            self.update_frame(current_time)

    def update_frame(self, current_time):

        category = self.get_category()
        if current_time - self.item_timer > self.item["INTERVAL"]:
            LEN = len(self.item[category])
            if LEN == 0:
                self.frame_loop()
                return
            if self.item_frame_idx + 1 == LEN:
                self.frame_loop()
            self.item_frame_idx = (self.item_frame_idx + 1) % LEN
            self.cx = self.item[category][self.item_frame_idx].cx
            self.cy = self.item[category][self.item_frame_idx].cy
            self.item_timer = current_time
            self.image = self.item[category][self.item_frame_idx].image
        self.rect.x = self.x_pos - G.HALF_GAME_SQUARE + self.item[category][self.item_frame_idx].cx
        self.rect.y = self.y_pos - G.HALF_GAME_SQUARE + self.item[category][self.item_frame_idx].cy

    def get_category(self):
        # 根据obstacle状态枚举 获取帧类型str
        category = "STAND"
        if self.state == ItemState.DYING:
            category = "DIE"
        return category

    def frame_loop(self):
        # 帧循环即将回到第1帧
        if self.state == ItemState.DYING:
            self.switch_state(ItemState.DEAD)
            self.uninstall()

    def switch_state(self, new_state):
        # 切换到指定状态 并重置帧索引
        self.state = new_state
        self.item_frame_idx = -1
        if new_state == ItemState.DYING:
            self.item["INTERVAL"] = 100

    def if_hide(self):
        # 判断item_instance是否隐藏
        if (self.x, self.y) in level.current_level.obstacle_instances:
            self.blank_img()

    def player_get(self, p):
        # 某一player获得该item
        if self.state == ItemState.DYING or self.state == ItemState.DEAD:
            return
        next_state_after_taken = ItemState.DYING if "DIE" in self.item.keys() else ItemState.DEAD
        self.switch_state(next_state_after_taken)
        # sound_player("")

    def set_restoration(self, to_x, to_y):
        self.item_instances_dict.pop((self.x, self.y))
        self.x = to_x
        self.y = to_y
        self.item_instances_dict[(to_x, to_y)] = self

    def uninstall(self):
        self.item_instances_dict.pop((self.x, self.y))


class ItemState(enum.Enum):
    DEAD = -2
    DYING = -1
    NORMAL = 0

