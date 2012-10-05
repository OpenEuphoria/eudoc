# Makefile for building and installing eudoc
# Assumes a working euphoria installation

!include config.wat

EUDOC= common.e euparser.e genparser.e parsers.e

!ifndef PREFIX
PREFIX=$(%EUDIR)
!endif

all : .SYMBOLIC build\eudoc.exe

build : .EXISTSONLY
	mkdir build

build\main-.c build\eudoc.mak : build eudoc.ex $(EUDOC)
	cd build
	euc -makefile -wat -con ..\eudoc.ex
	cd ..

build\eudoc.exe : build\main-.c build\eudoc.mak
	 cd build
	$(MAKE) -f eudoc.mak
	cd ..

install : .SYMBOLIC
	copy build\eudoc.exe $(PREFIX)\bin\

uninstall : .SYMBOLIC 
	-del $(PREFIX)\bin\eudoc.exe

mostlyclean : .SYMBOLIC
	-del build\*.obj
	
clean : .SYMBOLIC 
	-del /S /Q build
	-rmdir build

distclean : .SYMBOLIC clean
	-del Makefile
