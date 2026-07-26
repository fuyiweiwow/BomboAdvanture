import unittest
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image

from src.tools.test.face_factor_model import parse_prompt


class FaceFactorParserTests(unittest.TestCase):
    def test_parse_approved_prompt_to_normalized_factors(self):
        result = parse_prompt("细眉、小眼、精灵耳", seed=20260726)

        self.assertEqual(result.factors["brow"], {
            "style": "thin",
            "thickness": 1,
            "curve": 0,
        })
        self.assertEqual(result.factors["eye"]["size"], "small")
        self.assertEqual(result.factors["eye"]["scale_x"], 0.75)
        self.assertEqual(result.factors["ear"], {
            "type": "elf",
            "length": 4,
            "tip_raise": 3,
            "outer_spread": 2,
        })
        self.assertEqual(result.seed, 20260726)
        self.assertEqual(result.warnings, [])

    def test_aliases_are_equivalent(self):
        self.assertEqual(
            parse_prompt("细的眉毛,小眼睛,尖耳", seed=1).factors,
            parse_prompt("细眉、小眼、精灵耳", seed=1).factors,
        )

    def test_unknown_prompt_words_are_reported_without_changing_defaults(self):
        result = parse_prompt("细眉、未知装饰", seed=1)

        self.assertEqual(result.factors["brow"]["style"], "thin")
        self.assertEqual(result.warnings, ["未识别提示词: 未知装饰"])

    def test_crossed_eye_is_parsed_but_not_enabled_by_default(self):
        result = parse_prompt("斗鸡眼", seed=1)

        self.assertEqual(result.factors["eye"]["pupil_offset"], [0, 0])
        self.assertEqual(result.warnings, ["因子暂未启用: eye.pupil_offset"])


class FaceFactorRasterTests(unittest.TestCase):
    def test_small_eye_thin_brow_elf_ear_covers_the_feature_socket(self):
        from src.tools.test.face_factor_raster import rasterize_variant, validate_coverage

        base = Image.new("RGBA", (36, 34), (0, 0, 0, 0))
        factors = parse_prompt("细眉、小眼、精灵耳", seed=1).factors
        result = rasterize_variant(base, direction="D", factors=factors, seed=1)

        self.assertIsNotNone(result.layers["brow"].getbbox())
        self.assertIsNotNone(result.layers["eye"].getbbox())
        self.assertIsNotNone(result.layers["ear"].getbbox())
        self.assertEqual(validate_coverage(result), [])

    def test_same_seed_produces_identical_layer_bytes(self):
        from src.tools.test.face_factor_raster import rasterize_variant

        base = Image.new("RGBA", (36, 34), (0, 0, 0, 0))
        factors = parse_prompt("细眉、小眼、精灵耳", seed=99).factors
        left = rasterize_variant(base, direction="D", factors=factors, seed=99)
        right = rasterize_variant(base, direction="D", factors=factors, seed=99)

        for name in ("socket_cover", "brow", "eye", "ear"):
            self.assertEqual(
                list(left.layers[name].get_flattened_data()),
                list(right.layers[name].get_flattened_data()),
            )

    def test_profile_anchors_cover_real_extracted_eye_and_ear_sockets(self):
        from pathlib import Path

        from src.tools.test.face_factor_raster import rasterize_variant, validate_coverage

        root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\face_bases_v1")
        factors = parse_prompt("缁嗙湁銆佸皬鐪笺€佺簿鐏佃€", seed=1).factors
        for role, prefix in (("male", "face10101"), ("female", "Face10701")):
            for direction in ("L", "R"):
                path = root / role / "base" / f"{prefix}_stand_{direction}_0.png"
                base = Image.open(path).convert("RGBA")
                result = rasterize_variant(base, direction=direction, factors=factors, seed=1)
                self.assertEqual(validate_coverage(result), [], msg=str(path))
                self.assertEqual(result.coverage["socket_expected"], result.coverage["socket_covered"])


class FaceFactorGeneratorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
        cls.source_dir = cls.project_root / "assets" / "test" / "face_bases_v1"
        cls.python_output_dir = cls.project_root / "assets" / "test"

    def _hash_files(self, root: Path):
        return {
            path.relative_to(root).as_posix(): sha256(path.read_bytes()).hexdigest()
            for path in sorted(root.rglob("*.png"))
        }

    def test_generator_writes_28_frames_per_role_and_preserves_source(self):
        from src.tools.test.generate_factor_faces import generate_faces

        source_hashes = self._hash_files(self.source_dir)
        with TemporaryDirectory(prefix="face_factor_generator_", dir=self.python_output_dir) as temp_dir:
            output_dir = Path(temp_dir)
            manifest = generate_faces(
                prompt="\u7ec6\u7709\u3001\u5c0f\u773c\u3001\u7cbe\u7075\u8033",
                seed=20260726,
                source_dir=self.source_dir,
                output_dir=output_dir,
                faces=("male", "female"),
            )

            self.assertEqual(manifest["frame_count"], {"male": 28, "female": 28})
            self.assertEqual(len(list((output_dir / "male" / "composite").glob("*.png"))), 28)
            self.assertEqual(len(list((output_dir / "female" / "composite").glob("*.png"))), 28)
            self.assertTrue((output_dir / "manifest.json").is_file())
            self.assertTrue((output_dir / "prompts" / "factors.json").is_file())
            self.assertEqual(source_hashes, self._hash_files(self.source_dir))

    def test_composite_uses_base_socket_cover_eye_brow_ear_order(self):
        from src.tools.test.generate_factor_faces import generate_faces

        with TemporaryDirectory(prefix="face_factor_order_", dir=self.python_output_dir) as temp_dir:
            output_dir = Path(temp_dir)
            generate_faces(
                prompt="\u7ec6\u7709\u3001\u5c0f\u773c\u3001\u7cbe\u7075\u8033",
                seed=1,
                source_dir=self.source_dir,
                output_dir=output_dir,
                faces=("male",),
            )
            frame_name = "face10101_stand_D_0.png"
            base = Image.open(self.source_dir / "male" / "base" / frame_name).convert("RGBA")
            composite = Image.open(output_dir / "male" / "composite" / frame_name).convert("RGBA")
            cover = Image.open(output_dir / "male" / "socket_cover" / frame_name).convert("RGBA")
            eye = Image.open(output_dir / "male" / "eye" / frame_name).convert("RGBA")
            brow = Image.open(output_dir / "male" / "brow" / frame_name).convert("RGBA")
            ear = Image.open(output_dir / "male" / "ear" / frame_name).convert("RGBA")

            expected = base.copy()
            for layer in (cover, eye, brow, ear):
                expected.alpha_composite(layer)
            self.assertEqual(list(composite.get_flattened_data()), list(expected.get_flattened_data()))

    def test_same_seed_reproduces_layers_and_female_blush(self):
        from src.tools.test.generate_factor_faces import generate_faces

        with TemporaryDirectory(prefix="face_factor_repro_", dir=self.python_output_dir) as temp_dir:
            root = Path(temp_dir)
            first_dir = root / "first"
            second_dir = root / "second"
            generate_faces(
                prompt="\u7ec6\u7709\u3001\u5c0f\u773c\u3001\u7cbe\u7075\u8033",
                seed=99,
                source_dir=self.source_dir,
                output_dir=first_dir,
                faces=("female",),
            )
            generate_faces(
                prompt="\u7ec6\u7709\u3001\u5c0f\u773c\u3001\u7cbe\u7075\u8033",
                seed=99,
                source_dir=self.source_dir,
                output_dir=second_dir,
                faces=("female",),
            )
            first_files = self._hash_files(first_dir)
            second_files = self._hash_files(second_dir)
            self.assertEqual(first_files, second_files)

            base = Image.open(self.source_dir / "female" / "base" / "Face10701_stand_D_0.png").convert("RGBA")
            composite = Image.open(first_dir / "female" / "composite" / "Face10701_stand_D_0.png").convert("RGBA")
            blush_pixels = []
            for y in range(base.height):
                for x in range(base.width):
                    r, g, b, alpha = base.getpixel((x, y))
                    if alpha >= 128 and r > g + 20 and r > b + 20:
                        blush_pixels.append((x, y))
            self.assertTrue(blush_pixels)
            self.assertTrue(any(composite.getpixel(point) == base.getpixel(point) for point in blush_pixels))

    def test_different_seed_changes_component_pixels_but_not_prompt_categories(self):
        import json

        from src.tools.test.generate_factor_faces import generate_faces

        with TemporaryDirectory(prefix="face_factor_seed_", dir=self.python_output_dir) as temp_dir:
            root = Path(temp_dir)
            first_dir = root / "seed_11"
            second_dir = root / "seed_12"
            generate_faces(
                prompt="\u7ec6\u7709\u3001\u5c0f\u773c\u3001\u7cbe\u7075\u8033",
                seed=11,
                source_dir=self.source_dir,
                output_dir=first_dir,
                faces=("male",),
            )
            generate_faces(
                prompt="\u7ec6\u7709\u3001\u5c0f\u773c\u3001\u7cbe\u7075\u8033",
                seed=12,
                source_dir=self.source_dir,
                output_dir=second_dir,
                faces=("male",),
            )
            first_eye = (first_dir / "male" / "eye" / "face10101_stand_D_0.png").read_bytes()
            second_eye = (second_dir / "male" / "eye" / "face10101_stand_D_0.png").read_bytes()
            self.assertNotEqual(first_eye, second_eye)

            first_factors = json.loads((first_dir / "prompts" / "factors.json").read_text(encoding="utf-8"))
            second_factors = json.loads((second_dir / "prompts" / "factors.json").read_text(encoding="utf-8"))
            self.assertEqual(first_factors["factors"], second_factors["factors"])
            self.assertNotEqual(first_factors["resolved_factors"], second_factors["resolved_factors"])


if __name__ == "__main__":
    unittest.main()
