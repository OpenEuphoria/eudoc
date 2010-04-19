@echo off

echo !include Makefile.wat > Makefile

echo # eudoc configuration for watcom > config.wat

:Loop
IF "%1"=="" GOTO Continue

IF "%1" =="--prefix" (
	echo PREFIX=%2 >> config.wat
	SHIFT
	GOTO EndLoop
)

:EndLoop
SHIFT
GOTO Loop

:Continue
