import pytest

from ddr5_radar.contrato import Formato
from ddr5_radar.nucleo.normalizador import extrair_atributos

KABUM_SIMPLES = "Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5, CL36, DIMM, Preto, EXPO - KF556C36BBE-16"
KABUM_KIT = "Memória RAM Kingston Fury Beast Expo, 32GB (2X16GB), 6000MT/s, DDR5, DIMM, CL30, Branco - KF560C30BWEK2-32"
KABUM_MHZ = "Memória Gamer Kingston Fury Beast, 8GB, DDR5, 5600MHz, CL40 - Kf556c40bb-8"
KABUM_RGB = "Memória RAM Kingston Fury Beast RGB, 8GB, 5200MHz, DDR5, CL40, para Intel XMP, Preto - KF552C40BBA-8"
KABUM_NOTEBOOK = "Memória RAM para Notebook Corsair Vengeance, 8GB, 4800MHz, DDR5, CL40, Preto - CMSX8GX5M1A4800C40"
KABUM_CORSAIR_KIT = "Memória RAM Corsair Vengeance, 32GB (2x16GB), 6000MHz, DDR5, CL38, Intel XMP, Preto - CMK32GX5M2B6000C38"
ML_BAGUNCADO = "KIT MEMORIA RAM DDR5 32GB 6000 KINGSTON FURY BEAST RGB *ENVIO IMEDIATO*"


def test_extrai_capacidade_e_velocidade_do_titulo_simples():
    a = extrair_atributos(KABUM_SIMPLES)
    assert a.capacidade_gb == 16
    assert a.velocidade_mts == 5600
    assert a.latencia_cl == 36
    assert a.marca == "kingston"
    assert a.linha == "fury-beast"


def test_kit_usa_capacidade_total_e_conta_modulos():
    a = extrair_atributos(KABUM_KIT)
    assert a.capacidade_gb == 32
    assert a.modulos == 2
    assert a.velocidade_mts == 6000


def test_mhz_e_mts_sao_a_mesma_grandeza():
    assert extrair_atributos(KABUM_MHZ).velocidade_mts == 5600


def test_rgb_e_detectado():
    assert extrair_atributos(KABUM_RGB).rgb is True
    assert extrair_atributos(KABUM_SIMPLES).rgb is False


def test_notebook_e_sodimm():
    assert extrair_atributos(KABUM_NOTEBOOK).formato is Formato.SODIMM
    assert extrair_atributos(KABUM_SIMPLES).formato is Formato.DIMM


def test_part_number_normalizado_em_maiuscula():
    assert extrair_atributos(KABUM_MHZ).part_number == "KF556C40BB-8"
    assert extrair_atributos(KABUM_SIMPLES).part_number == "KF556C36BBE-16"


def test_titulo_de_marketplace_sem_part_number():
    a = extrair_atributos(ML_BAGUNCADO)
    assert a.part_number is None
    assert a.marca == "kingston"
    assert a.linha == "fury-beast"
    assert a.capacidade_gb == 32
    assert a.velocidade_mts == 6000
    assert a.rgb is True


def test_campo_ausente_vira_none_e_nao_chute():
    a = extrair_atributos("Memória DDR5 sem mais nada")
    assert a.capacidade_gb is None
    assert a.velocidade_mts is None
    assert a.marca is None
    assert a.latencia_cl is None


def test_marca_da_corsair():
    a = extrair_atributos(KABUM_CORSAIR_KIT)
    assert a.marca == "corsair"
    assert a.linha == "vengeance"
    assert a.modulos == 2
