# Sabre Fighter Plane Simulator - Makefile
# Builds for macOS (.app bundle + .dmg) and Linux

APP_NAME    = Sabre
VERSION     = 0.2.4b
REV_DATE    = 11/21/99
BUNDLE      = $(APP_NAME).app
DMG         = $(APP_NAME).dmg

CXX         = c++
CC          = cc

CXXFLAGS    = -std=c++11 -Wall -O2 -fPIC -Isrc \
              -DVERSION=\"$(VERSION)\" -DREV_DATE=\"$(REV_DATE)\"
CFLAGS      = -Wall -O2 -fPIC -Isrc \
              -DVERSION=\"$(VERSION)\" -DREV_DATE=\"$(REV_DATE)\"

UNAME_S := $(shell uname -s)

SDL_CFLAGS  := $(shell pkg-config --cflags sdl2 SDL2_mixer)
SDL_LIBS    := $(shell pkg-config --libs sdl2 SDL2_mixer)
SDL_DEFINES  = -DHAVE_LIBSDL=1

ifeq ($(UNAME_S),Darwin)
  # Static link SDL2 + SDL2_mixer, dynamic link their codec deps
  SDL2_A     := $(shell brew --prefix sdl2)/lib/libSDL2.a
  SDL2MIX_A  := $(shell brew --prefix sdl2_mixer)/lib/libSDL2_mixer.a
  FRAMEWORKS := -framework Cocoa -framework CoreAudio -framework AudioToolbox \
                -framework CoreVideo -framework IOKit -framework Carbon \
                -framework ForceFeedback -framework Metal -framework QuartzCore \
                -framework CoreFoundation -framework CoreHaptics \
                -framework GameController -framework AudioUnit \
                -framework CoreServices -framework CoreMIDI -framework AppKit
  # Dynamic libs for mixer codec deps (will be bundled in .app)
  CODEC_LIBS := -L/opt/homebrew/lib $(shell pkg-config --libs-only-l flac libmpg123 vorbis vorbisfile ogg opus opusfile libxmp wavpack libgme fluidsynth 2>/dev/null) -lstdc++ -lz
  LDFLAGS    = $(SDL2MIX_A) $(SDL2_A) $(FRAMEWORKS) $(CODEC_LIBS) -lobjc -lm -liconv
  MENU_SRC   = src/menu_mac.mm
else
  LDFLAGS    = $(SDL_LIBS) -lm
  MENU_SRC   = src/menu.C
endif

# Source files (no SDL dependency)
CORE_CXX = \
  src/aaaunit.C src/aibase.C src/aiflite.C src/aigunner.C \
  src/aipilot.C src/aipilot2.C src/aipilot3.C src/aipilot4.C \
  src/aipilot5.C src/aipilot6.C src/bits.C src/clip.C \
  src/cockpit.C src/colormap.C src/colorspc.C src/convpoly.C \
  src/copoly.C src/cpoly.C src/dvector.C src/earth.C \
  src/flight.C src/fltlite.C src/fltmngr.C src/fltobj.C \
  src/fltzview.C src/font8x8.C src/fontdev.C src/game.C \
  src/globals.C src/grndunit.C src/group_3d.C src/hud.C \
  src/instrmnt.C src/key_map.C src/led2.C src/linux_joy.C \
  src/moveable.C src/mytimer.C src/obj_3d.C src/pen.C \
  src/pilobj.C src/pilot.C src/plltt.C src/port_3d.C \
  src/portkey.C src/ppm.C src/rendpoly.C src/rndrpoly.C \
  src/rndzpoly.C src/rotate.C src/sairfld.C src/sarray.C \
  src/sattkr.C src/sbfltmdl.C src/sbrkeys.C src/scnedit.C \
  src/sfltmdl.C src/sfrmtn.C src/simfile.C src/simfilex.C \
  src/siminput.C src/simmath.C src/smath.C src/smnvrst.C \
  src/sobject.C src/spilcaps.C src/splncaps.C src/srunway.C \
  src/sslewer.C src/stact.C src/starget.C src/swaypnt.C \
  src/sweapon.C src/target.C src/terrain.C src/transblt.C \
  src/traveler.C src/txtrmap.C src/unguided.C src/viewobj.C \
  src/vmath.C src/vtable2.C src/waypoint.C src/weapons.C \
  src/zview.C

