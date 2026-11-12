"""Enregistre le journal du brassard (port USB) dans un fichier, pour comparer_simulation.py.

  pip install pyserial
  python mesures/capturer.py COM3 essai-1.txt --duree 60        (Windows ; /dev/ttyACM0 sous Linux)

Pendant l'enregistrement : lancer une séance dans l'application (état « mesure »), puis suivre
le cycle d'effort (3 s repos, 4 s moyen, 3 s fort, 5 s moyen, 3 s repos), au moins deux fois.
Sans pyserial : copier le moniteur série de l'IDE Arduino dans un fichier, cela marche aussi.
"""
import argparse
import sys
import time


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("port")
    p.add_argument("fichier")
    p.add_argument("--duree", type=float, default=60, help="secondes (défaut 60)")
    p.add_argument("--debit", type=int, default=115200)
    a = p.parse_args()
    try:
        import serial
    except ImportError:
        sys.exit("pyserial manque : pip install pyserial")
    n = 0
    fin = time.time() + a.duree
    with serial.Serial(a.port, a.debit, timeout=1) as port, open(a.fichier, "w", encoding="utf-8") as f:
        print(f"Enregistrement {a.duree:.0f} s sur {a.port}…")
        while time.time() < fin:
            ligne = port.readline().decode("utf-8", errors="replace").strip()
            if not ligne:
                continue
            f.write(ligne + "\n")
            if ligne.startswith("M,"):
                n += 1
                if n % 250 == 0:
                    print(f"  {n} mesures")
            else:
                print("  brassard :", ligne)
    print(f"{n} mesures écrites dans {a.fichier}")
    if n == 0:
        print("Aucune mesure : la séance est-elle lancée (état « mesure ») et JOURNAL_SERIE vaut-il true ?")


if __name__ == "__main__":
    main()
