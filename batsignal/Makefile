CFLAGS=$(shell pkg-config --cflags --libs x11 xft fontconfig)

fullscreen_warning: fullscreen_warning.c
	$(CC) $(CFLAGS) fullscreen_warning.c -o fullscreen_warning

install: fullscreen_warning
	cp fullscreen_warning $(HOME)/bin

clean:
	rm -rf fullscreen_warning
