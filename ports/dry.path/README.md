Dry Path (https://pixel-boy.itch.io/dry-path)
===========

Original version by:  
https://pixel-boy.itch.io/dry-path

Description
===========

Dry path is a 2D / 3D exploration third person platformer game. After the crash of your airship you are the only survivor in a mysterious desert, the air is dry, and the water is lacking.

To compile:
===========

wget https://downloads.tuxfamily.org/godotengine/3.2.3/godot-3.2.3-stable.tar.xz  
tar xf godot-3.2.3-stable.tar.xz  
cd godot-3.2.3-stable/platform  
git clone https://github.com/Cebion/frt.git  
cd ../  
scons platform=frt tools=no target=release use_llvm=yes module_webm_enabled=no -j12  
strip bin/godot.frt.opt.llvm

Controls:
===========

DPAD        = Movement  
B           = Jump  
A           = Interact

