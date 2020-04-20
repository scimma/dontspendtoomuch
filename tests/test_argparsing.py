import unittest
import dontspendtoomuch


class TestArgumentParsing(unittest.TestCase):
    def test_no_date_provided(self):
        with self.assertRaises(SystemExit):
            dontspendtoomuch.parse_arguments([])

    def test_dates_and_n_days(self):
        with self.assertRaises(SystemExit):
            dontspendtoomuch.parse_arguments(
                ["--start", "2020-04-01",
                 "--end", "2020-05-01",
                 "--n-days", "1"],
            )

    def test_only_start(self):
        with self.assertRaises(SystemExit):
            dontspendtoomuch.parse_arguments(["--start", "2020-04-01"])

    def test_only_end(self):
        with self.assertRaises(SystemExit):
            dontspendtoomuch.parse_arguments(["--end", "2020-04-01"])
