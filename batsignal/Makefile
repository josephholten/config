PKG_CFLAGS = $(shell pkg-config --cflags --libs x11 xft fontconfig xrandr)

fullscreen_warning: fullscreen_warning.c
	$(CC) $(CFLAGS) $(PKG_CFLAGS) fullscreen_warning.c -o fullscreen_warning

install: fullscreen_warning
	cp fullscreen_warning $(HOME)/bin

uninstall:
	rm -rf $(HOME)/bin/fullscreen_warning

clean:
	rm -rf fullscreen_warning
