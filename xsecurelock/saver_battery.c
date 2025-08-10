#include <X11/extensions/Xrender.h>
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
    int retcode = 0;
    Display *display;
    char* window_id_str;
    unsigned int window_id;
    Window window;
    int screen;
    int percentage;
    char text[64];
    char* font_name;

    FcResult result;
    FcPattern *pattern, *match_pattern;
    XftFont *xft_font;
    XftDraw *xft_draw;
    XftColor xft_color;
    XRenderColor render_color = {
        .red = 0xffff,
        .green = 0xffff,
        .blue = 0xffff,
        .alpha = 0xffff
    };

    // Open a connection to the X server
    display = XOpenDisplay(NULL);
    if (display == NULL) {
        fprintf(stderr, "saver_battery: error: could not open display\n");
        return 1;
    }

    // Get the window ID from the environment variable provided by xsecurelock
    window_id_str = getenv("XSCREENSAVER_WINDOW");
    if (window_id_str == NULL) {
        fprintf(stderr, "saver_battery: error: XSCREENSAVER_WINDOW environment variable not set\n");
        XCloseDisplay(display);
        return 1;
    }

    // Convert the window ID from a string to a Window type
    window_id = strtoul(window_id_str, NULL, 10);
    window = (Window)window_id;

    screen = DefaultScreen(display);

    if (!FcInit()) {
        fprintf(stderr, "saver_battery: ERROR: could not initialze fontconfig\n");
        XCloseDisplay(display);
        return 1;
    }

    // Get the font used by xsecurelock, or a fallback if not set
    font_name = getenv("XSECURELOCK_FONT");
    if (font_name == NULL || strcmp(font_name, "") == 0) {
        font_name = "monospace:size=10";
    }

    // Create a fontconfig pattern from the font name
    pattern = FcNameParse((const FcChar8 *)font_name);
    if (!pattern) {
        fprintf(stderr, "saver_battery: error: could not parse font name '%s'\n", font_name);
        XCloseDisplay(display);
        FcFini();
        return 1;
    }

    // Find the best matching font and load it
    FcConfigSubstitute(NULL, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);
    match_pattern = FcFontMatch(NULL, pattern, &result);
    if (!match_pattern) {
        fprintf(stderr, "saver_battery: error: could not find a matching font for '%s'\n", font_name);
        FcPatternDestroy(pattern);
        XCloseDisplay(display);
        FcFini();
        return 1;
    }

    xft_font = XftFontOpenPattern(display, match_pattern);
    if (!xft_font) {
        fprintf(stderr, "saver_battery: error: could not open xft font\n");
        FcPatternDestroy(pattern);
        FcPatternDestroy(match_pattern);
        XCloseDisplay(display);
        FcFini();
        return 1;
    }

    FcPatternDestroy(pattern);

    // Create an XftDraw object for drawing text
    xft_draw = XftDrawCreate(display, window, DefaultVisual(display, screen), DefaultColormap(display, screen));
    if (!xft_draw) {
        fprintf(stderr, "saver_battery: error: could not create XftDraw object\n");
        XftFontClose(display, xft_font);
        XCloseDisplay(display);
        FcFini();
        return 1;
    }

    // Allocate an XftColor for the text
    if (!XftColorAllocValue(display, DefaultVisual(display, screen), DefaultColormap(display, screen), &render_color, &xft_color)) {
        fprintf(stderr, "saver_battery: error: could not allocate XftColor\n");
        XftDrawDestroy(xft_draw);
        XftFontClose(display, xft_font);
        XCloseDisplay(display);
        FcFini();
        return 1;
    }

    // Main event loop
    while (1) {
        int percentage = get_battery_percentage();
        char text[64];

        // Get window dimensions to center the text
        XWindowAttributes win_attrs;
        XGetWindowAttributes(display, window, &win_attrs);
        int x, y;

        // Clear the window before drawing
        XClearWindow(display, window);
        XGlyphInfo extents;

        if (percentage >= 0) {
            if (percentage > 100) {
                snprintf(text, sizeof(text), "Charging: %d%%", percentage - 101);
            } else {
                snprintf(text, sizeof(text), "Battery: %d%%", percentage);
            }
        } else {
            snprintf(text, sizeof(text), "Battery Info Unavailable");
        }

        XftTextExtents8(display, xft_font, (const FcChar8 *)text, strlen(text), &extents);
        x = (win_attrs.width - extents.width) / 2;
        y = (win_attrs.height + xft_font->ascent - xft_font->descent) * .9 ;
        XftDrawString8(xft_draw, &xft_color, xft_font, x, y, (const FcChar8 *)text, strlen(text));

        // Flush the display to make sure the drawing is visible
        XFlush(display);

        // Sleep for 5 seconds before updating the display
        sleep(5);
    }

    // TODO: move clean up to SIGTERM

end_xftcolor:
    XftColorFree(display, DefaultVisual(display, screen), DefaultColormap(display, screen), &xft_color);
end_xftdraw:
    XftDrawDestroy(xft_draw);
end_xftfont:
    XftFontClose(display, xft_font);
end_fc:
    FcFini();
end_xdisplay:
    XCloseDisplay(display);
end:
    return retcode;
}
