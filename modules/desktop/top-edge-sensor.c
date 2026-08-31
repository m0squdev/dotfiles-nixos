/*
 * top-edge-sensor — run a command when the pointer touches the top of a screen.
 *
 * Why this exists: Waybar can hide and un-hide itself on SIGUSR1 (and can move
 * between layer-shell layers while doing so), but nothing in the stack can tell
 * it *when*. niri has no pointer-position IPC, and GTK3 has no generic hover
 * state — `:hover` is just GTK_STATE_FLAG_PRELIGHT, which only widgets that opt
 * in ever get. GtkWindow never does, which is why the `window#waybar:hover`
 * trick found in Hyprland dotfiles silently does nothing here (Waybar sets that
 * flag by hand, per module, in AModule::handleMouseEnter — that is the only
 * reason `#clock:hover` works).
 *
 * So the trigger has to be a real Wayland surface: a transparent layer-shell
 * strip pinned to the top edge, above everything, that reports pointer
 * enter/leave. That is all this program is. It holds no policy — bar-peek.sh
 * decides which strip should be listening and what the commands do.
 *
 * ONE STRIP PER MONITOR, EACH WITH ITS OWN STATE. Only the monitor showing the
 * focused fullscreen window has a bar that needs rescuing; the top edge of any
 * other screen must stay inert, or throwing the pointer up there peeks a bar
 * that was never covered. So `armed` and `revealed` are per strip, and at most
 * one strip is armed at a time. (niri only draws a *focused* fullscreen window
 * over the top layer, so at most one monitor can ever be in that state.)
 *
 * ARMING. While armed the strip claims pointer input over its whole area, so it
 * would swallow clicks meant for a visible bar. It therefore starts disarmed
 * (empty input region = fully click-through) and is armed only for as long as
 * something is actually covering that monitor's bar. Arming names a monitor, and
 * a signal cannot carry an argument, so it arrives as a line on stdin:
 *
 *     arm <x>,<y>   arm the monitor at that logical position, disarm the rest
 *     disarm        disarm every monitor
 *
 * Two things fall out of using a pipe. There is no longer a startup race to
 * lose: SIGUSR1 defaults to *terminate*, so bar-peek.sh had to wait for our
 * layer surface to appear before it dared signal, whereas a write to a pipe
 * simply waits in the buffer. And EOF means the driver is gone — including when
 * it was killed outright and its EXIT trap never ran — so we put the bar back
 * and shut down with it instead of being left behind, armed, with nobody left
 * to disarm us.
 *
 * The logical position is the join key because GDK will not tell us niri's
 * connector name. gdk_monitor_get_model() returns the EDID model — measured on
 * this machine, "M2352D" and "0x403D", never "HDMI-A-1" or "eDP-1". Position is
 * what both sides do agree on, and niri cannot place two outputs at the same one.
 *
 *     SIGHUP    hold     — click-through WITHOUT putting away what is revealed
 *     SIGWINCH  release  — resume watching
 *
 * Hold stays on signals precisely because it needs no argument. bar-peek.sh
 * drives it from a second background process (the swaync subscriber), and that
 * process would otherwise have to inherit the control pipe — one more writer
 * keeping it open, which is exactly what would stop EOF from meaning what it
 * says above.
 *
 * Hold exists for panels opened *from* whatever we revealed: a menu from the
 * bar lands in the middle of the screen, i.e. inside the region we watch, so
 * reaching for it would both dismiss the bar and have its first click eaten.
 * Held, the pointer passes straight through to the panel and the bar stays.
 * Release re-claims the input, and the compositor immediately reports the
 * pointer if it is already inside — so a pointer left below the bar puts it
 * away at that moment, exactly as if it had just moved there.
 *
 * (SIGHUP and SIGWINCH are not meaningful choices; GLib's signal source only
 * supports six signals and these are the two left over.)
 *
 * TWO SHAPES. The strip moves out of its own way, because triggering and
 * un-triggering want opposite geometry — and because whatever gets revealed has
 * to stay usable, which it cannot if this thing is sitting on top of it.
 *
 *   waiting   a --trigger-height tripwire (a couple of px) along the very top
 *             edge. The gesture has to actually reach the top of the screen
 *             rather than merely approach it; the pointer clamps at y=0, so
 *             throwing it upwards always lands inside.
 *   revealed  everything BELOW --reveal-offset, i.e. the whole screen except
 *             the band the revealed bar occupies. The bar is left completely
 *             uncovered and keeps its own clicks, while any pointer movement
 *             off it lands here.
 *
 * So both transitions are driven by *enter* and leave events are ignored: enter
 * the tripwire to reveal, enter the area below to put it away. Covering all of
 * the lower screen rather than a thin band under the bar is deliberate — a band
 * can be skipped entirely by one fast flick of the pointer, which would strand
 * the bar on screen. The cost is that this surface briefly owns clicks below
 * the bar, for the one frame between that first motion event and the commit
 * that shrinks it back.
 */
