"""Registro dos adaptadores. Acrescentar loja aqui e a unica costura necessaria."""
from ddr5_radar.coleta.adaptadores.amazon import AdaptadorAmazon
from ddr5_radar.coleta.adaptadores.kabum import AdaptadorKabum

ADAPTADORES = {
    "kabum": AdaptadorKabum(),
    "amazon": AdaptadorAmazon(),
}
