# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['main.py'],
    pathex=['game/game.py', 'game/algo/aStar.py', 'game/algo/blender.py', 'game/const/color.py', 'game/const/game.py', 'game/const/window.py', 'game/effect/effect.py', 'game/effect/effect_instance.py', 'game/frame/bomb.py', 'game/frame/character.py', 'game/frame/flame.py', 'game/frame/floor.py', 'game/frame/frame.py', 'game/frame/item.py', 'game/frame/magic.py', 'game/frame/obstacle.py', 'game/level/level.py', 'game/music/music_loader.py', 'game/skill/skill.py', 'game/skill/new_skill.py', 'game/sound/sound_player.py', 'game/sprite/bomb_instance.py', 'game/sprite/flame_instance.py', 'game/sprite/hero.py', 'game/sprite/item_instance.py', 'game/sprite/npc.py', 'game/sprite/obstacle_instance.py', 'game/sprite/player.py', 'game/sprite/throwable.py', 'game/sprite/updatable.py', 'game/ui/ui.py', 'game/ui/game/blood_bar.py', 'game/ui/game/dlg_pveFunc.py', 'game/ui/game/game_top.py', 'game/ui/game/misc_510.py', 'game/ui/game/player_icon.py', 'game/ui/game/status_bar.py'],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='main',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['icon.ico'],
)
