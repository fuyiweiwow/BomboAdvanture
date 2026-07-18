import json
import pygame

from game.frame.frame import Frame

ITEM_FRAME_ROOT = "game/frame/item/"
ITEM_IMG_ROOT = "res/img/item/"
items = {}


def get_item(name):
    if name not in items.keys():
        items[name] = load_item(name)
    return items[name]


def load_item(name):
    an_item = {}
    with open(ITEM_FRAME_ROOT + '/' + name + ".json") as f:
        item_json = json.load(f)
    an_item["INTERVAL"] = item_json["INTERVAL"]
    append_item(item_json, an_item, "STAND")
    append_item(item_json, an_item, "DIE")
    return an_item


def append_item(item_json, an_item, state: str):

    if state in item_json:
        an_item[state] = list()
        frames = item_json[state]
        size = len(frames["IMG"])
        for i in range(size):
            # print(ITEM_IMG_ROOT + frames["IMG"][i])
            img = pygame.image.load(ITEM_IMG_ROOT + frames["IMG"][i]).convert_alpha()
            cx = frames["CX"][i]
            cy = frames["CY"][i]
            an_item[state].append(Frame(img, cx, cy))

