Quest of Graal DX (https://pixel-boy.itch.io/guardian-sphere)
===========

Original version by:  
https://pixel-boy.itch.io/guardian-sphere

Description
===========

Shoot 'em up in which you use your life point to buy full of upgrades and make your Guardian strong enough to deal with waves of invaders.

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
B           = Shoot  
A           = Cancel


