import re
import unittest

from PIL import Image, ImageChops

import generate_ship_previews as previews


def map_with_window(window_path):
    """A window beside another window and a shuttle wall."""
    dmm = previews.Dmm.__new__(previews.Dmm)
    dmm.width = dmm.height = 3
    dmm.grid = {(x, y): "floor" for x in range(1, 4) for y in range(1, 4)}
    dmm.grid.update({(2, 2): "window", (2, 3): "neighbor", (3, 2): "wall"})
    dmm.key_paths = {
        "floor": ["/turf/open/floor/plating"],
        "window": [window_path, "/turf/open/floor/plating"],
        "neighbor": ["/obj/structure/window/reinforced/shuttle", "/turf/open/floor/plating"],
        "wall": ["/turf/closed/wall/mineral/titanium"],
    }
    return dmm


class WindowSpawnerTests(unittest.TestCase):
    def test_spawners_match_runtime_spawn_lists(self):
        source = (previews.REPO_ROOT / "code/game/objects/effects/spawners/structure.dm").read_text()
        for spawner, window in previews.WINDOW_SPAWNERS.items():
            with self.subTest(spawner=spawner):
                definition = re.search(r"^" + re.escape(spawner) + r"\n((?:\t[^\n]*\n)*)", source, re.M)
                self.assertIsNotNone(definition)
                spawn_list = re.search(r"spawn_list = list\(([^\n]*)\)", definition.group(1))
                self.assertIsNotNone(spawn_list)
                self.assertIn(window, spawn_list.group(1).split(", "))

    def test_spawners_render_like_placed_windows(self):
        background = Image.new("RGBA", (96, 96), (40, 40, 40, 255))
        for spawner, window in previews.WINDOW_SPAWNERS.items():
            with self.subTest(spawner=spawner):
                expected = previews.apply_smoothing_fixes(map_with_window(window), background, background)
                actual = previews.apply_smoothing_fixes(map_with_window(spawner), background, background)
                self.assertIsNone(ImageChops.difference(expected, actual).getbbox(alpha_only=False))
                window_box = (32, 32, 64, 64)
                self.assertIsNotNone(ImageChops.difference(
                    actual.crop(window_box), background.crop(window_box),
                ).getbbox(alpha_only=False))

    def test_spawners_join_windows_and_frame_shuttle_walls(self):
        dmm = map_with_window("/obj/effect/spawner/structure/window/reinforced/shuttle")
        turfs, _, windows = previews.build_join_sets(dmm)
        self.assertEqual(previews.junction_at(2, 2, windows["shuttle_window"]), 1)
        self.assertEqual(previews.junction_at(3, 2, turfs["shuttle_wall"]), 8)
        self.assertNotIn((2, 2), turfs["wall"])

    def test_indestructible_spawner_inherits_shuttle_glass(self):
        self.assertEqual(
            previews.smooth_obj_entry("/obj/effect/spawner/structure/window/reinforced/shuttle/indestructible"),
            previews.smooth_obj_entry("/obj/structure/window/reinforced/shuttle/indestructible"),
        )

    def test_directional_windows_do_not_get_fulltile_glass(self):
        for path in (
            "/obj/effect/spawner/structure/window/hollow",
            "/obj/effect/spawner/structure/window/hollow/reinforced/directional",
            "/obj/structure/window/reinforced/spawner/directional/north",
            "/obj/effect/spawner/structure/windowless",
        ):
            with self.subTest(path=path):
                self.assertIsNone(previews.smooth_obj_entry(path))


if __name__ == "__main__":
    unittest.main()
