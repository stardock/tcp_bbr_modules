# BBRv3 (bbr3) backport module - build against any prepared kernel tree.
#
# Usage:
#   make                      # against /lib/modules/$(uname -r)/build
#   make KDIR=/path/to/linux  # against a specific (prepared) kernel tree
#   make KDIR=... ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
#
# The build first runs gen_kconfig.py, which test-compiles the probes in
# kapi_checklist against KDIR and writes kernel_config.h (HAVE_* macros).
# tcp_bbr3.c + bbr_compat.h adapt purely on those macros.

# DKMS invokes make with KERNELRELEASE=$kernelver, which can differ from
# uname -r (e.g. building for a newly installed kernel before reboot).
KDIR           ?= $(if $(KERNELRELEASE),/lib/modules/$(KERNELRELEASE)/build,/lib/modules/$(shell uname -r)/build)
PWD            := $(shell pwd)

# Compiler used for the probes; should match the one kbuild uses.
CC_PROBE       ?= $(CROSS_COMPILE)gcc
PROBE_J        ?= $(shell nproc 2>/dev/null || echo 4)
PROBE_ARCH     := $(if $(ARCH),-a $(ARCH),)

obj-m          := tcp_nanqinlang.o tcp_tsunami.o tcp_bbrplus.o tcp_brutal.o tcp_bbr1.o tcp_bbr3.o
ccflags-y      := -I$(src)

KBUILD_VARS    := $(if $(ARCH),ARCH=$(ARCH),) $(if $(CROSS_COMPILE),CROSS_COMPILE=$(CROSS_COMPILE),)

.PHONY: all modules probe clean distclean

all: modules

kernel_config.h: kapi_checklist gen_kconfig.py
	python3 gen_kconfig.py $(KDIR) $@ $(CC_PROBE) kapi_checklist -j $(PROBE_J) $(PROBE_ARCH)

probe: kernel_config.h

modules: kernel_config.h
	$(MAKE) -C $(KDIR) M=$(PWD) $(KBUILD_VARS) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

distclean: clean
	rm -f kernel_config.h

dkms:
	dkms add .
	dkms install tcp_bbr_modules/1.0

dkms-remove:
	dkms remove tcp_bbr_modules/1.0 --all
