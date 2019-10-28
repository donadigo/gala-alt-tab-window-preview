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

using Meta;
using Gala;
using Clutter;

namespace Gala.Plugins.AlternateAltTab
{
    public class PreviewPage : Clutter.Actor
    { 
        const int MIN_OFFSET = 64;
		const int SPACING = 18;
        const float MIN_CLONE_SCALE = 0.14f;
        const float MAX_CLONE_SCALE = 0.5f;

        public Screen screen { get; construct; }
        public WindowActorClone? current { get; set; }
        public Clutter.Actor container;

        public PreviewPage (Screen screen) {
            Object (screen: screen);
        }

        construct {
            var monitor = screen.get_current_monitor ();
            var geom = screen.get_monitor_geometry (monitor);
            set_position (MIN_OFFSET, MIN_OFFSET);
            set_size (geom.width - MIN_OFFSET * 2, geom.height - MIN_OFFSET * 2);

            container = new Clutter.Actor ();
            container.set_size (width, -1);
            //  container.set_easing_duration (300);
            //  container.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);

            add_child (container);
        }

        public bool add_window_actor (WindowActorClone window_actor, int index = -1) {
            window_actor.queue_reallocate.connect (queue_reallocate);
            container.insert_child_at_index (window_actor, index);
            return true;
        }

        public bool remove_window (Window window) {
            foreach (unowned Clutter.Actor child in container.get_children ()) {
                unowned WindowActorClone? clone = child as WindowActorClone;
                if (clone != null && clone.window == window) {
                    if (clone == current) {
                        current = (WindowActorClone?)(clone.get_next_sibling () ?? clone.get_previous_sibling ());
                    }

                    clone.queue_reallocate.disconnect (queue_reallocate);
                    container.remove_child (clone);
                    break;
                }
            }

            return current != null;
        }

        public bool next (bool backward) {
            if (!backward) {
                current = current.get_next_sibling () as WindowActorClone;
                if (current == null) {
                    current = container.get_first_child () as WindowActorClone;
                }

            } else {
                current = current.get_previous_sibling () as WindowActorClone;
                if (current == null) {
                    current = container.get_last_child () as WindowActorClone;
                }
            }

            return current != null;
        }

        public void reallocate (bool animate = true)
        {
            var children = container.get_children ();

            float current_height = 0;
            float current_width = 0;

            float max_width = width;

            var row_children = new Gee.ArrayList<WindowActorClone> ();

            float sscale = calculate_preferred_clone_scale ();

            foreach (unowned Actor child in children) {
                unowned WindowActorClone? clone = child as WindowActorClone;
                if (clone == null) {
                    continue;
                }
                
                clone.compute_final_size_for_scale (sscale);

                if (clone.final_width > max_width - current_width) {
                    float max_row_height = allocate_align_row (row_children, max_width, current_height);

                    current_height += max_row_height + SPACING;
                    row_children.clear ();
                    current_width = 0;
                }

                current_width += clone.final_width;
                if (row_children.size > 0) {
                    current_width += SPACING;
                }

                row_children.add (clone);
            }

            if (row_children.size > 0) {
                current_height += allocate_align_row (row_children, max_width, current_height);
            }

            foreach (unowned Actor child in children) {
                unowned WindowActorClone? clone = child as WindowActorClone;
                if (clone == null) {
                    continue;
                }

                clone.update_scale (sscale, animate);
            }

            container.set_position (width / 2 - container.width / 2, height / 2 - container.height / 2);
        }

        void queue_reallocate ()
        {
            Idle.add (() => {
                reallocate ();
                return false; 
            });
        }

        float allocate_align_row (Gee.ArrayList<WindowActorClone> actors, float max_width, float y)
        {
            float real_width = 0;
            float max_height = 0;
            foreach (var actor in actors) {
                real_width += actor.final_width;
                max_height = float.max (max_height, actor.final_height);
            }

            int spacing;
            if (actors.size > 1) {
                spacing = (actors.size - 1) * SPACING;
            } else {
                spacing = 0;
            }

            real_width += spacing;

            float row_offset = (max_width - real_width) / 2;
            float actor_offset = 0;
            for (int i = 0; i < actors.size; i++) {
                var actor = actors[i];
                int actor_spacing;
                if (i != 0) {
                    actor_spacing = SPACING;
                } else {
                    actor_spacing = 0;
                }

                actor.set_position (
                    (row_offset + actor_offset + actor_spacing),
                    (y + (max_height / 2 - actor.final_height / 2))
                );

                actor_offset += actor.final_width + actor_spacing;
            }

            return max_height;
        }

        float calculate_preferred_clone_scale ()
        {
            float available_area = width * height;
            float sum_window_area = 0.0f;

            foreach (unowned Actor child in container.get_children ()) {
                unowned WindowActorClone? clone = child as WindowActorClone;
                if (clone == null) {
                    continue;
                }

                var frame_rect = clone.window.get_frame_rect ();
                sum_window_area += frame_rect.width * frame_rect.height;
            }

            return (available_area / sum_window_area).clamp (MIN_CLONE_SCALE, MAX_CLONE_SCALE);
        }
    }
}