# Copyright (c) 2010 Aldo Cortesi
# Copyright (c) 2010, 2014 dequis
# Copyright (c) 2012 Randall Ma
# Copyright (c) 2012-2014 Tycho Andersen
# Copyright (c) 2012 Craig Barnes
# Copyright (c) 2013 horsik
# Copyright (c) 2013 Tao Sauvage
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from typing import List  # noqa: F401
from copy import deepcopy
import subprocess

from libqtile import bar, layout, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

mod = "mod4"
terminal = "kitty"

CCOLORS = dict(
    background='#000000',
    foreground='#FFFFFF',
    lila= '#de1fd2',
    gray= '#C4C4C4',
    darkgray= '#7D7D7D',
)

################ KEYBINDIGNS  ###########

def call_screen_lock(qtile):
    subprocess.call(["loginctl", "lock-session"])
    subprocess.call(["picom", "&", "disown"])

keys = [
    # Switch between windows
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.next(),
        desc="Move window focus to other window"),

    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(),
        desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(),
        desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(),
        desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),


    # switch between screens
    Key([mod], "Left", lazy.prev_screen()),
    Key([mod], "Right", lazy.next_screen()),

    # Swap columns
    Key([mod, "shift", "control"], "H", lazy.layout.swap_column_left()),
    Key([mod, "shift", "control"], "L", lazy.layout.swap_column_right()),

    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "h", lazy.layout.grow_left(),
        desc="Grow window to the left"),
    Key([mod, "control"], "l", lazy.layout.grow_right(),
        desc="Grow window to the right"),
    Key([mod, "control"], "j", lazy.layout.grow_down(),
        desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),


    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),

    # Toggle between split and unsplit sides of stack.
    # Split = all windows displayed
    # Unsplit = 1 window displayed, like Max layout, but still with
    # multiple stack panes
    Key([mod, "control"], "Return", lazy.layout.toggle_split(),
        desc="Toggle between split and unsplit sides of stack"),

    Key([mod], "Up", lazy.layout.maximize()),
    Key([mod], "Down", lazy.layout.normalize()),

    # QTile Shortcuts
    Key([mod, "control"], "r", lazy.restart(), desc="Restart Qtile"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod, "control"], "w", lazy.window.kill(), desc="Kill focused window"),
    Key([mod, "control"], "f", lazy.window.toggle_floating(), desc='toggle floating'),
    #Key([mod, "control"], "l", lazy.function(call_screen_lock), desc='lock screen'),
    Key([mod], "f",lazy.window.toggle_fullscreen(),desc='toggle fullscreen'),

    # spawn launcher
    Key([mod], "r", lazy.spawn("rofi -show run -monitor -4"), desc="Run rofi"),
    Key([mod, "shift"], "r", lazy.spawn("better-bwmenu"), desc="Run better-bwmenu"),
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),

]

groups = [Group(i) for i in "123456789"]

for i in groups:
    keys.extend([
        # mod1 + letter of group = switch to group
        Key([mod], i.name, lazy.group[i.name].toscreen(),
            desc="Switch to group {}".format(i.name)),

        # mod1 + shift + letter of group = switch to & move focused window to group
        # Key([mod, "shift"], i.name, lazy.window.togroup(i.name, switch_group=True),
        #     desc="Switch to & move focused window to group {}".format(i.name)),
        # Or, use below if you prefer not to switch to that group.

        # send window to group
        Key([mod, "shift"], i.name, lazy.window.togroup(i.name),
            desc="move focused window to group {}".format(i.name)),
    ])


default_layout_settings = dict(
    margin= 8,
    border_on_single=True,
    border_width= 4,
    border_focus= CCOLORS['lila'],
    border_normal= CCOLORS['gray'],
)

layouts = [
    layout.Columns(**default_layout_settings,
                   border_focus_stack='#dd2121',   # focus color when in max column
                   border_normal_stack=CCOLORS['gray'], # normal color when in max column
    ),
    layout.VerticalTile(**default_layout_settings,),
    layout.Max(**default_layout_settings),

    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2, **default_layout_settings),
    # layout.Bsp(),
    # layout.Matrix(),
    # layout.MonadTall(),
    # layout.MonadWide(),

    # layout.RatioTile(**default_layout_settings),
    # layout.Tile(),
    # layout.TreeTab(),
    # layout.Zoomy(),
]

widget_defaults = dict(
    font='Hack',
    fontsize=12,
    padding=5,
)

extension_defaults = widget_defaults.copy()


# get a custom bar object
def custom_bar(main=True):
    return bar.Bar([
        # just a black spacer
        widget.Sep(linewidth=0, padding=6), 
        widget.CurrentLayout(),
        widget.GroupBox(active='#FFFFFF',                                     # color of active groups
                        inacitve=CCOLORS['gray'], # color of inactive groups
                        rounded=False,
                        highlight_color=CCOLORS['lila'], # focused group
                        highlight_method="block",
                        this_current_screen_border = CCOLORS['lila'],
                        this_screen_border = CCOLORS['darkgray'],
                        other_current_screen_border = CCOLORS['lila'],
                        other_screen_border = CCOLORS['darkgray'],
        ),
        widget.WindowName(),
        widget.Systray(),
        widget.TextBox('|' if main else ''),
        widget.CapsNumLockIndicator(),
        widget.TextBox('|'),
        widget.Clock(format='%H:%M | %a, %d.%m.'),
        widget.Sep(linewidth=0, padding=20),
    ],
    30,
    #background='#00000000',
    )

screens = [
    Screen(
        top=custom_bar(),
        wallpaper='/home/joseph/Pictures/wallpapers/orion_nebula_wide.png',
    ),
    Screen(
        top=custom_bar(False),
        wallpaper='/home/joseph/Pictures/wallpapers/orion_nebula_tall.png',
    ),
]

# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
         start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front())
]


dgroups_app_rules = []  # type: List
main = None  # WARNING: this is deprecated and will be removed soon
follow_mouse_focus = False
bring_front_click = True
cursor_warp = False
floating_layout = layout.Floating(float_rules=[
    # Run the utility of `xprop` to see the wm class and name of an X client.
    *layout.Floating.default_float_rules,
    Match(wm_class='confirmreset'),  # gitk
    Match(wm_class='makebranch'),  # gitk
    Match(wm_class='maketag'),  # gitk
    Match(wm_class='ssh-askpass'),  # ssh-askpass
    Match(title='branchdialog'),  # gitk
    Match(title='pinentry'),  # GPG key password entry
])
auto_fullscreen = True
focus_on_window_activation = "smart"

# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