#define _GNU_SOURCE
#include <gtk/gtk.h>
#include <gtk-layer-shell.h>
#include <glib-unix.h>
#include <stdio.h>
#include <unistd.h>

static gint   opt_trigger_height = 2;
static gint   opt_reveal_offset  = 48;
static gchar *opt_enter  = NULL;
static gchar *opt_leave  = NULL;

/* One per monitor. Both flags are per strip: `armed` because only the monitor
 * whose bar is covered should be listening, `revealed` because it is that same
 * strip that has to change shape and change back. */
typedef struct {
    GtkWindow  *window;
    GdkMonitor *monitor;
    gboolean    armed;
    gboolean    revealed;
} Strip;

static GList   *strips = NULL;
static gboolean held   = FALSE;   /* watching suspended, reveal state kept */

static void run(const gchar *cmd) {
    GError *err = NULL;

    if (cmd == NULL || *cmd == '\0')
        return;
    /* Async, and without G_SPAWN_DO_NOT_REAP_CHILD so GLib double-forks and the
     * child is reaped by init — this fires often enough to matter. */
    if (!g_spawn_command_line_async(cmd, &err)) {
        g_warning("cannot run \"%s\": %s", cmd, err->message);
        g_clear_error(&err);
    }
}

/* Claim or release pointer input over the strip. queue_draw is what gets the
 * new region committed: gtk-layer-shell only pushes surface state on the next
 * frame, and a strip that never changes appearance would otherwise not draw. */
static void apply_input_region(Strip *strip) {
    GdkWindow *gdk_window = gtk_widget_get_window(GTK_WIDGET(strip->window));

    if (gdk_window == NULL)
        return;
    if (strip->armed && !held) {
        gdk_window_input_shape_combine_region(gdk_window, NULL, 0, 0);
    } else {
        cairo_region_t *none = cairo_region_create();
        gdk_window_input_shape_combine_region(gdk_window, none, 0, 0);
        cairo_region_destroy(none);
    }
    gtk_widget_queue_draw(GTK_WIDGET(strip->window));
}

/* Tripwire along the top edge, or everything below the revealed bar. Neither
 * transition can fabricate a crossing event: we only ever reveal with the
 * pointer at the very top (which the lower shape excludes) and only ever put
 * away with the pointer below the bar (which the tripwire excludes). */
static void apply_shape(Strip *strip) {
    GtkWidget *widget = GTK_WIDGET(strip->window);

    gtk_layer_set_anchor(strip->window, GTK_LAYER_SHELL_EDGE_BOTTOM, strip->revealed);
    gtk_layer_set_margin(strip->window, GTK_LAYER_SHELL_EDGE_TOP,
                         strip->revealed ? opt_reveal_offset : 0);
    /* Anchored top AND bottom, the compositor dictates the height and the
     * request would only act as an unwanted minimum. */
    gtk_widget_set_size_request(widget, -1, strip->revealed ? -1 : opt_trigger_height);
    gtk_widget_queue_draw(widget);
}

static void set_revealed(Strip *strip, gboolean on) {
    if (strip->revealed == on)
        return;
    strip->revealed = on;
    apply_shape(strip);
    run(on ? opt_enter : opt_leave);
}

static void set_armed(Strip *strip, gboolean armed) {
    if (strip->armed == armed)
        return;
    strip->armed = armed;
    apply_input_region(strip);

    /* Disarming mid-reveal: the pointer can no longer reach us to put things
     * back, so do it now. */
    if (!armed)
        set_revealed(strip, FALSE);
}

