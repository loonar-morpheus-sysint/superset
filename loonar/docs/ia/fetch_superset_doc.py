import sys
from typing import Optional

import requests
from bs4 import BeautifulSoup


def check_python_dep(module: str, pip_name: Optional[str] = None) -> None:
    """
    Verifica se o módulo está instalado, sugere instalação se não estiver.
    """
    try:
        __import__(module)
    except ImportError:
        pkg = pip_name or module
        print(f"Dependência Python '{module}' não encontrada.")
        print(f"Por favor, instale manualmente com: pip install {pkg}")
        sys.exit(10)


check_python_dep("requests")
check_python_dep("bs4", "beautifulsoup4")


if len(sys.argv) != 3:
    print("Uso: fetch_superset_doc.py <url> <arquivo_saida>")
    sys.exit(1)

url: str = sys.argv[1]
out_file: str = sys.argv[2]

try:
    resp = requests.get(url, timeout=20)
    resp.raise_for_status()
except Exception as e:
    print(f"Erro ao baixar {url}: {e}")
    sys.exit(2)

soup: BeautifulSoup = BeautifulSoup(resp.text, "html.parser")
main = soup.find("main") or soup.body
if not main:
    print("Conteúdo principal não encontrado.")
    sys.exit(3)

# Extrai texto limpo, separando por linhas
text: str = main.get_text(separator="\n", strip=True)

with open(out_file, "w") as f:
    f.write(text)

print(f"Arquivo atualizado: {out_file}")

# Dica para mypy: instale stubs se necessário
# python3 -m pip install types-requests
