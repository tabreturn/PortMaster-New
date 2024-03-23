## Notes

Original version by: https://skinner-space.itch.io/brutal-castle (May 14, 2021 Windows release)

Brutal Castle is an epic beat 'em up about fire-breathing living castle which outrageously fights against giant monsters to survive in a cruel medieval world of the war of all against all! Game files are already included and ready to go. Thanks to Skinner Space for the fantastic game and permission to distribute the files.


## Controls

| Button     | Action               |
| ---------- | -------------------- |
| LEFT/RIGHT | Directional movement |
| DOWN       | Down                 |
| UP         | Fire attack          |
| A          | Range attack         |
| B          | Jump                 |
| Y          | Melee attack         |
| R1         | Restore              |
| Start      | Enter                |


## Compile

```shell
wget https://downloads.tuxfamily.org/godotengine/3.3.4/godot-3.3.4-stable.tar.xz  
tar xf godot-3.3.4-stable.tar.xz  
cd godot-3.3.4-stable/platform  
git clone https://github.com/Cebion/frt.git  
cd ../  
scons platform=frt tools=no target=release use_llvm=yes module_webm_enabled=no -j12  
strip bin/godot.frt.opt.llvm
```

