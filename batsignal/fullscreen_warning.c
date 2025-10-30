#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/Xft/Xft.h>  // Add Xft headers
#include <X11/extensions/Xrandr.h> // for multi monitor info
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
  int width;
  int height;
} MonitorSize;

void get_monitor_size_where_mouse(Display *display, int screen, MonitorSize *monitor_size) {
    Window root = RootWindow(display, screen);

    Window root_return, child_return;
    int root_x, root_y, win_x, win_y;
    unsigned int mask_return;
    XQueryPointer(display, root, &root_return, &child_return,
                  &root_x, &root_y, &win_x, &win_y, &mask_return);

    XRRScreenResources *resources = XRRGetScreenResources(display, root);
    int done = 0;

    for (int i = 0; i < resources->noutput && !done; i++) {
        XRROutputInfo *output = XRRGetOutputInfo(display, resources, resources->outputs[i]);
        if (output->connection == RR_Connected && output->crtc) {
            XRRCrtcInfo *crtc = XRRGetCrtcInfo(display, resources, output->crtc);

            if (root_x >= crtc->x && root_x < crtc->x + (int)crtc->width && root_y >= crtc->y && root_y < crtc->y + (int)crtc->height) {
              monitor_size->width = crtc->width;
              monitor_size->height = crtc->height;
              done = 1;
            }

            XRRFreeCrtcInfo(crtc);
        }
        XRRFreeOutputInfo(output);
    }
    XRRFreeScreenResources(resources);
}


int main(int argc, char** argv) {
    Display *display;
    Window window;
    XEvent event;
    int screen;
    GC gc;

    const char* message = "BATTERY CRITICALLY LOW";
    const char* USAGE = "usage: %s [-m message] [-f font] [-b bg_color] [-t text_color] [-h]\n";
    const char* font = "Liberation Mono";
    const char* color_str = "red";
    const char* tcolor_str = "white";

    int opt;
    while ((opt = getopt(argc, argv, "m:f:hb:t:")) != -1) {
      switch (opt) {
        case 'm':
          message = optarg;
          break;
        case 'f':
          font = optarg;
          break;
        case 'h':
          printf(USAGE, argv[0]);
          return 0;
        case 'b':
          color_str = optarg;
          break;
        case 't':
          tcolor_str = optarg;
          break;
        default:
          fprintf(stderr, "warning: ignoring unrecognized option '%c'", opt);
          fprintf(stderr, USAGE, argv[0]);
          break;
      }
    }

    display = XOpenDisplay(NULL);
    if (display == NULL) {
        fprintf(stderr, "ERROR: fullscreen: Cannot open display\n");
        return 1;
    }

    screen = DefaultScreen(display);

    MonitorSize monitor;
    get_monitor_size_where_mouse(display, screen, &monitor);

    Colormap colormap = DefaultColormap(display, screen);

    XColor color, tcolo;
    if (!XParseColor(display, colormap, color_str, &color)) {
      fprintf(stderr, "ERROR: failed to parse color: %s\n", color_str);
      XCloseDisplay(display);
      return 1;
    }

    if (!XAllocColor(display, colormap, &color)) {
      fprintf(stderr, "ERROR: failed to allocate color: %s\n", color_str);
      return 1;
    }

    unsigned long border_width = 0, border = BlackPixel(display, screen),
      background = color.pixel;
    int win_x = 0, win_y = 0;

    window = XCreateSimpleWindow(display, RootWindow(display, screen),
      win_x, win_y, monitor.width, monitor.height, border_width, border,
      background);

    XStoreName(display, window, "Critical Warning");

    XClassHint class_hint;
    class_hint.res_name = "critical_warning";
    class_hint.res_class = "CriticalWarning";
    XSetClassHint(display, window, &class_hint);

    Atom wm_state = XInternAtom(display, "_NET_WM_STATE", False);
    Atom fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", False);

    XEvent fullscreen_event;
    memset(&fullscreen_event, 0, sizeof(fullscreen_event));

    fullscreen_event.type = ClientMessage;
    fullscreen_event.xclient.window = window;
    fullscreen_event.xclient.message_type = wm_state;
    fullscreen_event.xclient.format = 32;
    fullscreen_event.xclient.data.l[0] = 1;  // _NET_WM_STATE_ADD
    fullscreen_event.xclient.data.l[1] = fullscreen;
    fullscreen_event.xclient.data.l[2] = 0;

    XSelectInput(display, window, ExposureMask | KeyPressMask);

    gc = XCreateGC(display, window, 0, 0);

    Visual *visual = DefaultVisual(display, screen);

    XftFont* xft_font = XftFontOpen(display, screen,
      XFT_FAMILY, XftTypeString, font,
      XFT_WEIGHT, XftTypeInteger, XFT_WEIGHT_BOLD,
      XFT_SIZE, XftTypeDouble, 64.0, NULL);

    if (!xft_font) {
      printf("ERROR: fullscreen: couldn't load font '%s' or any other fallback", font);

      XFreeGC(display, gc);
      XDestroyWindow(display, window);
      XCloseDisplay(display);

      return 1;
    }

    XftColor xft_color;
    XftColorAllocName(display, visual, colormap, tcolor_str, &xft_color);
    XftDraw *xft_draw = XftDrawCreate(display, window, visual, colormap);
    XMapRaised(display, window);
    XSendEvent(display, RootWindow(display, screen), False,
               SubstructureNotifyMask | SubstructureRedirectMask,
               &fullscreen_event);

    XFlush(display);

    while (1) {
        XNextEvent(display, &event);

        if (event.type == Expose) {
            if (xft_font) {
                XGlyphInfo extents;
                XftTextExtents8(display, xft_font, (XftChar8 *)message, strlen(message), &extents);

                int x = (monitor.width - extents.width) / 2;
                int y = (monitor.height + extents.height) / 2;

                XftDrawString8(xft_draw, &xft_color, xft_font, x, y,
                               (XftChar8 *)message, strlen(message));
            }
        } else if (event.type == KeyPress) {
            break;
        }
    }

    if (xft_font) XftFontClose(display, xft_font);
    XftDrawDestroy(xft_draw);
    XftColorFree(display, visual, colormap, &xft_color);

    XFreeGC(display, gc);
    XDestroyWindow(display, window);
    XCloseDisplay(display);

    return 0;
}
