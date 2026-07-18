import pygame

from game.const import game as G
from game.level import level


def current_grid(x_pos, y_pos):
    x = x_pos // G.GAME_SQUARE
    y = y_pos // G.GAME_SQUARE
    return int(x), int(y)


class Updatable(pygame.sprite.Sprite):

    def __init__(self, x, y):
        super(Updatable, self).__init__()
        self.x = x
        self.y = y
        self.x_pos = x * G.GAME_SQUARE + G.HALF_GAME_SQUARE  # 中心点x坐标
        self.y_pos = y * G.GAME_SQUARE + G.HALF_GAME_SQUARE  # 中心点y坐标
        self.wall_walking = False  # 允许穿墙

    def if_hide(self):
        ret = False
        ois = level.current_level.obstacle_instances
        if (self.x, self.y) in ois.keys():
            an_obstacle = ois[(self.x, self.y)]
            if an_obstacle.obstacle_can_hide:
                self.blank_img()
                ret = True
        return ret

    def blank_img(self):
        # 清空image
        self.image = pygame.Surface((1, 1), pygame.SRCALPHA, 32)

    def get_ruld_block(self):
        right = self.x_pos + G.HALF_GAME_SQUARE - 1
        right_grid = int(right // G.GAME_SQUARE)
        top = self.y_pos - G.HALF_GAME_SQUARE
        top_grid = int(top // G.GAME_SQUARE)
        left = self.x_pos - G.HALF_GAME_SQUARE
        left_grid = int(left // G.GAME_SQUARE)
        bottom = self.y_pos + G.HALF_GAME_SQUARE - 1
        bottom_grid = int(bottom // G.GAME_SQUARE)
        return right, right_grid, top, top_grid, left, left_grid, bottom, bottom_grid

    def slide(self, update_time_old, district_locked, orientation, slide_speed, top, bottom, left, right, block, top_grid, bottom_grid, left_grid, right_grid, cl):
        slide_speed = min(20, slide_speed * G.GAME_SQUARE / 1000 * (pygame.time.get_ticks() - update_time_old))
        if orientation == 1:
            self.movement_right(district_locked, slide_speed, top, bottom, right, block, top_grid, bottom_grid, cl)
        elif orientation == 2:
            self.movement_up(district_locked, slide_speed, top, left, right, block, left_grid, right_grid, cl)
        elif orientation == 3:
            self.movement_left(district_locked, slide_speed, top, bottom, left, block, top_grid, bottom_grid, cl)
        elif orientation == 4:
            self.movement_down(district_locked, slide_speed, bottom, left, right, block, left_grid, right_grid, cl)

    def movement_right(self, district_locked, speed, top, bottom, right, block, top_grid, bottom_grid, cl):
        if right // G.GAME_SQUARE != (right + speed) // G.GAME_SQUARE:  # 右侧身位跨格子时
            right_screen = right + speed >= cl.map_x_pos  # 右侧碰撞屏幕
            right_district = self.x_pos + speed >= cl.district_square["x2"]
            right_block = block[1][self.x + 1][self.y]  # 右侧numpy障碍
            right_block_top_0 = self.y != top // G.GAME_SQUARE and block[0][self.x + 1][top_grid + 1]  # 右上侧横向障碍
            right_block_top_1 = block[1][self.x + 1][top_grid]  # 右上侧纵向障碍
            right_block_bottom_0 = self.y != bottom // G.GAME_SQUARE and block[0][self.x + 1][bottom_grid]  # 右下侧横向障碍
            right_block_bottom_1 = block[1][self.x + 1][bottom_grid]  # 右下侧纵向障碍
            right_edge = (right + speed) // G.GAME_SQUARE
            right_bomb = len(cl.get_bomb_instance(right_edge, self.y))  # 右侧糖泡
            right_bomb_top = len(cl.get_bomb_instance(right_edge, top_grid))  # 右上侧糖泡
            right_bomb_bottom = len(cl.get_bomb_instance(right_edge, bottom_grid))  # 右下侧糖泡
            if self.wall_walking and not right_screen:
                self.x_pos += speed
                cl.scroll_map()
            if district_locked and right_district:
                self.x_pos += min(speed, max(0, right_edge * G.GAME_SQUARE - G.HALF_GAME_SQUARE - self.x_pos))
                self.collide_wall()
                self.collide_district()
            elif right_block > 0 or right_screen or right_bomb > 0:
                self.x_pos += min(speed, max(0, right_edge * G.GAME_SQUARE - G.HALF_GAME_SQUARE - self.x_pos))
                self.collide_wall()
                self.try_push("R")
            elif right_block_top_0 > 0 or right_block_top_1 > 0 or right_bomb_top > 0:
                self.y_pos = min(self.y_pos + speed, self.y * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("R", (0, -1))
            elif right_block_bottom_0 > 0 or right_block_bottom_1 > 0 or right_bomb_bottom > 0:
                self.y_pos = max(self.y_pos - speed, self.y * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("R", (0, 1))
            else:
                self.x_pos += speed
                cl.scroll_map()
        elif self.x_pos // G.GAME_SQUARE != (self.x_pos + speed) // G.GAME_SQUARE:
            if len(level.current_level.get_bomb_instance(self.x + 1, self.y)) == 0 or self.wall_walking:
                self.x_pos += speed
                cl.scroll_map()
        else:
            self.x_pos += speed
            cl.scroll_map()

    def movement_up(self, district_locked, speed, top, left, right, block, left_grid, right_grid, cl):
        if top // G.GAME_SQUARE != (top - speed) // G.GAME_SQUARE:
            top_screen = top - speed < 0
            top_district = self.y_pos - speed < cl.district_square["y1"]
            top_block = block[0][self.x][self.y]
            top_block_left_0 = block[0][left_grid][self.y]
            top_block_left_1 = self.x != left // G.GAME_SQUARE and block[1][left_grid + 1][self.y - 1]
            top_block_right_0 = block[0][right_grid][self.y]
            top_block_right_1 = self.x != right // G.GAME_SQUARE and block[1][right_grid][self.y - 1]
            top_edge = (top - speed) // G.GAME_SQUARE
            top_bomb = len(cl.get_bomb_instance(self.x, top_edge))
            top_bomb_left = len(cl.get_bomb_instance(left_grid, top_edge))
            top_bomb_right = len(cl.get_bomb_instance(right_grid, top_edge))
            if self.wall_walking and not top_screen:
                self.y_pos -= speed
                cl.scroll_map()
            elif district_locked and top_district:
                self.y_pos -= min(speed, max(0, top_edge * G.GAME_SQUARE + G.HALF_GAME_SQUARE - self.y_pos))
                self.collide_wall()
                self.collide_district()
            elif top_block > 0 or top_screen or top_bomb > 0:
                self.y_pos -= min(speed, max(0, top_edge * G.GAME_SQUARE + G.HALF_GAME_SQUARE - self.y_pos))
                self.collide_wall()
                self.try_push("U")
            elif top_block_left_0 > 0 or top_block_left_1 > 0 or top_bomb_left > 0:
                self.x_pos = min(self.x_pos + speed, self.x * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("U", (-1, 0))
            elif top_block_right_0 > 0 or top_block_right_1 > 0 or top_bomb_right > 0:
                self.x_pos = max(self.x_pos - speed, self.x * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("U", (1, 0))
            else:
                self.y_pos -= speed
                cl.scroll_map()
        elif self.y_pos // G.GAME_SQUARE != (self.y_pos - speed) // G.GAME_SQUARE:
            if len(level.current_level.get_bomb_instance(self.x, self.y - 1)) == 0 or self.wall_walking:
                self.y_pos -= speed
                cl.scroll_map()
        else:
            self.y_pos -= speed
            cl.scroll_map()

    def movement_left(self, district_locked, speed, top, bottom, left, block, top_grid, bottom_grid, cl):
        if left // G.GAME_SQUARE != (left - speed) // G.GAME_SQUARE:
            left_screen = left - speed < 0
            left_district = self.x_pos - speed < cl.district_square["x1"]
            left_block = block[1][self.x][self.y]
            left_block_top_0 = self.y != top // G.GAME_SQUARE and block[0][self.x - 1][top_grid + 1]
            left_block_top_1 = block[1][self.x][top_grid]
            left_block_bottom_0 = self.y != bottom // G.GAME_SQUARE and block[0][self.x - 1][bottom_grid]
            left_block_bottom_1 = block[1][self.x][bottom_grid]
            left_edge = (left - speed) // G.GAME_SQUARE
            left_bomb = len(cl.get_bomb_instance(left_edge, self.y))
            left_bomb_top = len(cl.get_bomb_instance(left_edge, top_grid))
            left_bomb_bottom = len(cl.get_bomb_instance(left_edge, bottom_grid))
            if self.wall_walking and not left_screen:
                self.x_pos -= speed
                cl.scroll_map()
            if district_locked and left_district:
                self.x_pos -= min(speed, max(0, self.x_pos - (left * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
                self.collide_wall()
                self.collide_district()
            elif left_block > 0 or left_screen or left_bomb > 0:
                self.x_pos -= min(speed, max(0, self.x_pos - (left * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
                self.collide_wall()
                self.try_push("L")
            elif left_block_top_1 > 0 or left_block_top_0 > 0 or left_bomb_top > 0:
                self.y_pos = min(self.y_pos + speed, self.y * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("L", (0, -1))
            elif left_block_bottom_1 > 0 or left_block_bottom_0 > 0 or left_bomb_bottom > 0:
                self.y_pos = max(self.y_pos - speed, self.y * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("L", (0, 1))
            else:
                self.x_pos -= speed
                cl.scroll_map()
        elif self.x_pos // G.GAME_SQUARE != (self.x_pos - speed) // G.GAME_SQUARE:
            if len(level.current_level.get_bomb_instance(self.x - 1, self.y)) == 0 or self.wall_walking:
                self.x_pos -= speed
                cl.scroll_map()
        else:
            self.x_pos -= speed
            cl.scroll_map()

    def movement_down(self, district_locked, speed, bottom, left, right, block, left_grid, right_grid, cl):
        if bottom // G.GAME_SQUARE != (bottom + speed) // G.GAME_SQUARE:
            bottom_block = block[0][self.x][self.y + 1]
            bottom_district = self.y_pos + speed >= cl.district_square["y2"]
            bottom_block_right_0 = block[0][int(right // G.GAME_SQUARE)][self.y + 1]
            bottom_block_right_1 = self.x != right // G.GAME_SQUARE and block[1][int(right // G.GAME_SQUARE)][
                self.y + 1]
            bottom_block_left_0 = block[0][int(left // G.GAME_SQUARE)][self.y + 1]
            bottom_block_left_1 = self.x != left // G.GAME_SQUARE and block[1][int(left // G.GAME_SQUARE) + 1][
                self.y + 1]
            bottom_screen = bottom + speed >= cl.map_y_pos
            bottom_edge = (bottom + speed) // G.GAME_SQUARE
            bottom_bomb = len(cl.get_bomb_instance(self.x, bottom_edge))
            bottom_bomb_left = len(cl.get_bomb_instance(left_grid, bottom_edge))
            bottom_bomb_right = len(cl.get_bomb_instance(right_grid, bottom_edge))
            if self.wall_walking and not bottom_screen:
                self.y_pos += speed
                cl.scroll_map()
            elif district_locked and bottom_district:
                self.y_pos += min(speed, max(0, self.y_pos - (bottom_edge * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
                self.collide_wall()
                self.collide_district()
            elif bottom_block > 0 or bottom_screen or bottom_bomb > 0:
                self.y_pos += min(speed, max(0, self.y_pos - (bottom_edge * G.GAME_SQUARE + G.HALF_GAME_SQUARE)))
                self.collide_wall()
                self.try_push("D")
            elif bottom_block_right_0 > 0 or bottom_block_right_1 > 0 or bottom_bomb_right > 0:
                self.x_pos = max(self.x_pos - speed, self.x * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("D", (1, 0))
            elif bottom_block_left_0 > 0 or bottom_block_left_1 > 0 or bottom_bomb_left > 0:
                self.x_pos = min(self.x_pos + speed, self.x * G.GAME_SQUARE + G.HALF_GAME_SQUARE)
                self.try_push("D", (-1, 0))
            else:
                self.y_pos += speed
                cl.scroll_map()
        elif self.y_pos // G.GAME_SQUARE != (self.y_pos + speed) // G.GAME_SQUARE:
            if len(level.current_level.get_bomb_instance(self.x, self.y + 1)) == 0 or self.wall_walking:
                self.y_pos += speed
                cl.scroll_map()
        else:
            self.y_pos += speed
            cl.scroll_map()

    def collide_wall(self):
        pass

    def collide_district(self):
        pass

    def try_push(self, direction, offset=(0, 0)):
        pass

    def draw(self, screen: pygame.Surface):
        screen.blit(self.image, self.rect)

    def get_y(self):
        return self.y
