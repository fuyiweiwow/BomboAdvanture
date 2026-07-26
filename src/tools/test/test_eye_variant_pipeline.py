import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class EyeVariantCatalogTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_two_common_eye_shapes_apply_to_both_front_bases(self):
        from src.tools.test.eye_variant_pipeline import generate_eye_variants

        with TemporaryDirectory(prefix="eye_variants_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_eye_variants(output)

            self.assertEqual(
                manifest["variants"],
                ["set_a_reference_open", "set_b_round_open"],
            )
            self.assertEqual(manifest["roles"], ["male", "female"])

            for variant in manifest["variants"]:
                for role in manifest["roles"]:
                    role_dir = output / variant / role
                    for filename in (
                        "base.png",
                        "eye_geometry.png",
                        "pupil.png",
                        "highlight.png",
                        "eye.png",
                        "brow.png",
                        "ear.png",
                        "composite.png",
                        "preview.png",
                    ):
                        self.assertTrue((role_dir / filename).is_file(), f"{variant}/{role}/{filename}")
                    with Image.open(role_dir / "composite.png") as image:
                        self.assertEqual(image.size, (36, 34))
                    with Image.open(role_dir / "preview.png") as image:
                        self.assertEqual(image.size, (144, 136))
                    with Image.open(role_dir / "highlight.png") as image:
                        left_highlights = sum(
                            image.getpixel((x, y))[3] > 0
                            for y in range(image.height)
                            for x in range(image.width // 2)
                        )
                        right_highlights = sum(
                            image.getpixel((x, y))[3] > 0
                            for y in range(image.height)
                            for x in range(image.width // 2, image.width)
                        )
                        self.assertGreater(left_highlights, 0)
                        self.assertGreater(right_highlights, 0)
                        left_positions = [
                            x
                            for y in range(image.height)
                            for x in range(image.width // 2)
                            if image.getpixel((x, y))[3] > 0
                        ]
                        right_positions = [
                            x
                            for y in range(image.height)
                            for x in range(image.width // 2, image.width)
                            if image.getpixel((x, y))[3] > 0
                        ]
                        self.assertLess(sum(left_positions) / len(left_positions), 11.5)
                        self.assertLess(sum(right_positions) / len(right_positions), 23.5)

                self.assertEqual(
                    (output / variant / "male" / "eye.png").read_bytes(),
                    (output / variant / "female" / "eye.png").read_bytes(),
                )

            self.assertNotEqual(
                (output / "set_a_reference_open" / "male" / "eye.png").read_bytes(),
                (output / "set_b_round_open" / "male" / "eye.png").read_bytes(),
            )

            with Image.open(output / "set_a_reference_open" / "female" / "composite.png") as image:
                blush_pixels = [
                    image.getpixel((x, y))
                    for y in range(20, 32)
                    for x in range(6, 15)
                    if image.getpixel((x, y))[0] > image.getpixel((x, y))[1] + 20
                ]
                self.assertTrue(blush_pixels)

    def test_full_catalog_contains_all_motion_frames_and_keeps_back_eyes_empty(self):
        from src.tools.test.eye_variant_pipeline import generate_full_eye_variants

        with TemporaryDirectory(prefix="eye_variants_full_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_full_eye_variants(output)

            self.assertEqual(manifest["frame_count"], {
                "set_a_reference_open": {"male": 28, "female": 28},
                "set_b_round_open": {"male": 28, "female": 28},
            })
            for variant in manifest["variants"]:
                for role in manifest["roles"]:
                    role_dir = output / variant / role
                    composites = sorted((role_dir / "composite").glob("*.png"))
                    eyes = sorted((role_dir / "eye").glob("*.png"))
                    self.assertEqual(len(composites), 28)
                    self.assertEqual(len(eyes), 28)
                    self.assertTrue((role_dir / "preview" / "catalog.png").is_file())
                    self.assertTrue((role_dir / "composite" / f"{('face10101' if role == 'male' else 'Face10701')}_stand_D_0.png").is_file())

                    with Image.open(role_dir / "eye" / f"{('face10101' if role == 'male' else 'Face10701')}_stand_U_0.png") as image:
                        self.assertIsNone(image.getbbox())
                    with Image.open(role_dir / "eye" / f"{('face10101' if role == 'male' else 'Face10701')}_walk_U_5.png") as image:
                        self.assertIsNone(image.getbbox())

                self.assertEqual(
                    (output / variant / "male" / "eye" / "face10101_stand_D_0.png").read_bytes(),
                    (output / variant / "female" / "eye" / "Face10701_stand_D_0.png").read_bytes(),
                )

            self.assertNotEqual(
                (output / "set_a_reference_open" / "male" / "eye" / "face10101_stand_D_0.png").read_bytes(),
                (output / "set_b_round_open" / "male" / "eye" / "face10101_stand_D_0.png").read_bytes(),
            )

    def test_exaggerated_catalog_is_one_style_for_both_roles(self):
        from src.tools.test.eye_variant_pipeline import (
            generate_exaggerated_eye_variants,
            generate_full_eye_variants,
        )

        with TemporaryDirectory(prefix="eye_variants_exaggerated_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_exaggerated_eye_variants(output)
            baseline_output = output / "baseline"
            generate_full_eye_variants(baseline_output)

            self.assertEqual(manifest["variants"], ["set_c_exaggerated"])
            self.assertEqual(manifest["roles"], ["male", "female"])
            self.assertEqual(
                manifest["frame_count"],
                {"set_c_exaggerated": {"male": 28, "female": 28}},
            )
            factors = manifest["variant_factors"]["set_c_exaggerated"]
            self.assertGreater(factors["eye_scale_x"], 1.1)
            self.assertGreater(factors["eye_scale_y"], 1.15)
            self.assertLess(factors["brow_curve"], -1)
            self.assertEqual(factors["brow_weight"], 1)

            for role, face_id in (("male", "face10101"), ("female", "Face10701")):
                role_dir = output / "set_c_exaggerated" / role
                front_name = f"{face_id}_stand_D_0.png"
                self.assertTrue((role_dir / "preview" / "catalog.png").is_file())
                self.assertEqual(len(list((role_dir / "composite").glob("*.png"))), 28)
                self.assertNotEqual(
                    (role_dir / "eye" / front_name).read_bytes(),
                    (baseline_output / "set_a_reference_open" / role / "eye" / front_name).read_bytes(),
                )
                self.assertNotEqual(
                    (role_dir / "brow" / front_name).read_bytes(),
                    (baseline_output / "set_a_reference_open" / role / "brow" / front_name).read_bytes(),
                )

                with Image.open(role_dir / "highlight" / front_name) as image:
                    highlights = [
                        (x, y)
                        for y in range(image.height)
                        for x in range(image.width)
                        if image.getpixel((x, y))[3] > 0
                    ]
                    self.assertEqual(
                        [(10, 25), (11, 25), (22, 25), (23, 25)],
                        highlights,
                    )

    def test_exaggerated_motion_frames_reuse_front_palette_and_anchors(self):
        import json

        from src.tools.test.eye_variant_pipeline import generate_exaggerated_eye_variants

        with TemporaryDirectory(prefix="eye_variants_fixed_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            generate_exaggerated_eye_variants(output)
            role_dir = output / "set_c_exaggerated" / "male"

            def points(path):
                with Image.open(path) as image:
                    image = image.convert("RGBA")
                    return {
                        (x, y)
                        for y in range(image.height)
                        for x in range(image.width)
                        if image.getpixel((x, y))[3] > 0
                    }

            def colors(path):
                with Image.open(path) as image:
                    return {
                        pixel
                        for pixel in image.convert("RGBA").get_flattened_data()
                        if pixel[3] > 0
                    }

            front_name = "face10101_stand_D_0.png"
            front_eye_colors = colors(role_dir / "eye" / front_name)
            with Image.open(role_dir / "eye" / front_name) as image:
                image = image.convert("RGBA")
                dark_lower_pixels = [
                    (x, y)
                    for y in range(30, image.height)
                    for x in range(image.width)
                    if image.getpixel((x, y))[3] > 0 and sum(image.getpixel((x, y))[:3]) < 300
                ]
            self.assertFalse(dark_lower_pixels)

            annotations = json.loads(
                (self.project_root / "assets" / "test" / "male_face_v2" / "annotations.json").read_text(
                    encoding="utf-8"
                )
            )

            def iris_center(frame, left):
                iris = [
                    tuple(point)
                    for point in annotations[frame]["feat"]["iris"]
                    if (point[0] < 18) == left
                ]
                return (
                    (min(x for x, _ in iris) + max(x for x, _ in iris)) / 2,
                    (min(y for _, y in iris) + max(y for _, y in iris)) / 2,
                )

            front_centers = {side: iris_center("stand_D_0", side == "L") for side in ("L", "R")}
            front_brow_points = points(role_dir / "brow" / front_name)
            for frame in ("walk_D_0", "walk_D_1", "walk_D_2", "walk_D_4", "walk_D_5"):
                filename = f"face10101_{frame}.png"
                motion_colors = colors(role_dir / "eye" / filename)
                self.assertLessEqual(motion_colors, front_eye_colors, frame)

                expected_brow = set()
                for side in ("L", "R"):
                    dx = round(iris_center(frame, side == "L")[0] - front_centers[side][0])
                    dy = round(iris_center(frame, side == "L")[1] - front_centers[side][1])
                    side_points = {
                        (x, y)
                        for x, y in front_brow_points
                        if (x < 18) == (side == "L")
                    }
                    expected_brow.update((x + dx, y + dy) for x, y in side_points)
                self.assertEqual(expected_brow, points(role_dir / "brow" / filename), frame)


if __name__ == "__main__":
    unittest.main()
