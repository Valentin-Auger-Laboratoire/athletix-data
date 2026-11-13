<?php
// RGPD, droit d'accès et à la portabilité (articles 15 et 20) : toutes les données du compte
// connecté, dans un seul fichier JSON. Le mot de passe (haché), les jetons et le code
// de vérification ne sont pas exportés.
require __DIR__ . '/bootstrap.php';
require_post();
require __DIR__ . '/brassard.php';
$user_id = require_user($conn);

function lignes(mysqli $conn, string $sql, int $user_id): array
{
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $res = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $res;
}

$compte = lignes($conn, "SELECT pseudo, email, sport, created_at FROM users WHERE id = ?", $user_id);
$seances = lignes($conn,
    "SELECT s.*, r.duree_s, r.nb_echantillons, r.intensite_moyenne_pct, r.intensite_max_pct,
            r.temps_effort_intense_s, r.nb_alertes, r.temps_zone_repos_s, r.temps_zone_moderee_s,
            r.temps_zone_soutenue_s, r.nb_contractions, r.nb_series, r.indice_fatigue_pct, r.courbe, r.ref_mvc_mv,
            r.mdf_debut_hz, r.mdf_fin_hz, r.baisse_mdf_pct, r.courbe_mdf
     FROM sessions_entrainement s LEFT JOIN resultats_emg r ON r.session_id = s.id
     WHERE s.user_id = ? ORDER BY s.debut", $user_id);
foreach ($seances as &$s) {
    unset($s['user_id']);
    foreach (['courbe', 'trace_gps', 'courbe_mdf'] as $c) {
        $s[$c] = $s[$c] === null ? null : json_decode($s[$c], true);
    }
}
unset($s);

json_out([
    "status" => "success",
    "exporte_le" => date('c'),
    "compte" => $compte[0] ?? null,
    "profils" => lignes($conn, "SELECT * FROM profil_ia WHERE user_id = ? ORDER BY created_at", $user_id),
    "calibrations" => lignes($conn,
        "SELECT c.ref_mvc_mv, c.created_at, b.numero_serie FROM calibrations c
         JOIN brassards b ON b.id = c.brassard_id WHERE c.user_id = ? ORDER BY c.created_at", $user_id),
    "brassards" => lignes($conn, "SELECT numero_serie, firmware, batterie_niveau, derniere_synchro FROM brassards WHERE user_id = ?", $user_id),
    "seances" => $seances,
]);
