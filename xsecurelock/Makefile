##
# xsecurelock - custom module
#
# @file
# @version 0.1

CFLAGS=$(shell pkg-config --cflags --libs x11 xft fontconfig)

saver_battery: saver_battery.c
	$(CC) $(CFLAGS) saver_battery.c -o saver_battery
