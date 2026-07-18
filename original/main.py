import asyncio
import numpy as np
from game import control
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# if __name__ == "__main__":

async def main():
    gameCtrl = control.Control()
    await gameCtrl.update()

asyncio.run(main())