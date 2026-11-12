<?php
require __DIR__ . '/bootstrap.php';

// Classement des 50 meilleurs athlètes vérifiés sur les 30 derniers jours.
//
// Règle de score (validée le 12 novembre 2026, voir architecture/MCD_MLD.md §5) : chaque séance mesurée rapporte
//   10 points (régularité : venir s'entraîner compte)
// + minutes de séance × intensité moyenne / 50 (travail musculaire réellement fourni).
// Exemple : 30 min à 40 % MVC → 10 + 30 × 40 / 50 = 34 points.
// Les séances faites avec le brassard SIMULÉ ne comptent pas : seul un vrai muscle marque des points.
$sql = "SELECT u.pseudo, u.sport,
               COALESCE(SUM(10 + ROUND(r.duree_s / 60 * r.intensite_moyenne_pct / 50)), 0) AS score,
               COUNT(r.session_id) AS nb_seances
        FROM users u
        LEFT JOIN sessions_entrainement s
               ON s.user_id = u.id AND s.donnees_simulees = 0
              AND s.debut >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        LEFT JOIN resultats_emg r ON r.session_id = s.id
        WHERE u.verified = 1
        GROUP BY u.id, u.pseudo, u.sport
        ORDER BY score DESC, nb_seances DESC, u.pseudo
        LIMIT 50";
$result = $conn->query($sql);

$athletes = [];
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $row['score'] = (int) $row['score'];
        $row['nb_seances'] = (int) $row['nb_seances'];
        $athletes[] = $row;
    }
}

echo json_encode($athletes, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
