# Notes

Based on [jsgamelauncher](https://github.com/monteslu/jsgamelauncher) by Luis Montes.

A compatibility layer that lets JavaScript games run without a browser on retro handhelds. Uses standard web APIs (Canvas 2D, WebGL, WebAudio, Gamepad API, etc.) so games work identically in a browser and on-device.

## Controls

| Button          | Action                |
|-----------------|-----------------------|
| D-PAD / L-Stick | Move                  |
| A/B/X/Y         | Game-specific actions |
| Hotkey + Start  | Exit game             |

Individual games may use different input mappings, which are exposed to each game via the standard Web Keyboard/Gamepad API.

## Adding Games

Place game folders in `jsgamelauncher/games/`. Each game needs:
- A `.jsg` file
- A `game.js`, `main.js`, or `index.js` entry point (or specify `main` in `package.json`)

Update the following line in the `.sh` accordingly:
```
ROM="$GAMEDIR/games/demo/demo.jsg"
```
Games with a `public/` subfolder will have asset loading (fetch, Image, XHR) resolve relative to that folder.
