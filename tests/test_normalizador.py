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


from ddr5_radar.nucleo.normalizador import chave_canonica, eh_ddr5, eh_memoria

DDR4 = "Memória RAM Kingston Fury Beast, 16GB, 3200MHz, DDR4, CL16 - KF432C16BB1-16"
PC_GAMER = "PC Gamer Plataforma AMD Ryzen 7000 DDR5 AM5 (FULL CUSTOM)"
PLACA_MAE = "Placa-mãe ASUS TUF Gaming B650M-E WiFi DDR5, Socket AM5, mATX"


def test_pc_montado_nao_e_memoria():
    assert eh_memoria(PC_GAMER) is False


def test_placa_mae_nao_e_memoria():
    assert eh_memoria(PLACA_MAE) is False


def test_pente_de_memoria_e_memoria():
    assert eh_memoria(KABUM_SIMPLES) is True
    assert eh_memoria(ML_BAGUNCADO) is True


def test_ddr4_nao_passa():
    a = extrair_atributos(DDR4)
    assert eh_ddr5(DDR4, a) is False


def test_ddr5_declarado_passa():
    a = extrair_atributos(KABUM_SIMPLES)
    assert eh_ddr5(KABUM_SIMPLES, a) is True


def test_sem_rotulo_mas_rapido_demais_para_ddr4_passa():
    titulo = "Memoria 16GB 5600MHz Kingston Fury Beast"
    assert eh_ddr5(titulo, extrair_atributos(titulo)) is True


def test_chave_ignora_latencia_para_nao_perder_match():
    com_cl = extrair_atributos(
        "Memória RAM Kingston Fury Beast, 16GB, 5600MT/s, DDR5, CL36 - KF556C36BBE-16"
    )
    sem_cl = extrair_atributos("MEMORIA KINGSTON FURY BEAST 16GB DDR5 5600")
    assert chave_canonica(com_cl) == chave_canonica(sem_cl)


def test_notebook_e_desktop_nao_compartilham_chave():
    desktop = extrair_atributos("Memória Corsair Vengeance, 8GB, 4800MHz, DDR5")
    notebook = extrair_atributos("Memória para Notebook Corsair Vengeance, 8GB, 4800MHz, DDR5")
    assert chave_canonica(desktop) != chave_canonica(notebook)


def test_rgb_muda_a_chave():
    com = extrair_atributos("Memória Kingston Fury Beast RGB, 16GB, 5600MHz, DDR5")
    sem = extrair_atributos("Memória Kingston Fury Beast, 16GB, 5600MHz, DDR5")
    assert chave_canonica(com) != chave_canonica(sem)


def test_sem_linha_reconhecida_nao_gera_chave():
    a = extrair_atributos("Memoria DDR5 16GB 5600MHz marca desconhecida")
    assert chave_canonica(a) is None


def test_chave_e_estavel_e_legivel():
    a = extrair_atributos(KABUM_KIT)
    assert chave_canonica(a) == "kingston|fury-beast|32|2|6000|dimm|sem-rgb"


# --- titulos reais coletados em 2026-08-24 que o parser inicial errou ---
REAL_XPG = "Memória DDR5 XPG Armax RGB, 16GB, 5600MHz, Preto, AX5U5600C4616G-SAMRBK"
REAL_APACER = "Memória DDR5 Apacer Nox, 16GB, 6000MHz, Branco, AH5U16G60C622MWAA-1"
REAL_KEEPDATA = "Mem Desk Ddr5  8GB 5600mhz Keepdata Kd56n46/8g"
REAL_CORSAIR_PN = "Memória RAM Corsair Vengeance, 32GB (2x16GB), 6000MHz, DDR5, CL38 - CMK32GX5M2B6000C38"


def test_part_number_depois_de_virgula():
    assert extrair_atributos(REAL_XPG).part_number == "AX5U5600C4616G-SAMRBK"
    assert extrair_atributos(REAL_APACER).part_number == "AH5U16G60C622MWAA-1"


def test_part_number_depois_de_espaco_com_barra():
    assert extrair_atributos(REAL_KEEPDATA).part_number == "KD56N46/8G"


def test_part_number_sem_separador_especial():
    assert extrair_atributos(REAL_CORSAIR_PN).part_number == "CMK32GX5M2B6000C38"


def test_medida_no_fim_nao_e_confundida_com_part_number():
    assert extrair_atributos("Memória Kingston Fury Beast DDR5 16GB 5600MHz").part_number is None
    assert extrair_atributos("Memória DDR5 Corsair Vengeance 32GB").part_number is None
    assert extrair_atributos("Memória DDR5 Kingston Fury Beast, 16GB, CL36").part_number is None


def test_marcas_novas_reconhecidas():
    assert extrair_atributos(REAL_APACER).marca == "apacer"
    assert extrair_atributos(REAL_XPG).marca == "adata"
    assert extrair_atributos(REAL_KEEPDATA).marca == "keepdata"


def test_linhas_novas_reconhecidas():
    assert extrair_atributos(REAL_XPG).linha == "armax"
    assert extrair_atributos(REAL_APACER).linha == "nox"


def test_sufixo_de_cor_nao_e_confundido_com_watts():
    # "-W" de White estava batendo na regra de unidade "w$" e matando o
    # part number inteiro. Watts so aparece depois de numero (650W).
    branca = "Memória DDR5 Rise Mode Zeus Series, 16GB, 5600MHz, Branca, RM-D5-16G-5600ZE-W"
    preta = "Memória DDR5 Rise Mode Zeus Series, 16GB, 5600MHz, Preto, RM-D5-16G-5600ZE-B"
    assert extrair_atributos(branca).part_number == "RM-D5-16G-5600ZE-W"
    assert extrair_atributos(preta).part_number == "RM-D5-16G-5600ZE-B"


def test_marca_e_linha_do_rise_mode_e_hiksemi():
    zeus = extrair_atributos("Memória DDR5 Rise Mode Zeus Series, 16GB, 6000MHz, Preto")
    assert zeus.marca == "rise-mode"
    assert zeus.linha == "zeus"
    hik = extrair_atributos("Memória DDR5 Hiksemi Armor, 16GB, 4800MHz, Branco")
    assert hik.marca == "hiksemi"
    assert hik.linha == "armor"
