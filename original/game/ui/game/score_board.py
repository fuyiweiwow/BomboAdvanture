import pygame

from game.frame import character
from game.level import level
from game.sprite.player import Player
from game.ui.ui import UIInstance


class ScoreBoard(UIInstance):

    TIME_IMG_OFFSETS = (0, 27, 54, 81, 108, 135, 162, 189, 216, 243)
    TIME_IMG_LENGTH = 27

    def __init__(self):
        super().__init__("bg", "bg_game")
        self.time_img = None
        self.rect.x = 600
        self.title = ""
        self.second_old = 0  # 上次设置的ui时间是多少 避免重复刷新
        self.player_a = level.current_level.me
        self.font = pygame.font.Font("res/font/simsun.ttc", 12)
        self.init_score_board()

    def init_score_board(self):
        self.time_img = pygame.image.load("res/img/ui/common/number3.png")

    def reset(self):
        self.sheet = pygame.Surface(self.rect.size, pygame.SRCALPHA, 32)
        self.reset_title(self.title)
        self.reset_time(self.second_old)
        self.reset_players()
        self.redraw_trigger = True

    def set_title(self, title: str):
        self.title = title
        self.reset()

    def reset_title(self, title: str):
        shadow = self.font.render(title, True, (0, 0, 0))
        self.sheet.blit(shadow, (131, 17))
        img = self.font.render(title, True, (255, 255, 255))
        self.sheet.blit(img, (130, 16))
        img = pygame.image.load("res/img/ui/icon/bomb_0_0.png")
        self.sheet.blit(img, (90, 16))
        img = pygame.image.load("res/img/ui/common/btn_leave_0_3.png")
        self.sheet.blit(img, (135, 535))

    def set_time(self, second: int):
        second = min(max(0, second), 5940)
        if second == self.second_old:
            return
        self.second_old = second
        self.reset()

    def reset_time(self, second: int):
        minute = second // 60
        second = second % 60
        if minute < 10:
            self.sheet.blit(self.time_img, (58, 56),
                            (ScoreBoard.TIME_IMG_OFFSETS[0], 0, ScoreBoard.TIME_IMG_LENGTH, self.time_img.get_height()))
        else:
            self.sheet.blit(self.time_img, (58, 56), (
            ScoreBoard.TIME_IMG_OFFSETS[minute // 10 % 10], 0, ScoreBoard.TIME_IMG_LENGTH, self.time_img.get_height()))
        self.sheet.blit(self.time_img, (85, 56),
                        (ScoreBoard.TIME_IMG_OFFSETS[minute % 10], 0, ScoreBoard.TIME_IMG_LENGTH,
                         self.time_img.get_height()))

        self.sheet.blit(self.time_img, (112, 56), (297, 0, ScoreBoard.TIME_IMG_LENGTH, self.time_img.get_height()))

        if second < 10:
            self.sheet.blit(self.time_img, (139, 56),
                            (ScoreBoard.TIME_IMG_OFFSETS[0], 0, ScoreBoard.TIME_IMG_LENGTH, self.time_img.get_height()))
        else:
            self.sheet.blit(self.time_img, (139, 56), (
            ScoreBoard.TIME_IMG_OFFSETS[second // 10 % 10], 0, ScoreBoard.TIME_IMG_LENGTH, self.time_img.get_height()))
        self.sheet.blit(self.time_img, (166, 56),
                        (ScoreBoard.TIME_IMG_OFFSETS[second % 10], 0, ScoreBoard.TIME_IMG_LENGTH,
                         self.time_img.get_height()))

    def reset_players(self):
        p: Player = self.player_a
        surf = pygame.Surface((40, 44), pygame.SRCALPHA, 32)
        for component in character.CHARACTER_COMPONENTS["D"]:
            if component not in p.character["STAND_D"].keys():
                continue
            frame = p.character["STAND_D"][component][0]
            surf.blit(frame.image, (frame.cx - 30, frame.cy - 31))
        self.sheet.blit(surf, (65, 108))
        shadow = self.font.render("永恒", True, (0, 0, 0))
        self.sheet.blit(shadow, (165, 115))
        img = self.font.render("永恒", True, (255, 255, 255))
        self.sheet.blit(img, (164, 114))
        shadow = self.font.render("QQTPVE作者", True, (0, 0, 0))
        self.sheet.blit(shadow, (129, 135))
        img = self.font.render("QQTPVE作者", True, (255, 255, 255))
        self.sheet.blit(img, (128, 134))
