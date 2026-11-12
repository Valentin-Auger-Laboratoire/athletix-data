<?php
// Historique des séances de l'utilisateur connecté, avec leur résumé EMG et leur contexte.
// Paramètre facultatif `limite` (1 à 500, 100 par défaut) : utilisé par l'écran d'évolution.
require __DIR__ . '/bootstrap.php';
require_post();

require __DIR__ . '/brassard.php';
$user_id = require_user($conn);
$limite = entier_post('limite', 1, 500, 100);

$stmt = $conn->prepare(
    "SELECT s.id, s.discipline, s.debut, s.fin, s.donnees_simulees,
            s.distance_m, s.denivele_m, s.vitesse_moy_kmh, s.nb_pas, s.fc_moy, s.fc_max,
            s.temperature_c, s.humidite_pct, s.meteo_code, s.ressenti_fatigue, s.douleur,
            s.sommeil, s.commentaire, s.mode_adapte,
            r.duree_s, r.intensite_moyenne_pct, r.intensite_max_pct,
            r.temps_effort_intense_s, r.nb_alertes, r.ref_mvc_mv,
            r.temps_zone_repos_s, r.temps_zone_moderee_s, r.temps_zone_soutenue_s,
            r.nb_contractions, r.indice_fatigue_pct, r.courbe
     FROM sessions_entrainement s
     JOIN resultats_emg r ON r.session_id = s.id
     WHERE s.user_id = ?
     ORDER BY s.debut DESC, s.id DESC
     LIMIT ?"
);
$stmt->bind_param("ii", $user_id, $limite);
$stmt->execute();
$res = $stmt->get_result();

$entiers = ['id', 'duree_s', 'intensite_moyenne_pct', 'intensite_max_pct', 'temps_effort_intense_s', 'nb_alertes'];
$seances = [];
while ($row = $res->fetch_assoc()) {
    foreach ($entiers as $c) {
        $row[$c] = (int) $row[$c];
    }
    foreach (['ref_mvc_mv', 'distance_m', 'denivele_m', 'nb_pas', 'fc_moy', 'fc_max', 'humidite_pct', 'meteo_code',
              'ressenti_fatigue', 'douleur', 'temps_zone_repos_s', 'temps_zone_moderee_s', 'temps_zone_soutenue_s',
              'nb_contractions', 'indice_fatigue_pct'] as $c) {
        $row[$c] = $row[$c] === null ? null : (int) $row[$c];
    }
    foreach (['vitesse_moy_kmh', 'temperature_c'] as $c) {
        $row[$c] = $row[$c] === null ? null : (float) $row[$c];
    }
    $row['courbe'] = $row['courbe'] === null ? null : json_decode($row['courbe'], true);
    $row['donnees_simulees'] = (int) $row['donnees_simulees'] === 1;
    $row['mode_adapte'] = (int) $row['mode_adapte'] === 1;
    $seances[] = $row;
}
$stmt->close();

json_out(["status" => "success", "seances" => $seances]);
