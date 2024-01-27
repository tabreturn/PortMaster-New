Quest of Graal DX (https://pixel-boy.itch.io/quest-of-graal-dx)
===========

Original version by:  
https://pixel-boy.itch.io/quest-of-graal-dx (tested with Quest Of Graal LINUX.rar Mar 11, 2022 release)

Description
===========

Quest of Graal is a multiplayer platform racing game. But you can play alone against AI. Discover the history of Arthur and Merlin's quest for the Graal by unlocking storybook chapters as you play, racing through more than 20 levels using weapons, magic items, and golden statues (which unleash special player abilities) to make it through the mayhem.

To compile:
===========

wget https://downloads.tuxfamily.org/godotengine/3.5.2/godot-3.5.2-stable.tar.xz  
tar xf godot-3.5.2-stable.tar.xz  
cd godot-3.5.2-stable/platform  
git clone https://github.com/Cebion/frt.git  
cd ../  
scons platform=frt tools=no target=release use_llvm=yes module_webm_enabled=no -j12  
strip bin/godot.frt.opt.llvm

Controls:
===========

DPAD        = Movement  
X           = ATK  
C           = SPC

