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


if __name__ == "__main__":
    unittest.main()
