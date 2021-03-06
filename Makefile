CROSS_COMPILE ?= arm-none-eabi-
CC := $(CROSS_COMPILE)gcc
QEMU_STM32 ?= ../qemu_stm32/arm-softmmu/qemu-system-arm

ARCH = CM3
VENDOR = ST
PLAT = STM32F10x

LIBDIR = .
CMSIS_LIB=$(LIBDIR)/libraries/CMSIS/$(ARCH)
STM32_LIB=$(LIBDIR)/libraries/STM32F10x_StdPeriph_Driver

CMSIS_PLAT_SRC = $(CMSIS_LIB)/DeviceSupport/$(VENDOR)/$(PLAT)

export PATH := /usr/local/csl/arm-2012.03/bin:$(PATH)

all: main.bin

main.bin: kernel.c kernel.h context_switch.s syscall.s syscall.h
	$(CROSS_COMPILE)gcc \
		-DUSER_NAME=\"$(USER)\" \
		-Wl,-Tmain.ld -nostartfiles \
		-I . \
		-I$(LIBDIR)/libraries/CMSIS/CM3/CoreSupport \
		-I$(LIBDIR)/libraries/CMSIS/CM3/DeviceSupport/ST/STM32F10x \
		-I$(CMSIS_LIB)/CM3/DeviceSupport/ST/STM32F10x \
		-I$(LIBDIR)/libraries/STM32F10x_StdPeriph_Driver/inc \
		-fno-common -ffreestanding -O0 \
		-gdwarf-2 -g3 \
		-mcpu=cortex-m3 -mthumb \
		-o main.elf \
		\
		$(CMSIS_LIB)/CoreSupport/core_cm3.c \
		$(CMSIS_PLAT_SRC)/system_stm32f10x.c \
		$(CMSIS_PLAT_SRC)/startup/gcc_ride7/startup_stm32f10x_md.s \
		$(STM32_LIB)/src/stm32f10x_rcc.c \
		$(STM32_LIB)/src/stm32f10x_gpio.c \
		$(STM32_LIB)/src/stm32f10x_usart.c \
		$(STM32_LIB)/src/stm32f10x_exti.c \
		$(STM32_LIB)/src/misc.c \
		\
		context_switch.s \
		syscall.s \
		stm32_p103.c \
		kernel.c \
		unit_test.c \
		memcpy.s
	$(CROSS_COMPILE)objcopy -Obinary main.elf main.bin
	$(CROSS_COMPILE)objdump -S main.elf > main.list

qemu: main.bin $(QEMU_STM32)
	$(QEMU_STM32) -M stm32-p103 -kernel main.bin -monitor stdio

qemudbg: main.bin $(QEMU_STM32)
	$(QEMU_STM32) -M stm32-p103 \
		-gdb tcp::3333 -S \
		-kernel main.bin


qemu_remote: main.bin $(QEMU_STM32)
	$(QEMU_STM32) -M stm32-p103 -kernel main.bin -vnc :1

qemudbg_remote: main.bin $(QEMU_STM32)
	$(QEMU_STM32) -M stm32-p103 \
		-gdb tcp::3333 -S \
		-kernel main.bin \
		-vnc :1

qemu_remote_bg: main.bin $(QEMU_STM32)
	$(QEMU_STM32) -M stm32-p103 \
		-kernel main.bin \
		-vnc :1 &

qemudbg_remote_bg: main.bin $(QEMU_STM32)
	$(QEMU_STM32) -M stm32-p103 \
		-gdb tcp::3333 -S \
		-kernel main.bin \
		-vnc :1 &

emu: main.bin
	bash emulate.sh main.bin

qemuauto: main.bin gdbscript
	bash emulate.sh main.bin &
	sleep 1
	$(CROSS_COMPILE)gdb -x gdbscript&
	sleep 5

qemuauto_remote: main.bin gdbscript
	bash emulate_remote.sh main.bin &
	sleep 1
	$(CROSS_COMPILE)gdb -x gdbscript&
	sleep 5

check: unit_test.c unit_test.h
	$(MAKE) main.bin DEBUG_FLAGS=-DDEBUG
	$(QEMU_STM32) -M stm32-p103 \
		-gdb tcp::3333 -S \
		-serial stdio \
		-kernel main.bin -monitor null >/dev/null &
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-strlen.txt' -x unit_test/test-strlen.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-strcpy.txt' -x unit_test/test-strcpy.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-strcmp.txt' -x unit_test/test-strcmp.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-strncmp.txt' -x unit_test/test-strncmp.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-cmdtok.txt' -x unit_test/test-cmdtok.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-itoa.txt' -x unit_test/test-itoa.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-find_events.txt' -x unit_test/test-find_events.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-find_envvar.txt' -x unit_test/test-find_envvar.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-fill_arg.txt' -x unit_test/test-fill_arg.in
	@echo
	$(CROSS_COMPILE)gdb -batch -ex 'set logging file test_result/test-export_envvar.txt' -x unit_test/test-export_envvar.in
	@echo
	@pkill -9 $(notdir $(QEMU_STM32))

clean:
	rm -f *.elf *.bin *.list
