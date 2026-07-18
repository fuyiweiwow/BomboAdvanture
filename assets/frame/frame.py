import numpy
import pygame


class Frame:

    def __init__(self, image: pygame.Surface, cx, cy):
        self.image = image
        self.cx = cx
        self.cy = cy
        self.alpha = None

    def get_alpha(self):
        arr = pygame.surfarray.array_alpha(self.image).reshape((self.image.get_size()[0], self.image.get_size()[1], 1))
        self.alpha = numpy.tile(arr, (1, 1, 3)) / 255

    def duplicate(self):
        img = self.image.copy()
        return Frame(img, self.cx, self.cy)
