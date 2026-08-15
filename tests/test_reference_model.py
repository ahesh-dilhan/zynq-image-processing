import unittest

from sim.reference_model import demo_frame, mean_filter_cropped


class MeanFilterReferenceTests(unittest.TestCase):
    def test_single_window_uses_integer_truncation(self) -> None:
        self.assertEqual(mean_filter_cropped(list(range(9)), 3, 3), [4])

    def test_known_four_by_four_frame(self) -> None:
        frame = [
            0, 1, 2, 3,
            4, 5, 6, 7,
            8, 9, 10, 11,
            12, 13, 14, 15,
        ]
        self.assertEqual(mean_filter_cropped(frame, 4, 4), [5, 6, 9, 10])

    def test_output_size_matches_cropped_contract(self) -> None:
        width, height = 8, 6
        output = mean_filter_cropped(demo_frame(width, height), width, height)
        self.assertEqual(len(output), (width - 2) * (height - 2))

    def test_rejects_bad_dimensions_and_samples(self) -> None:
        with self.assertRaises(ValueError):
            mean_filter_cropped([0, 1, 2, 3], 2, 2)
        with self.assertRaises(ValueError):
            mean_filter_cropped([0] * 9, 4, 4)
        with self.assertRaises(ValueError):
            mean_filter_cropped([0] * 8 + [256], 3, 3)


if __name__ == "__main__":
    unittest.main()
