//
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Clutter;
using Meta;

namespace Gala.Plugins.AlternateAltTab
{
	public delegate void ObjectCallback (Object object);

	class Settings : Granite.Services.Settings
	{
		public bool all_workspaces { get; set; default = false; }
		public bool animate { get; set; default = true; }
		public bool always_on_primary_monitor { get; set; default = false; }
		public int icon_size { get; set; default = 128; }

		static Settings? instance = null;

		private Settings ()
		{
			base ("org.pantheon.desktop.gala.plugins.alternate-alt-tab");
		}

		public static Settings get_default ()
		{
			if (instance == null)
				instance = new Settings ();

			return instance;
		}
	}

	public class Main : Gala.Plugin
	{
		const int INDICATOR_BORDER = 6;
		const double ANIMATE_SCALE = 0.8;

		public bool opened { get; private set; default = false; }

		Gala.WindowManager? wm = null;
		Gala.ModalProxy modal_proxy = null;
		Actor wrapper;
		Actor indicator;

		int modifier_mask;

		Gee.ArrayList<PreviewPage> pages;
		
		private WindowActorClone? current {
			get {
				return current_page.current;
			}
		}

		PreviewPage? current_page = null;
		unowned Workspace? current_workspace = null;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;

			pages = new Gee.ArrayList<PreviewPage> ();

			KeyBinding.set_custom_handler ("switch-applications", handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-applications-backward", handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows", handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows-backward", handle_switch_windows);

			wrapper = new Actor ();
			wrapper.background_color = { 0, 0, 0, 190 };
			wrapper.reactive = true;
			wrapper.set_pivot_point (0.5f, 0.5f);
			wrapper.key_release_event.connect (key_relase_event);

			indicator = new Actor ();
			indicator.background_color = { 255, 255, 255, 180 };
			indicator.width = INDICATOR_BORDER * 2;
			indicator.height = INDICATOR_BORDER * 2;

			wrapper.add_child (indicator);
		}

		public override void destroy ()
		{
			if (wm == null)
				return;
		}

		void handle_switch_windows (Display display, Screen screen, Window? window,
			KeyEvent? event, Meta.KeyBinding binding)
		{
			var settings = Settings.get_default ();
			var workspace = settings.all_workspaces ? null : screen.get_active_workspace ();

			current_workspace = workspace;

			// copied from gnome-shell, finds the primary modifier in the mask
			var mask = binding.get_mask ();
			if (mask == 0)
				modifier_mask = 0;
			else {
				modifier_mask = 1;
				while (mask > 1) {
					mask >>= 1;
					modifier_mask <<= 1;
				}
			}

			if (!opened) {
				collect_windows (display, workspace);
				open_switcher ();

				update_indicator_position ();
			}

			var binding_name = binding.get_name ();
			var backward = binding_name.has_suffix ("-backward");

			//  bool s = (ModifierType.SHIFT_MASK in get_current_modifiers ());
			//  if (Meta.VirtualModifier.SHIFT_MASK in binding.get_modifiers ()) {
			//  	print ("BACKWARD".to_string () + "\n");
			//  }

			// FIXME for unknown reasons, switch-applications-backward won't be emitted, so we
			//       test manually if shift is held down
			backward = binding_name == "switch-windows"
				&& (get_current_modifiers () & ModifierType.SHIFT_MASK) != 0;

				//  print (backward.to_string () + "\n");
				next_window (display, workspace, backward);
		}

		void collect_windows (Display display, Workspace? workspace)
		{
			var screen = wm.get_screen ();

			var windows = display.get_tab_list (TabList.NORMAL, workspace);
			var current_window = display.get_tab_current (TabList.NORMAL, workspace);

			pages.clear ();
			var page = new PreviewPage (screen);
			foreach (var window in windows) {
				var actor = get_actor_for_window (window);
				var clone = new WindowActorClone (actor);
				clone.activate.connect (on_clone_activated);

				page.add_window_actor (clone);
				if (window == current_window) {
					page.current = clone;
				}
			}

			page.reallocate (false);
			pages.add (page);
		}

		void on_window_added (Window window)
		{
			if (current_page == null) {
				return;
			}

			Idle.add (() => {
				unowned Display display = window.get_display ();
				int index = display.get_tab_list (TabList.NORMAL, window.get_workspace ()).index (window);
				if (index != -1) {
					var actor = (Meta.WindowActor)window.get_compositor_private ();
					var clone = new WindowActorClone (actor);
					clone.activate.connect (on_clone_activated);

					current_page.add_window_actor (clone, index);
					current_page.reallocate ();
					update_indicator_position ();
				}

				return false;
			});
		}

