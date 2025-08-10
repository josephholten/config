#include <X11/extensions/Xrender.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xft/Xft.h>
#include <fontconfig/fontconfig.h>

#define JASSERT_GOTO(COND, LBL, MSG...) do { if(!(COND)) { retcode = 1; fprintf(stderr, __FILE__ ": error: " MSG); sleep(1); goto LBL; }} while (0)

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
        if (fscanf(f, "%d", &capacity) != 1)
            capacity = -1;
        fclose(f);
    }

    // Check if the battery is charging
    snprintf(status_path, sizeof(status_path), "%s/status", path);
    f = fopen(status_path, "r");
    if (f) {
        if (fscanf(f, "%s", status) == 1 && strcmp(status, "Charging") == 0)
            capacity += 100;
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
    GC gc;
    XGCValues gc_values;

    display = XOpenDisplay(NULL);
    JASSERT_GOTO(display != NULL, end, "could not open display\n");

    window_id_str = getenv("XSCREENSAVER_WINDOW");
    JASSERT_GOTO(window_id_str != NULL, end_xdisplay, "XSCREENSAVER_WINDOW env var not set\n");

    window_id = strtoul(window_id_str, NULL, 10);
    window = (Window)window_id;
    screen = DefaultScreen(display);

    gc_values.foreground = BlackPixel(display, screen);
    gc = XCreateGC(display, window, GCForeground, &gc_values);

    JASSERT_GOTO(FcInit(), end_xdisplay, "could not init fontconfig\n");

    font_name = getenv("XSECURELOCK_FONT");
    if (font_name == NULL || strcmp(font_name, "") == 0) {
        font_name = "monospace:size=10";
    }

    pattern = FcNameParse((const FcChar8 *)font_name);
    JASSERT_GOTO(pattern, end_fc, "could not parse font name '%s'\n", font_name);

    FcConfigSubstitute(NULL, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);
    match_pattern = FcFontMatch(NULL, pattern, &result);
    JASSERT_GOTO(match_pattern, end_pattern, "could not find a matching pattern for '%s'\n", font_name);

    xft_font = XftFontOpenPattern(display, match_pattern);
    JASSERT_GOTO(xft_font, end_xftfont, "could not open xft font for '%s'\n", font_name);

    xft_draw = XftDrawCreate(display, window, DefaultVisual(display, screen), DefaultColormap(display, screen));
    JASSERT_GOTO(xft_draw, end_xftdraw, "could not create XftDraw object\n");

    JASSERT_GOTO(
        XftColorAllocValue(
            display,
            DefaultVisual(display, screen),
            DefaultColormap(display, screen),
            &render_color,
            &xft_color
        ),
        end_xftcolor,
        "could not allocate XftColor object\n"
    );

    while (1) {
        int percentage = get_battery_percentage();
        char text[64];

        // Get window dimensions to center the text
        XWindowAttributes win_attrs;
        XGetWindowAttributes(display, window, &win_attrs);
        int x, y;

        // Clear the window before drawing
        XFillRectangle(display, window, gc, 0, 0, win_attrs.width, win_attrs.height);
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
        XFlush(display);
        sleep(1);
    }

    // TODO: move clean up to SIGTERM

end_xftcolor:
    XftColorFree(display, DefaultVisual(display, screen), DefaultColormap(display, screen), &xft_color);
end_xftdraw:
    XftDrawDestroy(xft_draw);
end_xftfont:
    XftFontClose(display, xft_font);
end_pattern:
    FcPatternDestroy(match_pattern);
    FcPatternDestroy(pattern);
end_fc:
    FcFini();
end_xdisplay:
    XCloseDisplay(display);
end:
    return retcode;
}
