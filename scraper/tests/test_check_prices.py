"""Offline regression tests for scraper configuration and price conversion."""
import contextlib
import json
import io
import os
import unittest
from unittest.mock import patch

import httpx

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




def _client_with_products(products):
    payload = {
        "props": {
            "pageProps": {
                "data": {
                    "catalogServer": {"data": products}
                }
            }
        }
    }
    html = (
        '<script id="__NEXT_DATA__" type="application/json">'
        + json.dumps(payload) + "</script>"
    )
    transport = httpx.MockTransport(
        lambda request: httpx.Response(200, text=html, request=request)
    )
    return httpx.Client(transport=transport)


class StoreMatchingTests(unittest.TestCase):
    def test_chooses_only_correct_model_not_first_search_hit(self):
        products = [
            {
                "name": "Ryzen 7 5800X3D",
                "available": True,
                "priceWithDiscount": 1299,
            },
            {
                "name": "Processador AMD Ryzen 7 7800X3D",
                "available": True,
                "priceWithDiscount": 1799.9,
            },
        ]
        with _client_with_products(products) as client:
            found = check_prices.buscar_kabum(client, "Ryzen 7 7800X3D")
        self.assertEqual(found["preco"], 1799.90)
        self.assertIn("7800X3D", found["nome"])

    def test_refuses_ambiguous_search(self):
        products = [
            {"name": "Processador Ryzen 7 7800X3D", "available": True, "price": 1800},
            {"name": "Processador Ryzen 7 9800X3D", "available": True, "price": 2300},
        ]
        with _client_with_products(products) as client:
            found = check_prices.buscar_kabum(client, "Ryzen 7")
        self.assertIsNone(found)

    def test_refuses_out_of_stock_and_unrelated_models(self):
        products = [
            {"name": "DDR4 32GB 3200MHz", "available": True, "price": 350},
            {"name": "DDR5 32GB 6000MHz", "available": False, "price": 600},
        ]
        with _client_with_products(products) as client:
            found = check_prices.buscar_kabum(client, "DDR5 32GB 6000MHz")
        self.assertIsNone(found)

    def test_skips_unsupported_store_before_network_request(self):
        part = {"name": "Ryzen 7 7800X3D", "store": "Pichau"}
        with patch.object(check_prices, "buscar_kabum") as search:
            result = check_prices.processar_peca(None, None, part)
        self.assertEqual(result, "loja_nao_suportada")
        search.assert_not_called()

    def test_model_token_match_requires_numbers_and_all_tokens(self):
        self.assertTrue(check_prices.corresponde_produto(
            "RTX 4070 Super",
            "Placa de Video NVIDIA RTX 4070 SUPER 12GB"
        ))
        self.assertFalse(check_prices.corresponde_produto(
            "RTX 4070 Ti",
            "Placa de Video NVIDIA RTX 4070 SUPER 12GB"
        ))
        self.assertFalse(check_prices.corresponde_produto(
            "Memoria gamer", "Memoria gamer varios modelos"
        ))


if __name__ == "__main__":
    unittest.main()
