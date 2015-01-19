all:
	gprbuild -P demo.gpr --RTS=./ravenscar-sfp-stm32f4 -XLOADER=RAM
	gprbuild -P test.gpr --RTS=./ravenscar-sfp-stm32f4 -XLOADER=RAM

debug: all
	/usr/gnat/bin/arm-eabi-gdb obj/hello -cd=./

test: all
	/usr/gnat/bin/arm-eabi-gdb obj/testship -cd=./