CORE_C = src/dhlist.c src/spid.c src/stime.c \
         libzip/bits.c libzip/crc.c libzip/deflate.c \
         libzip/inflate.c libzip/trees.c libzip/unc.c

# SDL-aware files
SDL_CXX = src/kbdhit.C src/main.C src/input.C src/vga_13.C src/simsnd.C

# Objects
CORE_CXX_O = $(CORE_CXX:.C=.o)
CORE_C_O   = $(CORE_C:.c=.o)
SDL_CXX_O  = $(SDL_CXX:.C=.o)
ifeq ($(suffix $(MENU_SRC)),.mm)
  MENU_O = $(MENU_SRC:.mm=.o)
else
  MENU_O = $(MENU_SRC:.C=.o)
endif

ALL_O = $(CORE_CXX_O) $(CORE_C_O) $(SDL_CXX_O) $(MENU_O)
TARGET = src/sabre

.PHONY: all clean app dmg run universal

all: $(TARGET)

$(TARGET): $(ALL_O)
	$(CXX) -o $@ $^ $(LDFLAGS)

$(CORE_CXX_O): %.o: %.C
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(CORE_C_O): %.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(SDL_CXX_O): %.o: %.C
	$(CXX) $(CXXFLAGS) $(SDL_DEFINES) $(SDL_CFLAGS) -c -o $@ $<

src/menu_mac.o: src/menu_mac.mm
	$(CXX) $(CXXFLAGS) $(SDL_DEFINES) $(SDL_CFLAGS) -c -o $@ $<

src/menu.o: src/menu.C
	$(CXX) $(CXXFLAGS) $(SDL_DEFINES) $(SDL_CFLAGS) -c -o $@ $<

run: $(TARGET)
	cd . && ./$(TARGET)

clean:
	rm -f $(ALL_O) $(TARGET)
	rm -rf $(BUNDLE) $(DMG)
	rm -rf build-x86_64 build-arm64 build-sdl-inc

# --- Universal (fat) binary via frameworks ---
ifeq ($(UNAME_S),Darwin)
UNI_SDLINC    = build-sdl-inc/SDL2
UNI_FWFLAGS   = -F/Library/Frameworks -F$(HOME)/Library/Frameworks \
                -Ibuild-sdl-inc
UNI_FRAMEWORKS = -F/Library/Frameworks -F$(HOME)/Library/Frameworks \
                 -framework SDL2 -framework SDL2_mixer \
                 $(FRAMEWORKS) -lobjc -lm -liconv -lstdc++
UNI_CXXFLAGS  = -std=c++11 -Wall -O2 -fPIC -Isrc \
                -DVERSION=\"$(VERSION)\" -DREV_DATE=\"$(REV_DATE)\"
UNI_CFLAGS    = -Wall -O2 -fPIC -Isrc \
                -DVERSION=\"$(VERSION)\" -DREV_DATE=\"$(REV_DATE)\"

define build_arch
	@echo "=== Building $(1) ==="
	@mkdir -p build-$(1)/src build-$(1)/libzip
	@for f in $(CORE_CXX); do \
	  $(CXX) -arch $(1) $(UNI_CXXFLAGS) -c -o build-$(1)/$${f%.C}.o $$f; \
	done
	@for f in $(CORE_C); do \
	  $(CC) -arch $(1) $(UNI_CFLAGS) -c -o build-$(1)/$${f%.c}.o $$f; \
	done
	@for f in $(SDL_CXX); do \
	  $(CXX) -arch $(1) $(UNI_CXXFLAGS) $(SDL_DEFINES) $(UNI_FWFLAGS) -c -o build-$(1)/$${f%.C}.o $$f; \
	done
	@$(CXX) -arch $(1) $(UNI_CXXFLAGS) $(SDL_DEFINES) $(UNI_FWFLAGS) -c -o build-$(1)/src/menu_mac.o src/menu_mac.mm
	@$(CXX) -arch $(1) -o build-$(1)/sabre \
	  $$(find build-$(1) -name '*.o') $(UNI_FRAMEWORKS)
