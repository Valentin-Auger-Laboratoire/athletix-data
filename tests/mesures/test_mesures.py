"""Tests des outils de comparaison mesure / simulation (mesures/).
  python -m unittest discover -s tests/mesures -v
"""
import os
import sys
import tempfile
import unittest

import numpy as np

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "..", "mesures"))
import comparer_simulation as cs  # noqa: E402
import generer_exemple as ge  # noqa: E402
import modele  # noqa: E402


def journal(lignes):
    f = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8")
    f.write("\n".join(lignes) + "\n")
    f.close()
    return f.name


def verdict(v, debut):
    return [ok for c, _, _, ok in v if c.startswith(debut)][0]


class Modele(unittest.TestCase):
    def test_profil(self):
        self.assertEqual(list(modele.effort_vise([1.5, 5, 8.5, 12, 16.5, 18 + 8.5])), [0, 40, 95, 50, 0, 95])

    def test_transition_de_0_3_s(self):
        self.assertAlmostEqual(float(modele.effort_vise(3.15)), 20, places=6)  # à mi-chemin entre 0 et 40

    def test_rms_sur_un_palier(self):
        self.assertAlmostEqual(float(modele.intensite_reference(np.array([9.0]))[0]), 95, places=3)

    def test_rms_d_une_sinusoide(self):
        x = 1000 * np.sin(2 * np.pi * 50 * np.arange(0, 1, 1 / 500))
        self.assertAlmostEqual(float(modele.rms_glissante(x)[-1]), 1000 / np.sqrt(2), delta=1)

    def test_alerte_hysteresis(self):
        self.assertEqual(list(modele.alerte([70, 75, 72, 71, 69, 74, 76])), [0, 1, 1, 1, 0, 0, 1])


class Lecture(unittest.TestCase):
    def test_ignore_les_messages_et_gere_le_retour_a_zero(self):
        lignes = ["Brassard prêt", "ms,mv,rms,intensite,alerte"]
        ms = [2**32 - 1000 + 20 * i for i in range(100)]
        lignes += [f"M,{m % 2**32},10,10,1,0" for m in ms]
        m = cs.lire(journal(lignes))
        self.assertEqual(len(m["t"]), 100)
        self.assertAlmostEqual(float(m["t"][-1]), 99 * 0.02, places=6)

    def test_journal_vide_refuse(self):
        with self.assertRaises(ValueError):
            cs.lire(journal(["Brassard prêt", "M,1,2,3"]))


class Comparaison(unittest.TestCase):
    def test_seance_conforme_et_debut_retrouve(self):
        m = cs.lire(journal(ge.generer(nb_cycles=3, decalage_s=1.2, retard_s=0.15)))
        a = cs.analyser(m)
        self.assertEqual(a["nb_cycles"], 3)
        self.assertAlmostEqual(a["decalage"], 1.35, delta=0.25)
        self.assertTrue(all(ok for *_, ok in cs.verdicts(a)))

    def test_debut_tardif_retrouve(self):
        a = cs.analyser(cs.lire(journal(ge.generer(nb_cycles=2, decalage_s=7.0, retard_s=0.0))))
        self.assertAlmostEqual(a["decalage"], 7.0, delta=0.25)

    def test_effort_trop_faible_detecte(self):
        a = cs.analyser(cs.lire(journal(ge.generer(niveaux=(2, 36, 60, 47, 2)))))
        v = cs.verdicts(a)
        self.assertFalse(verdict(v, "Intensité, effort fort"))
        self.assertFalse(verdict(v, "Alerte pendant l'effort fort"))

    def test_alerte_sans_hysteresis_qui_clignote(self):
        a = cs.analyser(cs.lire(journal(ge.generer(niveaux=(2, 36, 76, 47, 2), hysteresis=False))))
        self.assertFalse(verdict(cs.verdicts(a), "Alerte qui clignote"))

    def test_figure_et_rapport(self):
        with tempfile.TemporaryDirectory() as d:
            chemin = journal(ge.generer(nb_cycles=2))
            code = cs.main([chemin, "--sortie", os.path.join(d, "essai")])
            self.assertEqual(code, 0)
            self.assertTrue(os.path.getsize(os.path.join(d, "essai-comparaison.png")) > 10000)
            with open(os.path.join(d, "essai-rapport.md"), encoding="utf-8") as f:
                self.assertIn("| Alerte pendant l'effort fort |", f.read())


if __name__ == "__main__":
    unittest.main()


import analyser_fatigue as af  # noqa: E402


class Fatigue(unittest.TestCase):
    def test_baisse_retrouvee_sur_l_exemple(self):
        m = af.lire(journal(ge.generer_fatigue(debut_hz=110, baisse_pct=20, bruit_hz=2)))
        a = af.analyser(m)
        self.assertAlmostEqual(a["baisse"], 20, delta=1.5)
        self.assertAlmostEqual(a["debut"], 110, delta=1.5)
        self.assertEqual(af.interpretation(a["baisse"]), "fatigue nette du muscle")

    def test_repos_ignore(self):
        m = af.lire(journal(ge.generer_fatigue()))
        self.assertTrue((m["mdf"] > 0).all())
        self.assertLess(len(m["mdf"]), m["nb_total"])

    def test_meme_calcul_que_l_application(self):
        # Même scénario que test/fatigue_test.dart (120 → 96 Hz en 2 min, ± 1,5 Hz) : baisse ≈ 20 %, pente ≈ −12 Hz/min
        lignes = []
        for i in range(241):
            t = i * 0.5
            lignes.append(f"F,{int(t * 1000)},{120 - 24 * t / 120 + ((t * 7) % 3 - 1.5):.3f},130")
        a = af.analyser(af.lire(journal(lignes)))
        self.assertAlmostEqual(a["baisse"], 20, delta=1.5)
        self.assertAlmostEqual(a["pente_hz_min"], -12, delta=1)

    def test_pas_assez_de_valeurs(self):
        with self.assertRaises(ValueError):
            af.analyser(af.lire(journal([f"F,{i * 512},110,125" for i in range(30)])))  # 15 s seulement
        with self.assertRaises(ValueError):
            af.lire(journal(["M,1,2,3,4,0", "bonjour"]))

    def test_reperes(self):
        self.assertEqual(af.interpretation(6), "début de fatigue")
        self.assertEqual(af.interpretation(0), "pas de fatigue mesurable")
        self.assertIn("hausse", af.interpretation(-8))

    def test_figure_et_rapport(self):
        dossier = tempfile.mkdtemp()
        src = journal(ge.generer_fatigue())
        self.assertEqual(af.main([src, "--sortie", os.path.join(dossier, "f")]), 0)
        self.assertTrue(os.path.getsize(os.path.join(dossier, "f-fatigue.png")) > 10000)
        with open(os.path.join(dossier, "f-fatigue.md"), encoding="utf-8") as f:
            self.assertIn("fatigue nette", f.read())
