<?php
// Historique des séances de l'utilisateur connecté, avec leur résumé EMG (les 50 dernières).
require __DIR__ . '/bootstrap.php';
require_post();

$user_id = require_user($conn);

$stmt = $conn->prepare(
    "SELECT s.id, s.discipline, s.debut, s.fin, s.donnees_simulees,
            r.duree_s, r.intensite_moyenne_pct, r.intensite_max_pct,
            r.temps_effort_intense_s, r.nb_alertes, r.ref_mvc_mv
     FROM sessions_entrainement s
     JOIN resultats_emg r ON r.session_id = s.id
     WHERE s.user_id = ?
     ORDER BY s.debut DESC, s.id DESC
     LIMIT 50"
);
$stmt->bind_param("i", $user_id);
$stmt->execute();
$res = $stmt->get_result();

$entiers = ['id', 'duree_s', 'intensite_moyenne_pct', 'intensite_max_pct', 'temps_effort_intense_s', 'nb_alertes'];
$seances = [];
while ($row = $res->fetch_assoc()) {
    foreach ($entiers as $c) {
        $row[$c] = (int) $row[$c];
    }
    $row['ref_mvc_mv'] = $row['ref_mvc_mv'] === null ? null : (int) $row['ref_mvc_mv'];
    $row['donnees_simulees'] = (int) $row['donnees_simulees'] === 1;
    $seances[] = $row;
}
$stmt->close();

json_out(["status" => "success", "seances" => $seances]);
