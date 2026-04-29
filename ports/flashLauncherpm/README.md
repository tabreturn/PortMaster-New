# Flash Launcher

A Flash/SWF game player for handheld Linux devices via PortMaster.

Based on [FlashLauncherZJ](https://github.com/StarCatL/FlashLauncherZJ) by the fantastic StarCatL.

DO NOT EXPECT every Flash game ever to run. Maybe like 50%. I'm not sure. No Flixel games ran for me, etc.

## Adding games

Place SWF files in `flashlauncherpm/programs/` -- each in its own subfolder:

```
flashlauncherpm/programs/
├── somegame/
│   └── somegame.swf
├── anothergame/
│   ├── anothergame.swf
│   └── controls.gptk
└── ...
```

You can grab the `swf` files for `alien_hominid`, `flyguy`, `marvin_spectrum`, and `wasted_sky` from the Ruffle demo repo: https://github.com/ruffle-rs/demo/tree/master/swfs


## Menu controls

| Button       | Action             |
|--------------|--------------------|
| UP/DOWN      | Menu navigate list |
| LEFT/RIGHT   | Menu page up/down  |
| A            | Menu launch        |
| SELECT       | Menu quit          |
| L-STICK      | In-game mouse      |
| R1           | In-game click      |
| SELECT+START | In-game quit       |

- Place a `controls.gptk` file in a game's folder to override the default mapping ...
- ... if no `controls.gptk` exists, the default `flash.gptk` is used.