endef

universal:
	@mkdir -p $(UNI_SDLINC)
	@ln -sf /Library/Frameworks/SDL2.framework/Headers/* $(UNI_SDLINC)/
	@ln -sf $(HOME)/Library/Frameworks/SDL2_mixer.framework/Headers/* $(UNI_SDLINC)/
	$(call build_arch,x86_64)
	$(call build_arch,arm64)
	@echo "=== Creating universal binary ==="
	lipo -create build-x86_64/sabre build-arm64/sabre -output src/sabre
	lipo -info src/sabre
	@echo "=== Universal binary ready ==="
endif

# --- macOS .app bundle ---
ifeq ($(UNAME_S),Darwin)
SDL2_FW     = /Library/Frameworks/SDL2.framework
SDL2MIX_FW  = $(HOME)/Library/Frameworks/SDL2_mixer.framework

app: universal
	@echo "=== Creating $(BUNDLE) ==="
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources/lib
	mkdir -p $(BUNDLE)/Contents/Frameworks
	cp $(TARGET) $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin
	cp -R lib/* $(BUNDLE)/Contents/Resources/lib/
	@[ -f Sabre.icns ] && cp Sabre.icns $(BUNDLE)/Contents/Resources/ || true
	@echo "Bundling frameworks..."
	cp -R $(SDL2_FW) $(BUNDLE)/Contents/Frameworks/
	cp -R $(SDL2MIX_FW) $(BUNDLE)/Contents/Frameworks/
	install_name_tool -add_rpath @executable_path/../Frameworks $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin
	@echo "Re-signing bundle..."
	@codesign --force --sign - $(BUNDLE)/Contents/Frameworks/SDL2.framework
	@codesign --force --sign - $(BUNDLE)/Contents/Frameworks/SDL2_mixer.framework
	@codesign --force --sign - $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin
	@printf '#!/bin/bash\nDIR="$$(dirname "$$0")"\ncd "$$DIR/../Resources"\nexec "$$DIR/$(APP_NAME)-bin" "$$@"\n' \
	  > $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	chmod +x $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	@printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>CFBundleExecutable</key><string>$(APP_NAME)</string>' \
	  '  <key>CFBundleIdentifier</key><string>com.sabre.flightsim</string>' \
	  '  <key>CFBundleName</key><string>$(APP_NAME) Fighter Plane Simulator</string>' \
	  '  <key>CFBundleVersion</key><string>$(VERSION)</string>' \
	  '  <key>CFBundleShortVersionString</key><string>$(VERSION)</string>' \
	  '  <key>CFBundlePackageType</key><string>APPL</string>' \
	  '  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>' \
	  '  <key>CFBundleIconFile</key><string>Sabre</string>' \
	  '  <key>NSHighResolutionCapable</key><true/>' \
	  '</dict></plist>' > $(BUNDLE)/Contents/Info.plist
	@echo "--- External dependencies check ---"
	@otool -L $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin | grep -v /System | grep -v /usr/lib | grep -v @rpath | grep -v @executable
	@echo "--- Bundle contents ---"
	@du -sh $(BUNDLE)/Contents/Frameworks/
	@du -sh $(BUNDLE)
	@lipo -info $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin
	@echo "=== $(BUNDLE) ready ==="

dmg: app
	@echo "=== Creating $(DMG) ==="
	rm -rf /tmp/$(APP_NAME)-dmg $(DMG)
	mkdir -p /tmp/$(APP_NAME)-dmg
	cp -R $(BUNDLE) /tmp/$(APP_NAME)-dmg/
	ln -s /Applications /tmp/$(APP_NAME)-dmg/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder /tmp/$(APP_NAME)-dmg -ov -format UDZO $(DMG)
	rm -rf /tmp/$(APP_NAME)-dmg
	@ls -lh $(DMG)
	@echo "=== $(DMG) ready ==="
endif
