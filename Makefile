APP_FILES = \
	TerminalFont \
	TerminalPTY \
	TerminalView \
	TerminalWindow \
	TerminalEmulator \
	main

NIBS = MainMenu TerminalWindow
FONTS = \
	fixed-13 \
	monaco-12 \
	vga-16 \
	terminus-32

APPEXTRAS = Info.plist Credits.rtf fvterm.icns

APPDIR = build/fvterm.app/Contents



CC = /usr/bin/gcc-4.2

CFLAGS = -std=gnu99 -Wall -Werror -Wno-multichar \
	 -Ibuild -Winvalid-pch

# For debuggability:
CFLAGS += -O0 -ggdb -DDEBUG

# For building the test dylib on !Darwin:
# CFLAGS += -DNOT_DARWIN

LDFLAGS = -framework Cocoa



default: build/fvterm.bin build/libfvterm.dylib $(NIBS:%=build/%.nib) $(FONTS:%=build/%.vtf)
	@mkdir -p $(APPDIR)/{MacOS,Resources}/
	cp build/fvterm.bin $(APPDIR)/MacOS/fvterm
	cp -a $(NIBS:%=build/%.nib) $(FONTS:%=build/%.vtf) $(APPEXTRAS) \
	    $(APPDIR)/Resources/
	cp Info.plist $(APPDIR)/

build/fontpacker: build/TerminalFont.o build/fontpacker.o
	$(CC) $(LDFLAGS) $+ -o build/fontpacker

build/fvterm.bin: $(APP_FILES:%=build/%.o)
	$(CC) $(LDFLAGS) $+ -o $@

build/libfvterm.dylib: build/TerminalEmulator.o build/libfvterm.o
	libtool -dynamic -lc -exported_symbols_list libfvterm.exp $+ -o $@

build/%.gch: %.h
	$(CC) -c $(CFLAGS) -x objective-c-header $< -o $@

build/%.o: %.[cm] build/Prefix.gch
	$(CC) -MMD -MP -c $(CFLAGS) $< -o $@

build/%.nib: %.xib
	ibtool $< --compile $@

build/%.vtf: build/fontpacker fonts/%/fontconfig.ini
	touch $@
	build/fontpacker fonts/$*/fontconfig.ini $@

-include $(APP_FILES:%=build/%.d)

.PHONY: build/fvterm.app
.PRECIOUS: build/Prefix.gch

run: default
	$(APPDIR)/MacOS/fvterm

debug: default
	@gdb -x .gdbscript $(APPDIR)/MacOS/fvterm

clean:
	rm -rf \
	    build/*.{o,d,vtf,nib} \
	    build/{fvterm.app,fvterm.bin,fontpacker}
