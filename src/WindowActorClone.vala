/*-
 * Copyright (c) 2019 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class Gala.Plugins.AlternateAltTab.WindowActorClone : Clutter.Actor {
    public Meta.WindowActor window_actor { get; construct; }
    public Meta.Window window { get; construct; }

    public Clutter.Actor container { get; private set; }
    public signal void activate ();
    public signal void queue_reallocate ();

    public float final_width { get; private set; }
    public float final_height { get; private set; }

    const float MIN_CONTAINER_SIZE = 80.0f;

    Clutter.Clone clone;
    WindowIcon window_icon;
    Clutter.Actor close_button;

    ulong check_confirm_dialog_cb = 0;

    static IndicatorAlignConstraint indicator_align_constraint;
    static construct {
        indicator_align_constraint = new IndicatorAlignConstraint (null);
    }

    construct {
        reactive = true;

        clone = new Clutter.Clone (window_actor.get_texture ());

        container = new Clutter.Actor ();
        container.add (clone);

        //  set_easing_duration (300);
        //  set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);

        window_actor.notify["allocation"].connect (() => queue_reallocate ());

        var constraint = new WindowIconAlignConstraint (container);

        window_icon = new WindowIcon (window, 64);
        window_icon.add_constraint (constraint);

        close_button = Utils.create_close_button ();
        close_button.set_position (-close_button.width / 2, -close_button.height / 2);
        close_button.opacity = 0;
        close_button.set_easing_duration (200);
        close_button.button_press_event.connect (() => {
            close_window ();
            return true;
        });

        var click = new Clutter.ClickAction ();
        click.clicked.connect (() => {
            activate ();
        });

        add_action (click);

        add_child (container);
        add_child (window_icon);
        add_child (close_button);
    }

    public WindowActorClone (Meta.WindowActor window_actor) {
        Object (window_actor: window_actor, window: window_actor.get_meta_window ());
    }

    public void compute_final_size_for_scale (float scale)
    {
        fix_small_scale (ref scale);
        var rect = window_actor.get_meta_window ().get_frame_rect ();
        final_width = (float)(rect.width * scale);
        final_height = (float)(rect.height * scale) + window_icon.height / 2;
    }

    public void update_scale (float sscale, bool animate = true)
    {
        fix_small_scale (ref sscale);
        update_clone (sscale);

        //  const double[] keyframes = { 0.5, 1.0 };
        //  Value[] xval = { container.scale_x, sscale };

        //  if (animate) {
        //      var xtransition = new Clutter.KeyframeTransition ("scale-x");
        //      xtransition.remove_on_complete = true;
        //      xtransition.duration = 300;
        //      xtransition.set_from_value (container.scale_x);
        //      xtransition.set_to_value (sscale);
        //      xtransition.set_key_frames (keyframes);
        //      xtransition.set_values (xval);

        //      var ytransition = new Clutter.KeyframeTransition ("scale-y");
        //      ytransition.duration = 300;
        //      ytransition.remove_on_complete = true;
        //      ytransition.set_from_value (container.scale_y);
        //      ytransition.set_to_value (sscale);
        //      ytransition.set_key_frames (keyframes);
        //      ytransition.set_values (xval);

        //      container.add_transition ("scale-x", xtransition);
        //      container.add_transition ("scale-y", ytransition);
        //  } else {
            container.set_scale (sscale, sscale);
        //  }
    }

    public void attach_indicator (Clutter.Actor indicator)
    {
        unowned Clutter.Actor? parent = indicator.get_parent ();
        if (parent != null) {
            parent.remove_child (indicator);
        }

        unowned Clutter.Constraint? constraint = indicator.get_constraint ("indicator-constraint");
        if (constraint != null) {
            indicator.remove_constraint (constraint);
        }

        insert_child_below (indicator, null);
        indicator_align_constraint.source = container;
        indicator.add_constraint_with_name ("indicator-constraint", indicator_align_constraint);
    }

    public override	bool enter_event (Clutter.CrossingEvent event)
    {
        close_button.opacity = 255;
        return false;
    }
    
    public override	bool leave_event (Clutter.CrossingEvent event)
    {
        close_button.opacity = 0;
        return false;
    }

    void update_clone (float sscale)
    {
        var rect = window_actor.get_meta_window ().get_frame_rect ();
        container.set_size (rect.width, rect.height);

        float pvx, pvy;
        container.get_pivot_point (out pvx, out pvy);

        float x_offset = rect.x - window_actor.x;
        float y_offset = rect.y - window_actor.y;
        clone.set_position (-x_offset, -y_offset);
        clone.set_clip (x_offset, y_offset, rect.width, rect.height);

        set_size (rect.width * sscale, rect.height * sscale);
    }

    // Do not allow window containers to be smaller than MIN_CONTAINER_SIZE
    void fix_small_scale (ref float sscale)
    {
        var rect = window_actor.get_meta_window ().get_frame_rect ();
        if (rect.width * sscale < MIN_CONTAINER_SIZE ||
            rect.height * sscale < MIN_CONTAINER_SIZE) {
            sscale = MIN_CONTAINER_SIZE / float.min (rect.width, rect.height);
        }
    }

    void close_window ()
    {
        unowned Meta.Screen screen = window.get_screen ();
        check_confirm_dialog_cb = screen.window_entered_monitor.connect (check_confirm_dialog);

        window.@delete (screen.get_display ().get_current_time ());
    }

    void check_confirm_dialog (int monitor, Meta.Window new_window)
    {
        if (new_window.get_transient_for () == window) {
            Idle.add (() => {
                activate ();
                return false;
            });

            SignalHandler.disconnect (window.get_screen (), check_confirm_dialog_cb);
            check_confirm_dialog_cb = 0;
        }
    }
}
