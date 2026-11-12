#!/usr/bin/env bash
# Scénario de test de l'API Athletix sur un vrai serveur et une vraie base MariaDB / MySQL.
#
# ⚠️ Le script VIDE toutes les tables de la base avant de commencer : à lancer uniquement
#    sur une base de TEST, jamais sur une base qui contient de vraies données.
#
# Utilisation (depuis la racine du dépôt) :
#   mysql -u root < database.sql
#   mysql -u root < migrations/001_brassard_emg.sql
#   mysql -u root < migrations/002_score_et_nettoyage.sql
#   cp backend/config.example.php backend/config.local.php     # puis l'adapter
#   php -S 127.0.0.1:8080 -t backend &                          # ou XAMPP
#   ATHLETIX_TEST=1 B=http://127.0.0.1:8080 bash tests/api/test_api.sh
#
# L'e-mail de vérification n'est pas envoyé en test : le code est lu directement en base.
if [ "${ATHLETIX_TEST:-}" != "1" ]; then
  echo "Refusé : ce script vide la base. Relance avec ATHLETIX_TEST=1 sur une base de test."; exit 1
fi
B=${B:-http://127.0.0.1:8080}
DB='athletix-pro'
ok=0; ko=0
post() { curl -s -X POST "$B/$1" "${@:2}"; }
check() { # nom, attendu (regex), réponse
  if echo "$3" | grep -qE "$2"; then ok=$((ok+1)); echo "OK   $1"; else ko=$((ko+1)); echo "FAIL $1 -> $3"; fi
}
mysql -uroot "$DB" -e "SET FOREIGN_KEY_CHECKS=0; DELETE FROM resultats_emg; DELETE FROM calibrations; DELETE FROM brassards; DELETE FROM sessions_entrainement; DELETE FROM profil_ia; DELETE FROM auth_tokens; DELETE FROM users; SET FOREIGN_KEY_CHECKS=1;"

check "GET refusé" '"status":"error"' "$(curl -s "$B/login.php")"
check "inscription : champs manquants" 'Champs manquants' "$(post register.php -d email=a@b.fr)"
check "inscription : email invalide" 'Email invalide' "$(post register.php -d pseudo=x -d email=pasunmail -d password=secret1)"
check "inscription : mdp court" 'trop court' "$(post register.php -d pseudo=x -d email=t@t.fr -d password=123)"
R=$(post register.php -d pseudo=Testeur -d email=test@exemple.fr -d password=secret123 -d sport=Running)
check "inscription" '"status":"success"' "$R"
check "inscription : doublon" 'déjà utilisé' "$(post register.php -d pseudo=Testeur -d email=test@exemple.fr -d password=secret123)"
check "mot de passe haché" '^\$2y\$' "$(mysql -uroot -N "$DB" -e "SELECT password_hash FROM users WHERE email='test@exemple.fr'")"
check "connexion avant vérification" '"status":"(error|unverified)"|vérif' "$(post login.php -d email=test@exemple.fr -d password=secret123)"
check "code faux" 'incorrect' "$(post verify_code.php -d email=test@exemple.fr -d code=000000)"
CODE=$(mysql -uroot -N "$DB" -e "SELECT verification_code FROM users WHERE email='test@exemple.fr'")
R=$(post verify_code.php -d email=test@exemple.fr -d code="$CODE")
check "vérification" '"status":"success"' "$R"
check "mauvais mot de passe" 'incorrect' "$(post login.php -d email=test@exemple.fr -d password=faux)"
R=$(post login.php -d email=test@exemple.fr -d password=secret123)
check "connexion" '"status":"success"' "$R"
T=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
check "jeton reçu" '^[a-f0-9]{64}$' "$T"
check "route protégée sans jeton" 'Session invalide' "$(post get_profil_ia.php)"
check "route protégée faux jeton" 'Session expirée' "$(post get_profil_ia.php -d token=$(printf 'a%.0s' {1..64}))"
check "profil absent" 'no_profil' "$(post get_profil_ia.php -d token=$T)"
check "profil enregistré" '"status":"success"' "$(post ia_profile_save.php -d token=$T -d objectif_principal=Endurance -d niveau_sportif=Débutant -d poids=70 -d taille=178 -d frequence=7 -d pathologies_blessures=Genou -d qualite_sommeil=Bonne -d niveau_stress=4 -d antecedents_cardio_perso=0 -d antecedents_cardio_famille=1)"
R=$(post get_profil_ia.php -d token=$T)
check "profil relu" '"frequence":"?7' "$R"
check "historique de profils" '"historique":\[' "$R"
check "calibration" '"status":"success"' "$(post save_calibration.php -d token=$T -d numero_serie=ATX-0001 -d firmware=1.0.0 -d ref_mvc_mv=1820 -d batterie=87)"
check "calibration hors plage" 'entre 100 et 3300' "$(post save_calibration.php -d token=$T -d numero_serie=ATX-0001 -d ref_mvc_mv=5000)"
check "calibration n° série invalide" 'série' "$(post save_calibration.php -d token=$T -d numero_serie='x;drop' -d ref_mvc_mv=1800)"
S="-d token=$T -d discipline=Running -d duree_s=600 -d nb_echantillons=30000 -d intensite_moyenne_pct=48 -d intensite_max_pct=97 -d temps_effort_intense_s=90 -d nb_alertes=2 -d numero_serie=ATX-0001 -d ref_mvc_mv=1820"
check "séance enregistrée" '"session_id":[0-9]+' "$(post save_seance.php $S)"
check "séance simulée" '"status":"success"' "$(post save_seance.php -d token=$T -d discipline=Yoga -d duree_s=300 -d nb_echantillons=15000 -d intensite_moyenne_pct=12 -d intensite_max_pct=30 -d temps_effort_intense_s=0 -d nb_alertes=0 -d simule=1)"
check "séance incohérente" 'Incohérent' "$(post save_seance.php -d token=$T -d discipline=Running -d duree_s=60 -d nb_echantillons=1 -d intensite_moyenne_pct=90 -d intensite_max_pct=50 -d temps_effort_intense_s=0 -d nb_alertes=0)"
check "séance champ manquant" 'Champ manquant' "$(post save_seance.php -d token=$T -d discipline=Running)"
check "brassard lié en base" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM brassards WHERE numero_serie='ATX-0001'")"
check "résultats EMG en base" '^2$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM resultats_emg")"
R=$(post get_seances.php -d token=$T)
check "historique des séances" '"status":"success","seances":\[' "$R"
check "historique : séance Running avec résumé" '"discipline":"Running".*"intensite_moyenne_pct":48' "$R"
check "historique : séance simulée signalée" '"discipline":"Yoga","debut":"[^"]+","fin":"[^"]+","donnees_simulees":true' "$R"
check "historique : sans jeton refusé" 'Session invalide' "$(post get_seances.php)"
R=$(post get_hardware.php -d token=$T)
check "état du brassard : batterie" '"battery":87' "$R"
check "état du brassard : relié" '"connected":true' "$R"
check "état du brassard : n° de série" '"numero_serie":"ATX-0001"' "$R"
check "batterie hors plage" 'entre 0 et 100' "$(post save_calibration.php -d token=$T -d numero_serie=ATX-0001 -d ref_mvc_mv=1800 -d batterie=150)"
R=$(curl -s -X POST "$B/get_classement.php")
check "classement" 'Testeur' "$R"
check "classement : score EMG (séance simulée exclue)" '"pseudo":"Testeur","sport":"Running","score":20,"nb_seances":1' "$R"
check "déconnexion" '"status":"success"' "$(post logout.php -d token=$T)"
check "jeton révoqué" 'Session expirée' "$(post get_profil_ia.php -d token=$T)"
check "renvoyer le code" '"status":"success"' "$(post resend_code.php -d email=inconnu@exemple.fr)"
echo "---- $ok OK, $ko FAIL"
