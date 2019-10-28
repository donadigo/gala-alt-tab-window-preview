
using Clutter;
using Meta;

namespace Gala.Plugins.AlternateAltTab.ActorUtils
{
    static void get_final_position (Clutter.Actor actor, out float x, out float y)
    {
        unowned Transition? t = actor.get_transition ("position");
        if (t != null) {
            var point = (Point?)t.interval.final.get_boxed ();
            x = point.x;
            y = point.y;
        } else {
            actor.get_position (out x, out y);
        }
    }

    public static void get_final_scale (Clutter.Actor actor, out double scale_x, out double scale_y)
    {
        unowned Transition? t = actor.get_transition ("scale-x");
        if (t != null) {
            scale_x = t.interval.final.get_double ();
        } else {
            scale_x = actor.scale_x;
        }

        t = actor.get_transition ("scale-y");
        if (t != null) {
            scale_y = t.interval.final.get_double ();
        } else {
            scale_y = actor.scale_y;
        }
    }
}