import unittest

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


if __name__ == "__main__":
    unittest.main()
