all:
	gprbuild -P demo.gpr --RTS=./ravenscar-sfp-stm32f4 -XLOADER=RAM

debug: all
	/usr/gnat/bin/arm-eabi-gdb obj/hello -cd=./
