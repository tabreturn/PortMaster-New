# Flash Launcher

A Flash/SWF game player for handheld Linux devices via PortMaster.

Based on [FlashLauncherZJ](https://github.com/StarCatL/FlashLauncherZJ) by StarCatL.


## Adding games

Place SWF files in `flashlauncherpm/programs/` -- each in its own subfolder:

```
flashlauncherpm/programs/
├── mygame/
│   └── mygame.swf
├── anothergame/
│   ├── anothergame.swf
│   └── controls.gptk
└── ...
```

## Menu controls

| Button       | Action        |
|--------------|---------------|
| UP/DOWN      | Navigate list |
| LEFT/RIGHT   | Page up/down  |
| A            | Launch game   |
| SELECT       | Quit menu     |
| SELECT+START | In-game quit  |
| L-STICK      | In-game mouse |
| R1           | In-game click |

- Press SELECT after a game loads to scale it to fit the screen.
- Place a `controls.gptk` file in a game's folder to override the default mapping.
- If no `controls.gptk` exists, the default `flash.gptk` is used.