/* Only the input region moves; `revealed` is deliberately left alone, which is
 * the whole point of holding. */
static void set_held(gboolean on) {
    if (held == on)
        return;
    held = on;
    for (GList *l = strips; l != NULL; l = l->next)
        apply_input_region(l->data);
}

/* Leave events are deliberately not handled: which shape the pointer entered is
 * what carries the meaning, so one handler drives both directions. */
static gboolean on_enter(GtkWidget *w, GdkEventCrossing *ev, gpointer data) {
    Strip *strip = data;

    (void)w;
    if (ev->detail == GDK_NOTIFY_INFERIOR)
        return FALSE;
    set_revealed(strip, !strip->revealed);
    return FALSE;
}

/* The strip must never be seen. Painting it fully transparent (rather than
 * leaving the theme's window background) is why it needs an RGBA visual. */
static gboolean on_draw(GtkWidget *w, cairo_t *cr, gpointer data) {
    (void)w; (void)data;
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    return FALSE;
}

/* Read live rather than cached: a monitor can be moved or re-scaled under us,
 * and there is nothing to invalidate this way. */
static gboolean strip_is_at(Strip *strip, int x, int y) {
    GdkRectangle geom;

    gdk_monitor_get_geometry(strip->monitor, &geom);
    return geom.x == x && geom.y == y;
}

