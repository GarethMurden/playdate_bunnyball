# Bunnyball — Playdate build
#
#   make          build Bunnyball.pdx from source/
#   make run      build, then open the bundle in the Playdate Simulator
#   make clean    remove the built bundle
#
# pdc is taken from $PDC if set, otherwise from $PLAYDATE_SDK_PATH/bin/pdc,
# otherwise from PATH.

GAME   := Bunnyball
SOURCE := source
OUTPUT := $(GAME).pdx

PDC ?= $(if $(PLAYDATE_SDK_PATH),$(PLAYDATE_SDK_PATH)/bin/pdc,pdc)
SIM ?= $(if $(PLAYDATE_SDK_PATH),$(PLAYDATE_SDK_PATH)/bin/PlaydateSimulator,PlaydateSimulator)

.PHONY: all build run clean

all: build

build:
	$(PDC) $(SOURCE) $(OUTPUT)

run: build
	"$(SIM)" "$(OUTPUT)"

clean:
	rm -rf "$(OUTPUT)"
