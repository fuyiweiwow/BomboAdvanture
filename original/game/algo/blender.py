import numpy as np

import pygame
import pygame.surfarray

BLEND_MULTIPLY = -1
BLEND_SCREEN = -2
BLEND_OVERLAY = -3


def arr_int2float(target, blend):
    # 将uint8的numpy数组转为float16
    return target.astype(np.float16), blend.astype(np.float16)


def broaden_alpha(blend_alpha):
    # 将[w, h]的alpha数组扩展为[w, h, 3]且介于0-1之间
    return np.tile(blend_alpha.reshape((blend_alpha.shape[0], blend_alpha.shape[1], 1)), (1, 1, 3)) / 255


def normal(target, blend, blend_alpha):
    # 正常
    blend_alpha = broaden_alpha(blend_alpha)
    target[...] = target * (1 - blend_alpha) + blend * blend_alpha


def multiply(target, blend, blend_alpha):
    # 正片叠底
    if target.shape != blend.shape:
        return
    target[...] = target * (blend + (255 - blend) * (1 - blend_alpha)) / 255


def screen_color(target, blend, blend_alpha):
    # 滤色
    if target.shape != blend.shape:
        return
    target[...] = 255 - (255 - target) * (255 - blend_alpha * blend) / 255


def overlay(target, blend, blend_alpha):
    # 叠加
    if target.shape != blend.shape:
        return target
    mask1 = target <= 128
    mask2 = target > 128
    target, blend = arr_int2float(target, blend)
    blend_alpha = broaden_alpha(blend_alpha)
    tmp = np.zeros(target.shape, dtype=np.uint8)

    tmp[mask1] = target[mask1] * (blend[mask1] + (128 - blend[mask1]) * (1 - blend_alpha[mask1])) / 128
    tmp[mask2] = 255 - (255 - target[mask2]) * (128 + blend_alpha[mask2] * (127 - blend[mask2])) / 128
    return tmp


def color_overlay(target_surface, color, package_surface):
    # 在半透明图层上叠加纯色
    # target_surface 半透明层Surface
    # color 叠加颜色
    # package_surface True返回pygame.Surface False返回三维数组
    target_arr = pygame.surfarray.array3d(target_surface)
    target_alpha = pygame.surfarray.array_alpha(target_surface)
    color = np.array([color])
    color = np.reshape(color, (1, 1, 3))
    color = np.tile(color, (target_arr.shape[0], target_arr.shape[1], 1))
    alpha = np.full((target_arr.shape[0], target_arr.shape[1]), 255)
    colored_target = overlay(target_arr, color, alpha)
    if not package_surface:
        return colored_target
    else:
        colored_surface = pygame.surfarray.make_surface(colored_target).convert_alpha()
        pygame.surfarray.pixels_alpha(colored_surface)[0::, 0::] = target_alpha
        return colored_surface


def blit(source, source_alpha, dest, blend_at, blend_mode):

    ra = pygame.Rect((0, 0, dest.get_size()[0], dest.get_size()[1]))
    rb = pygame.Rect((blend_at[0], blend_at[1], source.get_size()[0], source.get_size()[1]))
    ra_b = ra.clip(rb)
    if ra_b.w == 0:
        return

    fg_x, fg_dx, fg_y, fg_dy = max(0, -blend_at[0]), dest.get_size()[0] - blend_at[0], max(0, -blend_at[1]), dest.get_size()[1] - blend_at[1]
    a3d_item = pygame.surfarray.pixels3d(source)[fg_x: fg_dx, fg_y: fg_dy]
    source_alpha = source_alpha[fg_x: fg_dx, fg_y: fg_dy]

    bg_x, bg_dx, bg_y, bg_dy = ra_b.x, ra_b.x + ra_b.w, ra_b.y, ra_b.y + ra_b.h
    a3d_bg = pygame.surfarray.pixels3d(dest)[bg_x: bg_dx, bg_y: bg_dy]

    if blend_mode == BLEND_SCREEN:
        screen_color(a3d_bg, a3d_item, source_alpha)
    elif blend_mode == BLEND_MULTIPLY:
        multiply(a3d_bg, a3d_item, source_alpha)
    elif blend_mode == BLEND_OVERLAY:
        a3d_new = overlay(a3d_bg, a3d_item, source_alpha)
        p3d_bg = pygame.surfarray.pixels3d(dest)
        p3d_bg[bg_x: bg_dx, bg_y: bg_dy] = a3d_new
        del p3d_bg



