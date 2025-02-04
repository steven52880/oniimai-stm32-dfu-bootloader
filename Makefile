CROSS_COMPILE ?= arm-none-eabi-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
GIT_VERSION := $(shell git describe --abbrev=8 --dirty --always --tags)

# Config bits
BOOTLOADER_SIZE = 4
FLASH_SIZE = 256
FLASH_BASE_ADDR = 0x08000000
FLASH_BOOTLDR_PAYLOAD_SIZE_KB = $(shell echo $$(($(FLASH_SIZE) - $(BOOTLOADER_SIZE))))
RAM_SIZE_KB = 48

# Default config
CONFIG ?= -DWINUSB_SUPPORT

# Watchdog timeout in seconds
CONFIG += -DENABLE_WATCHDOG=20

# GPIO Pin to force DFU mode
CONFIG += -DENABLE_GPIO_DFU_BOOT -DGPIO_DFU_BOOT_PORT=GPIOC -DGPIO_DFU_BOOT_PIN=6 -DGPIO_DFU_BOOT_PULL_UP

# Configs
# Enables DFU upload commands, this is, enables reading flash memory (only within the user app boundaries) via DFU.
# CONFIG += -DENABLE_DFU_UPLOAD
# Ensures the user flash is completely erased before any DFU write/erase command is executed, to ensure no payloads are written that could lead to user data exfiltration.
# CONFIG += -DENABLE_SAFEWRITE
# Forces the user app image to have a valid checksum to boot it, on failure it will fallback to DFU mode.
# CONFIG += -DENABLE_CHECKSUM
# Disables JTAG at startup before jumping to user code and also ensures RDP protection is enabled before booting. It will update option bytes if that is not met and force a reset (should only happen the first time, after that RDP is enabled and can only be disabled via JTAG).
# CONFIG += -DENABLE_PROTECTIONS
# Enables DFU mode when a reset from the NRST pin occurs.
# CONFIG += -DENABLE_PINRST_DFU_BOOT

# Other options
# To protect bootloader from accidental writes
# CONFIG += -DENABLE_WRITEPROT

# Can be overriden with custom VID/PID
USB_VID ?= 0xdead
USB_PID ?= 0xca5d

CFLAGS = -Os -ggdb -std=c11 -Wall -pedantic -Werror \
	-ffunction-sections -fdata-sections -Wno-overlength-strings \
	-mcpu=cortex-m3 -mthumb -DSTM32F1 -fno-builtin-memcpy  \
	-fno-builtin-strlen -pedantic -DVERSION=\"$(GIT_VERSION)\" \
	-DUSB_PID=$(USB_PID) -DUSB_VID=$(USB_VID) \
	-flto $(CONFIG)

LDFLAGS = -ggdb -ffunction-sections -fdata-sections \
	-Wl,-Tstm32f103.ld -nostartfiles -lc -lnosys \
	-mthumb -mcpu=cortex-m3 -Wl,-gc-sections -flto \
	-Wl,--print-memory-usage

all:	bootloader-dfu-fw.bin

# DFU bootloader firmware
bootloader-dfu-fw.elf: init.o main.o usb.o
	$(CC) $^ -o $@ $(LDFLAGS) -Wl,-Ttext=$(FLASH_BASE_ADDR) -Wl,-Map,bootloader-dfu-fw.map -Wl,--defsym=_ram_size_kb=$(RAM_SIZE_KB)

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

%.o: %.c | flash_config.h
	$(CC) -c $< -o $@ $(CFLAGS)

flash_config.h:
	echo "#define FLASH_BASE_ADDR $(FLASH_BASE_ADDR)" > flash_config.h
	echo "#define FLASH_SIZE_KB $(FLASH_SIZE)" >> flash_config.h
	echo "#define FLASH_BOOTLDR_PAYLOAD_SIZE_KB $(FLASH_BOOTLDR_PAYLOAD_SIZE_KB)" >> flash_config.h
	echo "#define FLASH_BOOTLDR_SIZE_KB $(BOOTLOADER_SIZE)" >> flash_config.h

clean:
	-rm -f *.elf *.o *.bin *.map flash_config.h

