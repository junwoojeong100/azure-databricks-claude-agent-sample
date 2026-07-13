import unittest
from types import SimpleNamespace

from src.agent_sample import _normalized_token_counts


class AgentSampleUsageTests(unittest.TestCase):
    def test_corrects_repeated_stream_input_usage(self) -> None:
        usage = {
            "input_token_count": 48,
            "output_token_count": 4,
            "total_token_count": 28,
        }

        self.assertEqual(_normalized_token_counts(usage), (24, 4, 28))

    def test_preserves_consistent_object_usage(self) -> None:
        usage = SimpleNamespace(
            input_token_count=24,
            output_token_count=4,
            total_token_count=28,
        )

        self.assertEqual(_normalized_token_counts(usage), (24, 4, 28))

    def test_derives_missing_total_usage(self) -> None:
        usage = {
            "input_token_count": 24,
            "output_token_count": 4,
            "total_token_count": None,
        }

        self.assertEqual(_normalized_token_counts(usage), (24, 4, 28))


if __name__ == "__main__":
    unittest.main()
