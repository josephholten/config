#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xft/Xft.h>
#include <fontconfig/fontconfig.h>

// Function to read the battery percentage from the system
int get_battery_percentage() {
    FILE *f;
    char path[256];
    char capacity_path[256];
    char status_path[256];
    char status[16];
    int capacity = -1;

    // Find the first battery in the system
    snprintf(path, sizeof(path), "/sys/class/power_supply/BAT0");
    f = fopen(path, "r");
    if (f == NULL) {
        // Fallback to BAT1, etc.
        snprintf(path, sizeof(path), "/sys/class/power_supply/BAT1");
        f = fopen(path, "r");
        if (f == NULL) {
            return -1; // No battery found
        }
    }
    fclose(f);

    // Read the battery capacity
    snprintf(capacity_path, sizeof(capacity_path), "%s/capacity", path);
    f = fopen(capacity_path, "r");
    if (f) {
        if (fscanf(f, "%d", &capacity) != 1) {
            capacity = -1;
        }
        fclose(f);
    }

    // Check if the battery is charging
    snprintf(status_path, sizeof(status_path), "%s/status", path);
    f = fopen(status_path, "r");
    if (f) {
        if (fscanf(f, "%s", status) == 1) {
            if (strcmp(status, "Charging") == 0) {
                // Return a positive number for charging
                // Add a visual indicator in the UI
                capacity = capacity > 0 ? capacity : 101;
            }
        }
        fclose(f);
    }

    return capacity;
}

int main(void) {
    Display *display;
    Window window;
    XFontStruct *font;
    GC gc;
    XGCValues gc_values;
    XEvent event;
    char text[64];
    int screen;

    FcPattern *pattern;
    XftFont *xft_font;
    XftDraw *xft_draw;
    XftColor xft_color;

    // Open a connection to the X server
    display = XOpenDisplay(NULL);
    if (display == NULL) {
        fprintf(stderr, "Error: Could not open display.\n");
        return 1;
    }

    // Get the window ID from the environment variable provided by xsecurelock
    char *window_id_str = getenv("XSCREENSAVER_WINDOW");
    if (window_id_str == NULL) {
        fprintf(stderr, "Error: XSCREENSAVER_WINDOW environment variable not set.\n");
        XCloseDisplay(display);
        return 1;
    }

    // Convert the window ID from a string to a Window type
    unsigned long window_id = strtoul(window_id_str, NULL, 10);
    window = (Window)window_id;

    screen = DefaultScreen(display);

    if (!FcInit()) {
        fprintf(stderr, "saver_battery: ERROR: could not initialze fontconfig\n");
        XCloseDisplay(display);
        return 1;
    }

    // Get the font used by xsecurelock, or a fallback if not set
    char *font_name = getenv("XSECURELOCK_FONT");
    if (font_name == NULL || strcmp(font_name, "") == 0) {
        font_name = "monospace";
    }
    font = XLoadQueryFont(display, font_name);
    if (font == NULL) {
        fprintf(stderr, "saver_battery: could not load font '%s', using 'fixed'.\n", font_name);
        font = XLoadQueryFont(display, "fixed");
    }

    // Create a graphics context for drawing
    gc_values.foreground = WhitePixel(display, screen);
    gc = XCreateGC(display, window, GCForeground, &gc_values);
    XSetFont(display, gc, font->fid);

    // Main event loop
    while (1) {
        int percentage = get_battery_percentage();

        if (percentage >= 0) {
            // Clear the window before drawing
            XClearWindow(display, window);

            if (percentage > 100) {
                 snprintf(text, sizeof(text), "Charging: %d%%", percentage - 101);
            } else {
                 snprintf(text, sizeof(text), "Battery: %d%%", percentage);
            }

            int text_width = XTextWidth(font, text, strlen(text));
            int text_height = font->ascent + font->descent;

            // Get window dimensions to center the text
            XWindowAttributes win_attrs;
            XGetWindowAttributes(display, window, &win_attrs);

            int x = (win_attrs.width - text_width) / 2;
            int y = (win_attrs.height + text_height) * .75;

            // Draw the text
            XDrawString(display, window, gc, x, y, text, strlen(text));
        } else {
             // Handle case where battery information could not be retrieved
             XClearWindow(display, window);
             snprintf(text, sizeof(text), "Battery Info Unavailable");
             int text_width = XTextWidth(font, text, strlen(text));
             int text_height = font->ascent + font->descent;

             XWindowAttributes win_attrs;
             XGetWindowAttributes(display, window, &win_attrs);

             int x = (win_attrs.width - text_width) / 2;
             int y = (win_attrs.height + text_height) / 2;
             XDrawString(display, window, gc, x, y, text, strlen(text));
        }

        // Flush the display to make sure the drawing is visible
        XFlush(display);

        // Sleep for 5 seconds before updating the display
        sleep(5);
    }

    // Clean up (this part is technically unreachable in the infinite loop)
    XUnloadFont(display, font->fid);
    XFreeGC(display, gc);
    XCloseDisplay(display);

    return 0;
}
