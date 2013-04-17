MAKENSIS = "$(shell which makensis.exe 2> /dev/null)"
DIST_PATH= -p ../ProgrammingGauche -p ../Meadow -p ../Gauche-mingw-dist/Gauche
GEN_TARGET = setup.nsi
GAUCHE_VERSION = $(shell cat ../Gauche/VERSION 2> /dev/null)
TARGET = Gauchebox-$(GAUCHE_VERSION).exe

all: gen build

gen: $(GEN_TARGET)

$(GEN_TARGET): $(GEN_TARGET).in
	gosh ./file-list.scm $(DIST_PATH) -t $(GEN_TARGET).in -v $(GAUCHE_VERSION)

build: $(TARGET)

$(TARGET): $(GEN_TARGET)
ifneq ($(MAKENSIS), "")
	$(MAKENSIS) $(GEN_TARGET)
endif

clean:
	@if test -f $(GEN_TARGET); then \
		rm $(GEN_TARGET); \
	fi
	@if test -f $(TARGET); then \
		rm $(TARGET); \
	fi

