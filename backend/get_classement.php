<?php
require __DIR__ . '/bootstrap.php';

// Les 50 meilleurs athlètes vérifiés : pseudo, sport choisi à l'inscription (colonne `sport`)
// et score total calculé à partir de leurs performances enregistrées.
$sql = "SELECT u.pseudo, u.sport,
               COALESCE(SUM(p.score_force + p.score_endurance + p.score_vitesse
                            + p.score_technique + p.score_recuperation), 0) AS score
        FROM users u
        LEFT JOIN performances p ON p.user_id = u.id
        WHERE u.verified = 1
        GROUP BY u.id, u.pseudo, u.sport
        ORDER BY score DESC
        LIMIT 50";
$result = $conn->query($sql);

$athletes = [];
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $row['score'] = (int) $row['score'];
        $athletes[] = $row;
    }
}

echo json_encode($athletes);