		void on_window_removed (Window window)
		{
			if (current_page == null) {
				return;
			}

			if (current_page.remove_window (window)) {
				current_page.reallocate ();
				update_indicator_position ();
			} else {
				close_switcher (Gdk.CURRENT_TIME);
			}
		}

		void on_clone_activated (WindowActorClone clone)
		{
			current_page.current = clone;
			update_indicator_position ();
			
			// Wait 50ms to make the indicator visible for a bit
			Timeout.add (50, () => {
				close_switcher (Gdk.CURRENT_TIME);
				return false;
			});
		}

		Meta.WindowActor? get_actor_for_window (Meta.Window window)
		{
			Meta.WindowActor? window_actor = null;
			unowned List<Meta.WindowActor> actors = Compositor.get_window_actors (wm.get_screen ());
			actors.@foreach ((actor) => {
				if (actor.get_meta_window () == window) {
					window_actor = actor;
					return;
				}
			});

			return window_actor;
		}

		void open_switcher ()
		{
			if (current_workspace != null) {
				current_workspace.window_added.connect (on_window_added);
				current_workspace.window_removed.connect (on_window_removed);
			}

			if (pages.size == 0) {
				return;
			}

			if (opened) {
				return;
			}

			if (current_page != null) {
				wrapper.remove_child (current_page);
			}
			
			current_page = pages[0];
			wrapper.add_child (current_page);

			var screen = wm.get_screen ();
			var settings = Settings.get_default ();

			if (settings.animate) {
				//  wrapper.opacity = 0;
			}

			int width, height;
			screen.get_size (out width, out height);
			wrapper.width = width;
			wrapper.height = height;

			wm.ui_group.insert_child_above (wrapper, null);

			//  wrapper.save_easing_state ();
			wrapper.opacity = 255;
			//  wrapper.restore_easing_state ();

			modal_proxy = wm.push_modal ();
			modal_proxy.keybinding_filter = keybinding_filter;
			opened = true;

			wrapper.grab_key_focus ();

			// if we did not have the grab before the key was released, close immediately
			if ((get_current_modifiers () & modifier_mask) == 0)
				close_switcher (screen.get_display ().get_current_time ());
		}

		void close_switcher (uint32 time)
		{
			if (!opened)
				return;

			wm.pop_modal (modal_proxy);
			opened = false;

			if (current_workspace != null) {
				current_workspace.window_added.disconnect (on_window_added);
				current_workspace.window_removed.disconnect (on_window_removed);
			}

			ObjectCallback remove_actor = () => {
				wm.ui_group.remove_child (wrapper);
			};

			if (Settings.get_default ().animate) {
				wrapper.opacity = 0;

				var transition = wrapper.get_transition ("opacity");
				if (transition != null)
					transition.completed.connect (() => remove_actor (this));
				else
					remove_actor (this);

			} else {
				remove_actor (this);
			}

			if (current.window == null) {
				return;
			}

			activate_window (current.window, time);
		}

		void activate_window (Meta.Window window, uint32 time)
		{
			var workspace = window.get_workspace ();
			if (workspace != wm.get_screen ().get_active_workspace ())
				workspace.activate_with_focus (window, time);
			else
				window.activate (time);
		}

		void next_window (Display display, Workspace? workspace, bool backward)
		{
			current_page.next (backward);
			update_indicator_position ();
		}

		void update_indicator_position ()
		{
			current.attach_indicator (indicator);
		}

		bool key_relase_event (KeyEvent event)
		{
			if ((get_current_modifiers () & modifier_mask) == 0) {
				close_switcher (event.time);
				return true;
			}

			switch (event.keyval) {
				case Key.Escape:
					close_switcher (event.time);
					return true;
			}

			return false;
		}

		static Gdk.ModifierType get_current_modifiers ()
		{
			Gdk.ModifierType modifiers;
			double[] axes = {};
			Gdk.Display.get_default ().get_default_seat ().get_pointer ()
				.get_state (Gdk.get_default_root_window (), axes, out modifiers);

			return modifiers;
		}

		bool keybinding_filter (KeyBinding binding)
		{
			if (!binding.is_builtin ())
			return true;

			// otherwise we determine by name if it's meant for us
			var name = binding.get_name ();

			return !(name == "switch-applications" || name == "switch-applications-backward"
				|| name == "switch-windows" || name == "switch-windows-backward");
		}
	}
}

public Gala.PluginInfo register_plugin ()
{
	return Gala.PluginInfo () {
		name = "Alternate Alt Tab",
		author = "Gala Developers",
		plugin_type = typeof (Gala.Plugins.AlternateAltTab.Main),
		provides = Gala.PluginFunction.WINDOW_SWITCHER,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}

