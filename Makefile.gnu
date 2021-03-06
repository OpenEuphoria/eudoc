# Makefile for building and installing eudoc
# Assumes a working euphoria installation

CONFIG_FILE = config.gnu

ifndef CONFIG
CONFIG = $(CONFIG_FILE)
endif

include $(CONFIG_FILE)

EUDOC= $(wildcard *.e)

ifeq "$(PREFIX)" ""
PREFIX=/usr/local
endif


all : build/eudoc

build/main-.c : eudoc.ex $(EUDOC)
	-mkdir build
	cd build && euc -gcc -makefile ../eudoc.ex

build/eudoc.mak : build/main-.c

build/eudoc : build/main-.c build/eudoc.mak
	 $(MAKE) -C build -f eudoc.mak

install : build/eudoc
	install build/eudoc $(DESTDIR)$(PREFIX)/bin

uninstall :
	-rm $(DESTDIR)$(PREFIX)/bin/eudoc

mostlyclean : build
	-rm build/*.{c,o,mak,h}
	
clean :
	-rm -rf build

distclean : clean
	rm Makefile

.PHONY : all clean install uninstall disclean mostlyclean
.SECONDARY : build/eudoc.mak build/main-.c
