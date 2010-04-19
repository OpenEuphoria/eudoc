# Makefile for building and installing eudoc
# Assumes a working euphoria installation

!include config.wat

EUDOC= common.e euparser.e genparser.e parsers.e

!ifndef PREFIX
PREFIX=$(%EUDIR)
!endif

all : .SYMBOLIC build\eudoc.exe

build\main-.c build\eudoc.mak : eudoc.ex $(EUDOC)
	-mkdir build
	cd build
	euc -makefile-full -con ..\eudoc.ex
	cd ..

build\eudoc.exe : build\main-.c build\eudoc.mak
	 cd build
	$(MAKE) -f eudoc.mak
	cd ..

install : .SYMBOLIC
	copy build\eudoc.exe $(PREFIX)\bin\

uninstall : .SYMBOLIC 
	-del $(PREFIX)\bin\eudoc.exe

clean : .SYMBOLIC 
	-del /S /Q build

distclean : .SYMBOLIC clean
	-del Makefile
