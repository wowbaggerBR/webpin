/*-
 * Copyright (c) 2015 Erasmo Marín <erasmo.marin@gmail.com>
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace Webpin {
    public class WebAppWindow : Gtk.ApplicationWindow {

        private bool is_full_screen = false;

        private string style_str =   """@define-color titlebar_color @titlebar_color;""";

        //widgets
        private WebApp web_app;
        private WebBar headerbar;

        public WebAppWindow (string webapp_name, string webapp_uri) {

            set_wmclass(webapp_uri, webapp_uri);
            web_app = new WebApp(webapp_name, webapp_uri);

            headerbar = new WebBar(web_app.external_view);
            headerbar.show_close_button = true;
            headerbar.title = webapp_name;
            headerbar.set_title_mode (WebBar.title_mode.TITLE);

            //style
            if (web_app.ui_color != "none") {
                try {
                    print("set color");
                    var style_cp = style_str.replace ("@titlebar_color", web_app.ui_color);
                    var style_provider = new Gtk.CssProvider ();
                    style_provider.load_from_data (style_cp, -1);
                    headerbar.get_style_context ().add_provider (style_provider, -1);
                    Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", should_use_dark_theme (web_app.ui_color));
                } catch (GLib.Error err) {
         	        warning("Loading style failed");
                }
            }

            web_app.theme_color_changed.connect( (color)=> {
                try {
                    print("set color");
                    var style_cp = style_str.replace ("@titlebar_color", color);
                    var style_provider = new Gtk.CssProvider ();
                    style_provider.load_from_data (style_cp, -1);
                    headerbar.get_style_context ().add_provider (style_provider, -1);
                    Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", should_use_dark_theme (color));
                } catch (GLib.Error err) {
         	        warning("Loading style failed");
                }
            });

            this.set_titlebar (headerbar);

            var info = DesktopFile.get_app_by_url(webapp_uri);
            var width = info.get_string("WebpinWindowWidth");
            var height = info.get_string("WebpinWindowHeight");

            if(width !=null && height != null)
              set_default_size (int.parse(width), int.parse(height));
            else
              set_default_size (1000, 600);
            this.delete_event.connect (() => {
                update_window_state(this.get_allocated_width (), this.get_allocated_height () );
                return false;
	          });

            this.destroy.connect(Gtk.main_quit);

            web_app.external_request.connect ( () => {
                print("Web app external request\n");
                web_app.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT);
                headerbar.set_title_mode (WebBar.title_mode.BROWSER);
                web_app.set_visible_child_name ("external");
            });

            headerbar.back_event.connect ( () => {
                print ("back");
                headerbar.set_title_mode (WebBar.title_mode.TITLE);
                web_app.set_transition_type (Gtk.StackTransitionType.SLIDE_RIGHT);
                web_app.set_visible_child_name ("app");
                //wait the animation to end before "cleaning" the web view
                GLib.Timeout.add(web_app.get_transition_duration(), () => {
                    web_app.external_view.load_uri ("about:blank");
                    return false;
                });
            });

            add(web_app);
            show_all();
        }

        public new void fullscreen () {
            is_full_screen = true;
            base.fullscreen();
        }

        public new void unfullscreen () {
            is_full_screen = false;
            base.unfullscreen();
        }

        public void toggle_fullscreen() {
            if(is_full_screen)
                unfullscreen();
            else
                fullscreen();
            is_full_screen = !is_full_screen;
        }

      public void update_window_state (int width, int height) {
          var file = web_app.get_desktop_file();
          file.edit_propertie ("WebpinWindowWidth", width.to_string());
          file.edit_propertie ("WebpinWindowHeight", height.to_string());
      }

        public override bool key_press_event (Gdk.EventKey event) {
            bool handled = true;
            switch (event.keyval) {
            case Gdk.Key.Escape:
                unfullscreen();
                break;
            case Gdk.Key.F11:
                toggle_fullscreen();
                break;
            default:
                handled = false;
                break;
            }

            if (handled)
                return true;

            return (base.key_press_event != null) ? base.key_press_event (event) : true;
        }

        private bool should_use_dark_theme (string theme_color) {
            Gdk.RGBA color = {};
            color.parse (theme_color);

            double prom = (color.red + color.blue + color.green)/3;

            if (prom < 0.5)
                return true;
            return false;
        }
    }
}
