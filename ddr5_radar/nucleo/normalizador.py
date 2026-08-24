"""Titulo livre de loja -> atributos de memoria.

Regra de ouro: campo que nao foi encontrado vira None. Nunca chute.
Um chute errado aqui vira alerta falso la na frente.
"""
import re
import unicodedata
from dataclasses import dataclass

from ddr5_radar.contrato import Formato

MARCAS = {
    "kingston": ["kingston"],
    "corsair": ["corsair"],
    "adata": ["adata", "xpg"],
    "crucial": ["crucial", "micron"],
    "gskill": ["g.skill", "gskill", "g skill"],
    "teamgroup": ["teamgroup", "team group", "t-force", "tforce"],
    "patriot": ["patriot"],
    "netac": ["netac"],
    "lexar": ["lexar"],
    "samsung": ["samsung"],
    "sk-hynix": ["sk hynix", "hynix"],
    "husky": ["husky"],
    "rise-mode": ["rise mode", "rise-mode"],
    "pichau": ["pichau", "aegis"],
    "keepdata": ["keepdata"],
    "asgard": ["asgard"],
    "acer": ["acer", "predator"],
    "warrior": ["warrior", "multilaser"],
}

LINHAS = {
    "fury-beast": ["fury beast", "furybeast"],
    "fury-renegade": ["fury renegade", "renegade"],
    "vengeance": ["vengeance"],
    "dominator": ["dominator"],
    "ripjaws": ["ripjaws"],
    "trident-z": ["trident z", "trident-z", "tridentz"],
    "viper": ["viper"],
    "lancer": ["lancer"],
    "caster": ["caster"],
    "delta": ["delta"],
    "elite": ["elite"],
}


@dataclass(frozen=True, slots=True)
class AtributosMemoria:
    marca: str | None
    linha: str | None
    capacidade_gb: int | None
    modulos: int | None
    velocidade_mts: int | None
    latencia_cl: int | None
    formato: Formato
    rgb: bool
    part_number: str | None


def _sem_acento(texto: str) -> str:
    nfkd = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def _achar(mapa: dict[str, list[str]], texto: str) -> str | None:
    for canonico, apelidos in mapa.items():
        if any(apelido in texto for apelido in apelidos):
            return canonico
    return None


def _capacidade_e_modulos(texto: str) -> tuple[int | None, int | None]:
    # "32GB (2x16GB)" -> total 32, modulos 2. O total declarado manda.
    kit = re.search(r"(\d{1,3})\s*gb\s*\(\s*(\d)\s*x\s*(\d{1,3})\s*gb?\s*\)", texto)
    if kit:
        return int(kit.group(1)), int(kit.group(2))
    # "(2x16GB)" ou "2x16GB" sem total: multiplica
    solto = re.search(r"\(?\s*(\d)\s*x\s*(\d{1,3})\s*gb", texto)
    if solto:
        return int(solto.group(1)) * int(solto.group(2)), int(solto.group(1))
    simples = re.search(r"(\d{1,3})\s*gb", texto)
    if simples:
        # modulos fica None: "32GB" pode ser 1x32 ou kit nao declarado.
        return int(simples.group(1)), None
    return None, None


def _velocidade(texto: str) -> int | None:
    # MT/s e MHz sao a mesma grandeza nos catalogos das lojas.
    com_unidade = re.search(r"(\d{4,5})\s*(?:mt/s|mts|mhz)", texto)
    if com_unidade:
        return int(com_unidade.group(1))
    # marketplace escreve "DDR5 32GB 6000" sem unidade nenhuma
    solto = re.search(r"ddr5[^\d]{0,12}?(\d{4,5})(?!\s*gb)", texto)
    if solto:
        return int(solto.group(1))
    depois_do_gb = re.search(r"\d{1,3}\s*gb[^\d]{1,12}?(\d{4,5})(?!\s*gb)", texto)
    return int(depois_do_gb.group(1)) if depois_do_gb else None


def _part_number(titulo: str) -> str | None:
    """Codigo do fabricante, quase sempre no fim depois de um traco."""
    fim = re.search(r"[-–—]\s*([A-Za-z0-9][A-Za-z0-9./-]{5,})\s*$", titulo.strip())
    if not fim:
        return None
    candidato = fim.group(1)
    tem_letras = len(re.findall(r"[A-Za-z]", candidato)) >= 2
    tem_digitos = len(re.findall(r"\d", candidato)) >= 2
    return candidato.upper() if tem_letras and tem_digitos else None


def extrair_atributos(titulo: str) -> AtributosMemoria:
    texto = _sem_acento(titulo).lower()
    capacidade, modulos = _capacidade_e_modulos(texto)
    latencia = re.search(r"\bcl\s*(\d{2})\b", texto)
    e_notebook = any(t in texto for t in ("notebook", "sodimm", "so-dimm", "so dimm"))
    return AtributosMemoria(
        marca=_achar(MARCAS, texto),
        linha=_achar(LINHAS, texto),
        capacidade_gb=capacidade,
        modulos=modulos,
        velocidade_mts=_velocidade(texto),
        latencia_cl=int(latencia.group(1)) if latencia else None,
        formato=Formato.SODIMM if e_notebook else Formato.DIMM,
        rgb=bool(re.search(r"\brgb\b", texto)),
        part_number=_part_number(titulo),
    )
