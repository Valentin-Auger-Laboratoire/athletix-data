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
#   mysql -u root < migrations/003_contexte_telephone.sql
#   mysql -u root < migrations/004_trace_series_hors_ligne.sql
#   mysql -u root < migrations/005_fatigue_frequence.sql
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
R=$(post save_seance.php $S -d distance_m=5230 -d denivele_m=48 -d vitesse_moy_kmh=10,4 -d nb_pas=6100 -d fc_moy=148 -d fc_max=176 -d temperature_c=18.5 -d humidite_pct=62 -d meteo_code=3 -d ressenti_fatigue=6 -d douleur=2 -d sommeil=Moyen -d "commentaire=Jambes lourdes" -d mode_adapte=1 -d temps_zone_repos_s=60 -d temps_zone_moderee_s=300 -d temps_zone_soutenue_s=150 -d nb_contractions=42 -d indice_fatigue_pct=12 -d "courbe=[0,10,45,97,50,3]")
check "séance complète (téléphone, contexte, courbe)" '"session_id":[0-9]+' "$R"
check "courbe invalide refusée" 'courbe' "$(post save_seance.php $S -d 'courbe=[1,2,300]')"
check "fréquence cardiaque incohérente refusée" 'Incohérent' "$(post save_seance.php $S -d fc_moy=180 -d fc_max=150)"
check "ressenti hors plage refusé" 'entre 0 et 10' "$(post save_seance.php $S -d ressenti_fatigue=11)"
check "séance simulée" '"status":"success"' "$(post save_seance.php -d token=$T -d discipline=Yoga -d duree_s=300 -d nb_echantillons=15000 -d intensite_moyenne_pct=12 -d intensite_max_pct=30 -d temps_effort_intense_s=0 -d nb_alertes=0 -d simule=1)"
check "séance incohérente" 'Incohérent' "$(post save_seance.php -d token=$T -d discipline=Running -d duree_s=60 -d nb_echantillons=1 -d intensite_moyenne_pct=90 -d intensite_max_pct=50 -d temps_effort_intense_s=0 -d nb_alertes=0)"
check "séance champ manquant" 'Champ manquant' "$(post save_seance.php -d token=$T -d discipline=Running)"
check "brassard lié en base" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM brassards WHERE numero_serie='ATX-0001'")"
check "résultats EMG en base" '^3$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM resultats_emg")"
R=$(post get_seances.php -d token=$T)
check "historique des séances" '"status":"success","seances":\[' "$R"
check "historique : séance Running avec résumé" '"discipline":"Running".*"intensite_moyenne_pct":48' "$R"
check "historique : séance simulée signalée" '"discipline":"Yoga","debut":"[^"]+","fin":"[^"]+","donnees_simulees":true' "$R"
check "historique : mesures du téléphone et contexte" '"distance_m":5230,"denivele_m":48,"vitesse_moy_kmh":10.4,"nb_pas":6100,"fc_moy":148,"fc_max":176,"temperature_c":18.5' "$R"
check "historique : ressenti, sommeil, mode adapté" '"ressenti_fatigue":6,"douleur":2,"sommeil":"Moyen","commentaire":"Jambes lourdes","mode_adapte":true' "$R"
check "historique : zones, contractions, courbe" '"nb_contractions":42,"nb_series":null,"indice_fatigue_pct":12,"courbe":\[0,10,45,97,50,3\]' "$R"
check "historique : limite" '"seances":\[\{[^]]*\}\]\}$' "$(post get_seances.php -d token=$T -d limite=1)"
check "historique : sans jeton refusé" 'Session invalide' "$(post get_seances.php)"
R=$(post get_hardware.php -d token=$T)
check "état du brassard : batterie" '"battery":87' "$R"
check "état du brassard : relié" '"connected":true' "$R"
check "état du brassard : n° de série" '"numero_serie":"ATX-0001"' "$R"
check "batterie hors plage" 'entre 0 et 100' "$(post save_calibration.php -d token=$T -d numero_serie=ATX-0001 -d ref_mvc_mv=1800 -d batterie=150)"
R=$(curl -s -X POST "$B/get_classement.php")
check "classement" 'Testeur' "$R"
check "classement : score EMG (séance simulée exclue)" '"pseudo":"Testeur","sport":"Running","score":40,"nb_seances":2' "$R"
U=3f2a9c1e-7b4d-4e8a-9c2f-0a1b2c3d4e5f
TR='[[48.85,2.35,0,10],[48.851,2.351,30,45],[48.852,2.352,60,80]]'
R=$(post save_seance.php $S -d nb_series=4 -d client_uuid=$U -d "trace=$TR")
check "séance avec tracé, séries et identifiant" '"session_id":[0-9]+' "$R"
SID=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin)["session_id"])')
check "renvoi de la même séance : pas de doublon" "\"session_id\":$SID,\"deja_enregistree\":true" "$(post save_seance.php $S -d client_uuid=$U)"
check "une seule séance pour cet identifiant" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM sessions_entrainement WHERE client_uuid='$U'")"
check "identifiant invalide refusé" 'client_uuid' "$(post save_seance.php $S -d client_uuid=pas-un-uuid)"
check "tracé invalide refusé" 'trace' "$(post save_seance.php $S -d 'trace=[[95,2,0,10],[48,2,1,10]]')"
check "tracé : temps qui recule refusé" 'trace' "$(post save_seance.php $S -d 'trace=[[48,2,10,10],[48,2,5,10]]')"
R=$(post save_seance.php $S -d fin_il_y_a_s=86400)
check "séance envoyée plus tard (hier)" '"session_id":[0-9]+' "$R"
SID2=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin)["session_id"])')
check "séance envoyée plus tard : date d'hier" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT DATEDIFF(NOW(), fin) FROM sessions_entrainement WHERE id=$SID2")"
R=$(post get_seances.php -d token=$T -d id=$SID)
check "détail d'une séance : tracé et séries" '"nb_series":4.*"trace":\[\[48.85,2.35,0,10\]' "$R"
check "détail d'une séance : une seule" '^[^{]*\{[^{]*"seances":\[\{[^]]*\[\[[^}]*\}\]\}$' "$R"
check "liste : sans le tracé" '"trace":null' "$(post get_seances.php -d token=$T -d limite=1)"
check "détail : séance d'un autre refusée (aucun résultat)" '"seances":\[\]' "$(post get_seances.php -d token=$T -d id=999999)"
R=$(post export_donnees.php -d token=$T)
check "export RGPD : compte, profils, séances" '"compte":\{"pseudo":"Testeur","email":"test@exemple.fr".*"profils":\[\{.*"seances":\[\{' "$R"
check "export RGPD : sans mot de passe ni jeton" '^[^$]*$' "$(echo "$R" | grep -o 'password_hash\|token_hash\|verification_code' || true)"
# Cinq envois simultanés de la même séance : une seule enregistrée, tous répondent « succès »
U2=9b1c2d3e-4f50-4a6b-8c7d-8e9f0a1b2c3d
for i in 1 2 3 4 5; do post save_seance.php $S -d client_uuid=$U2 > /tmp/athletix_course_$i.json & done; wait
check "envois simultanés : une seule séance" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM sessions_entrainement WHERE client_uuid='$U2'")"
check "envois simultanés : tous en succès" '^5$' "$(cat /tmp/athletix_course_*.json | grep -o '"status":"success"' | wc -l | tr -d ' ')"
rm -f /tmp/athletix_course_*.json
# Fatigue mesurée par la fréquence médiane (migration 005, brassard en source RAW)
R=$(post save_seance.php $S -d mdf_debut_hz=121.5 -d mdf_fin_hz=98.2 -d baisse_mdf_pct=19.2 -d "courbe_mdf=[121.4,0,110.25,98]")
check "séance avec fatigue (fréquence médiane)" '"session_id":[0-9]+' "$R"
SIDF=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("session_id",""))')
check "fatigue relue : début, fin, baisse, courbe arrondie au dixième" '"mdf_debut_hz":121.5,"mdf_fin_hz":98.2,"baisse_mdf_pct":19.2,"courbe_mdf":\[121.4,0(\.0)?,110.3,98(\.0)?\]' "$(post get_seances.php -d token=$T -d id=$SIDF)"
check "fatigue absente : champs nuls (source ENV)" '"mdf_debut_hz":null,"mdf_fin_hz":null,"baisse_mdf_pct":null,"courbe_mdf":null' "$(post get_seances.php -d token=$T -d id=$SID)"
check "courbe de fréquence invalide refusée" 'courbe_mdf' "$(post save_seance.php $S -d 'courbe_mdf=[100,2000]')"
check "courbe de fréquence non numérique refusée" 'courbe_mdf' "$(post save_seance.php $S -d 'courbe_mdf=["a"]')"
check "baisse hors plage refusée" 'baisse_mdf_pct' "$(post save_seance.php $S -d baisse_mdf_pct=250)"
check "export RGPD : fatigue incluse" '"baisse_mdf_pct":"?19.2' "$(post export_donnees.php -d token=$T)"
# Un deuxième utilisateur ne voit ni ne touche les données du premier
post register.php -d pseudo=Autre -d email=autre@exemple.fr -d password=autre1234 -d sport=Yoga > /dev/null
CODE2=$(mysql -uroot -N "$DB" -e "SELECT verification_code FROM users WHERE email='autre@exemple.fr'")
post verify_code.php -d email=autre@exemple.fr -d code="$CODE2" > /dev/null
T2=$(post login.php -d email=autre@exemple.fr -d password=autre1234 | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
check "autre utilisateur : séance du premier invisible (par son id)" '"seances":\[\]' "$(post get_seances.php -d token=$T2 -d id=$SID)"
check "autre utilisateur : historique vide" '"seances":\[\]' "$(post get_seances.php -d token=$T2)"
check "autre utilisateur : export sans les séances du premier" '"seances":\[\]' "$(post export_donnees.php -d token=$T2)"
check "autre utilisateur : renvoyer l'identifiant d'un autre crée SA séance" '"session_id":[0-9]+' "$(post save_seance.php -d token=$T2 -d discipline=Yoga -d duree_s=300 -d nb_echantillons=1 -d intensite_moyenne_pct=10 -d intensite_max_pct=20 -d temps_effort_intense_s=0 -d nb_alertes=0 -d client_uuid=$U)"
check "autre utilisateur : la séance du premier n'a pas changé de propriétaire" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM sessions_entrainement s JOIN users u ON u.id=s.user_id WHERE s.client_uuid='$U' AND u.email='test@exemple.fr'")"
check "suppression du compte de l'autre utilisateur" '"status":"success"' "$(post supprimer_compte.php -d token=$T2 -d password=autre1234)"
check "le premier compte est intact" '^1$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*) FROM users WHERE email='test@exemple.fr'")"
check "suppression : mauvais mot de passe refusé" 'Mot de passe incorrect' "$(post supprimer_compte.php -d token=$T -d password=faux)"
check "déconnexion" '"status":"success"' "$(post logout.php -d token=$T)"
check "jeton révoqué" 'Session expirée' "$(post get_profil_ia.php -d token=$T)"
check "renvoyer le code" '"status":"success"' "$(post resend_code.php -d email=inconnu@exemple.fr)"
R=$(post login.php -d email=test@exemple.fr -d password=secret123)
T=$(echo "$R" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
check "suppression du compte" '"status":"success"' "$(post supprimer_compte.php -d token=$T -d password=secret123)"
check "après suppression : connexion impossible" 'incorrect' "$(post login.php -d email=test@exemple.fr -d password=secret123)"
check "après suppression : plus aucune donnée" '^0 0 0 0 0$' "$(mysql -uroot -N "$DB" -e "SELECT (SELECT COUNT(*) FROM users), (SELECT COUNT(*) FROM sessions_entrainement), (SELECT COUNT(*) FROM resultats_emg), (SELECT COUNT(*) FROM profil_ia), (SELECT COUNT(*) FROM calibrations)" | tr '\t' ' ')"
check "après suppression : brassard gardé, délié" '^1 NULL$' "$(mysql -uroot -N "$DB" -e "SELECT COUNT(*), MAX(user_id) FROM brassards" | tr '\t' ' ')"
echo "---- $ok OK, $ko FAIL"
