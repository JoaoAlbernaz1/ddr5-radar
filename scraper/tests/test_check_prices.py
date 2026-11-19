"""Offline regression tests for scraper configuration and price conversion."""
import contextlib
import io
import os
import unittest
from unittest.mock import patch

from scraper import check_prices


class ConfigurationTests(unittest.TestCase):
    def test_missing_all_secrets_exits_without_connecting(self):
        error = io.StringIO()
        with patch.dict(os.environ, {}, clear=True), \
             patch.object(check_prices, "create_client") as create_client, \
             contextlib.redirect_stderr(error):
            status = check_prices.main()

        self.assertEqual(status, 2)
        self.assertIn("SUPABASE_URL", error.getvalue())
        self.assertIn("SUPABASE_SERVICE_ROLE_KEY", error.getvalue())
        create_client.assert_not_called()

    def test_whitespace_credentials_are_rejected(self):
        with patch.dict(
            os.environ,
            {"SUPABASE_URL": "  ", "SUPABASE_SERVICE_ROLE_KEY": "    "},
            clear=True,
        ), patch.object(check_prices, "create_client") as create_client, \
             contextlib.redirect_stderr(io.StringIO()):
            status = check_prices.main()
        self.assertEqual(status, 2)
        create_client.assert_not_called()


class MoneyTests(unittest.TestCase):
    def test_brazilian_price_conversion(self):
        self.assertEqual(check_prices.reais_para_centavos("R$ 1.999,90"), 199990)
        self.assertEqual(check_prices.reais_para_centavos("49,99"), 4999)

    def test_decimal_rounding(self):
        self.assertEqual(check_prices.reais_para_centavos("1.005"), 101)


if __name__ == "__main__":
    unittest.main()