static void add_strip(GdkMonitor *monitor) {
    Strip *strip = g_new0(Strip, 1);
    GtkWidget *widget = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    GdkVisual *rgba = gdk_screen_get_rgba_visual(gtk_widget_get_screen(widget));

    strip->window = GTK_WINDOW(widget);
    strip->monitor = monitor;

    gtk_layer_init_for_window(strip->window);
    gtk_layer_set_namespace(strip->window, "top-edge-sensor");
    gtk_layer_set_monitor(strip->window, monitor);
    /* Overlay so it stays above fullscreen windows — niri draws a focused
     * fullscreen window over the *top* layer, which is exactly the case this
     * whole thing exists to detect. */
    gtk_layer_set_layer(strip->window, GTK_LAYER_SHELL_LAYER_OVERLAY);
    gtk_layer_set_anchor(strip->window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(strip->window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_anchor(strip->window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    /* -1, not 0: 0 would let the bar's own exclusive zone push the strip below
     * the bar, leaving the actual screen edge — where the pointer lands when you
     * throw it upwards — uncovered. -1 opts out and anchors to the real edge. */
    gtk_layer_set_exclusive_zone(strip->window, -1);
    gtk_layer_set_keyboard_mode(strip->window, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);

    gtk_widget_set_app_paintable(widget, TRUE);
    if (rgba != NULL)
        gtk_widget_set_visual(widget, rgba);
    gtk_widget_add_events(widget, GDK_ENTER_NOTIFY_MASK);
    g_signal_connect(widget, "draw", G_CALLBACK(on_draw), NULL);
    g_signal_connect(widget, "enter-notify-event", G_CALLBACK(on_enter), strip);

    /* A monitor that appears mid-peek starts disarmed and waiting, like every
     * other one: the peek belongs to whichever monitor bar-peek.sh armed. */
    apply_shape(strip);
    gtk_widget_show_all(widget);
    apply_input_region(strip);   /* needs the realized GdkWindow, so: after show */
    strips = g_list_prepend(strips, strip);
}

static void disarm_all(void) {
    for (GList *l = strips; l != NULL; l = l->next)
        set_armed(l->data, FALSE);
}

static gboolean on_command(GIOChannel *source, GIOCondition cond, gpointer data) {
    gchar *line = NULL;
    gsize len = 0;

    (void)data;
    if (cond & (G_IO_HUP | G_IO_ERR)) {
        /* bar-peek.sh is gone. Put away anything we revealed first — nothing
         * else is left that could take the bar back out of peek mode. */
        disarm_all();
        gtk_main_quit();
        return G_SOURCE_REMOVE;
    }

    /* Non-blocking, so this drains complete lines and stops at G_IO_STATUS_AGAIN
     * with any partial one still buffered for the next wake-up. */
    while (g_io_channel_read_line(source, &line, &len, NULL, NULL) == G_IO_STATUS_NORMAL) {
        int x, y;

        g_strstrip(line);
        if (sscanf(line, "arm %d,%d", &x, &y) == 2) {
            for (GList *l = strips; l != NULL; l = l->next)
                set_armed(l->data, strip_is_at(l->data, x, y));
        } else if (g_str_equal(line, "disarm")) {
            disarm_all();
        } else if (*line != '\0') {
            g_warning("unknown command \"%s\"", line);
        }
        g_clear_pointer(&line, g_free);
    }
    g_clear_pointer(&line, g_free);
    return G_SOURCE_CONTINUE;
}

static gboolean on_sighup(gpointer data)   { (void)data; set_held(TRUE);  return G_SOURCE_CONTINUE; }
static gboolean on_sigwinch(gpointer data) { (void)data; set_held(FALSE); return G_SOURCE_CONTINUE; }

static void on_monitor_added(GdkDisplay *display, GdkMonitor *monitor, gpointer data) {
    (void)display; (void)data;
    add_strip(monitor);
}

static void on_monitor_removed(GdkDisplay *display, GdkMonitor *monitor, gpointer data) {
    (void)display; (void)data;

    for (GList *l = strips; l != NULL; l = l->next) {
        Strip *strip = l->data;

        if (strip->monitor == monitor) {
            /* Unplugged mid-peek: --leave has to run, or the bar is left parked
             * over a fullscreen window on a screen that no longer exists. */
            set_armed(strip, FALSE);
            gtk_widget_destroy(GTK_WIDGET(strip->window));
            strips = g_list_delete_link(strips, l);
            g_free(strip);
            return;
        }
    }
}

static const GOptionEntry options[] = {
    { "trigger-height", 't', 0, G_OPTION_ARG_INT, &opt_trigger_height,
      "Height while waiting, in logical pixels (default 2)", "PX" },
    { "reveal-offset",  'r', 0, G_OPTION_ARG_INT, &opt_reveal_offset,
      "While revealed, watch everything below this y (default 48)", "PX" },
    { "enter",  'e', 0, G_OPTION_ARG_STRING, &opt_enter,
      "Command to run when the pointer reaches the strip", "CMD" },
    { "leave",  'l', 0, G_OPTION_ARG_STRING, &opt_leave,
      "Command to run when the pointer leaves it again", "CMD" },
    { NULL }
};

int main(int argc, char **argv) {
    GOptionContext *ctx = g_option_context_new("- reveal-on-top-edge sensor");
    GIOChannel *commands;
    GdkDisplay *display;
    GError *err = NULL;
    int n_monitors;

    /* First thing, before any work that could delay us: SIGHUP defaults to
     * *terminate*, and bar-peek.sh's swaync subscriber can hold us as soon as it
     * has a stream. */
    g_unix_signal_add(SIGHUP, on_sighup, NULL);
    g_unix_signal_add(SIGWINCH, on_sigwinch, NULL);

    g_option_context_add_main_entries(ctx, options, NULL);
    g_option_context_add_group(ctx, gtk_get_option_group(TRUE));
    if (!g_option_context_parse(ctx, &argc, &argv, &err)) {
        g_printerr("%s\n", err->message);
        return 1;
    }
    g_option_context_free(ctx);

    if (!gtk_layer_is_supported()) {
        g_printerr("compositor does not support the layer-shell protocol\n");
        return 1;
    }

    display = gdk_display_get_default();
    n_monitors = gdk_display_get_n_monitors(display);
    for (int i = 0; i < n_monitors; i++)
        add_strip(gdk_display_get_monitor(display, i));

    g_signal_connect(display, "monitor-added", G_CALLBACK(on_monitor_added), NULL);
    g_signal_connect(display, "monitor-removed", G_CALLBACK(on_monitor_removed), NULL);

    commands = g_io_channel_unix_new(STDIN_FILENO);
    g_io_channel_set_flags(commands, G_IO_FLAG_NONBLOCK, NULL);
    g_io_add_watch(commands, G_IO_IN | G_IO_HUP | G_IO_ERR, on_command, NULL);
    g_io_channel_unref(commands);

    gtk_main();
    return 0;
}
