# Makefile for building and installing eudoc
# Assumes a working euphoria installation

EUDOC= $(wildcard *.e)

ifeq "$(PREFIX)" ""
PREFIX=/usr/local
endif


all : build/eudoc

build/main-.c build/eudoc.mak : eudoc.ex $(EUDOC)
	-mkdir build
	cd build && euc -makefile-full ../eudoc.ex

build/eudoc : build/main-.c build/eudoc.mak
	 $(MAKE) -C build -f eudoc.mak

install : build/eudoc
	install build/eudoc $(DESTDIR)$(PREFIX)/bin

uninstall :
	-rm $(DESTDIR)$(PREFIX)/bin/eudoc

clean :
	-rm -rf build

distclean : clean
	rm Makefile

.PHONY : all clean install uninstall disclean
