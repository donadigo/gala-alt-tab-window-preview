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

public class Gala.Plugins.AlternateAltTab.WindowIconAlignConstraint : Clutter.Constraint {
    public Clutter.Actor container { get; construct; }

    public WindowIconAlignConstraint (Clutter.Actor container) {
        Object (container: container);
    }

    public override void update_allocation (Clutter.Actor actor, Clutter.ActorBox allocation) {
        float cwidth, cheight;
        container.get_transformed_size (out cwidth, out cheight);

        float actor_width, actor_height;
        actor.get_size (out actor_width, out actor_height);

        allocation.set_origin (cwidth / 2 - actor_width / 2, cheight - actor_height * 0.75f);
    }
}

public class Gala.Plugins.AlternateAltTab.IndicatorAlignConstraint : Clutter.Constraint {
    public Clutter.Actor? source { get; construct set; }
    const int INDICATOR_BORDER = 6;

    public IndicatorAlignConstraint (Clutter.Actor? source) {
        Object (source: source);
    }

    public override void update_allocation (Clutter.Actor actor, Clutter.ActorBox allocation) {
        if (source == null) {
            return;
        }

        float twidth, theight;
        source.get_transformed_size (out twidth, out theight);

        float actor_width, actor_height;
        actor.get_size (out actor_width, out actor_height);

        float px = 0, py = 0;
        allocation.set_origin (px - INDICATOR_BORDER, py - INDICATOR_BORDER);
        allocation.set_size (twidth + INDICATOR_BORDER * 2, theight + INDICATOR_BORDER * 2);
    }
}
