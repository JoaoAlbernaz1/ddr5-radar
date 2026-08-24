"""Registro dos adaptadores. Acrescentar loja aqui e a unica costura necessaria."""
from ddr5_radar.coleta.adaptadores.amazon import AdaptadorAmazon
from ddr5_radar.coleta.adaptadores.kabum import AdaptadorKabum
from ddr5_radar.coleta.adaptadores.mercadolivre import AdaptadorMercadoLivre

ADAPTADORES = {
    "kabum": AdaptadorKabum(),
    "amazon": AdaptadorAmazon(),
    "mercadolivre": AdaptadorMercadoLivre(),
}
