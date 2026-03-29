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

.PHONY: all clean app dmg run

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

# --- macOS .app bundle ---
ifeq ($(UNAME_S),Darwin)
app: $(TARGET)
	@echo "=== Creating $(BUNDLE) ==="
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources/lib
	mkdir -p $(BUNDLE)/Contents/Frameworks
	@# Copy binary
	cp $(TARGET) $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin
	@# Copy resources
	cp -R lib/* $(BUNDLE)/Contents/Resources/lib/
	@# Bundle dylibs and fix paths
	@echo "Bundling dynamic libraries..."
	@for dylib in $$(otool -L $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin | \
	    grep -oE '/opt/homebrew[^ ]+' | sort -u); do \
	  name=$$(basename "$$dylib"); \
	  cp "$$dylib" $(BUNDLE)/Contents/Frameworks/"$$name"; \
	  install_name_tool -change "$$dylib" "@executable_path/../Frameworks/$$name" \
	    $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin; \
	done
	@# Fix dylib cross-references
	@for fw in $(BUNDLE)/Contents/Frameworks/*.dylib; do \
	  for dep in $$(otool -L "$$fw" | grep -oE '/opt/homebrew[^ ]+'); do \
	    depname=$$(basename "$$dep"); \
	    [ -f "$(BUNDLE)/Contents/Frameworks/$$depname" ] || \
	      cp "$$dep" "$(BUNDLE)/Contents/Frameworks/$$depname" 2>/dev/null; \
	    install_name_tool -change "$$dep" "@executable_path/../Frameworks/$$depname" "$$fw" 2>/dev/null; \
	  done; \
	done
	@# Second pass for transitive deps
	@for fw in $(BUNDLE)/Contents/Frameworks/*.dylib; do \
	  for dep in $$(otool -L "$$fw" | grep -oE '/opt/homebrew[^ ]+'); do \
	    depname=$$(basename "$$dep"); \
	    [ -f "$(BUNDLE)/Contents/Frameworks/$$depname" ] || \
	      cp "$$dep" "$(BUNDLE)/Contents/Frameworks/$$depname" 2>/dev/null; \
	    install_name_tool -change "$$dep" "@executable_path/../Frameworks/$$depname" "$$fw" 2>/dev/null; \
	  done; \
	done
	@# Re-sign everything after install_name_tool changes
	@echo "Re-signing bundle..."
	@codesign --force --sign - $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin
	@for fw in $(BUNDLE)/Contents/Frameworks/*.dylib; do \
	  codesign --force --sign - "$$fw"; \
	done
	@# Create launcher that sets working dir
	@printf '#!/bin/bash\nDIR="$$(dirname "$$0")"\ncd "$$DIR/../Resources"\nexec "$$DIR/$(APP_NAME)-bin" "$$@"\n' \
	  > $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	chmod +x $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	@# Info.plist
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
	  '  <key>NSHighResolutionCapable</key><true/>' \
	  '</dict></plist>' > $(BUNDLE)/Contents/Info.plist
	@# Verify
	@echo "--- External dependencies check ---"
	@otool -L $(BUNDLE)/Contents/MacOS/$(APP_NAME)-bin | grep -v /System | grep -v /usr/lib | grep -v @executable
	@echo "--- Bundle contents ---"
	@echo "Frameworks: $$(ls $(BUNDLE)/Contents/Frameworks/ | wc -l) dylibs"
	@echo "Resources:  $$(ls $(BUNDLE)/Contents/Resources/lib/ | wc -l) files"
	@du -sh $(BUNDLE)
	@echo "=== $(BUNDLE) ready ==="

dmg: app
	@echo "=== Creating $(DMG) ==="
	rm -f $(DMG)
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(BUNDLE) -ov -format UDZO $(DMG)
	@ls -lh $(DMG)
	@echo "=== $(DMG) ready ==="
endif
