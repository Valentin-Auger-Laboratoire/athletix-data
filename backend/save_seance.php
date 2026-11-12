<?php
// Enregistre une séance terminée et son résumé EMG (voir architecture/INTEGRATION.md).
// Appelé par l'application à la fin d'une séance, jamais par le brassard lui-même.
require __DIR__ . '/bootstrap.php';
require __DIR__ . '/brassard.php';
require_post();

$user_id = require_user($conn);

$discipline = trim($_POST['discipline'] ?? '');
if ($discipline === '' || mb_strlen($discipline) > 50) {
    json_out(["status" => "error", "message" => "Champ invalide : discipline (1 à 50 caractères)"], 400);
}

$duree      = entier_post('duree_s', 1, 21600);               // 6 h maximum
$nb_ech     = entier_post('nb_echantillons', 0, 2000000);
$moyenne    = entier_post('intensite_moyenne_pct', 0, 255);   // format du paquet GATT
$max        = entier_post('intensite_max_pct', 0, 255);
$intense    = entier_post('temps_effort_intense_s', 0, 21600);
$nb_alertes = entier_post('nb_alertes', 0, 65535);
$simule     = ($_POST['simule'] ?? '0') === '1' ? 1 : 0;

if ($moyenne > $max) {
    json_out(["status" => "error", "message" => "Incohérent : l'intensité moyenne dépasse l'intensité maximale"], 400);
}
if ($intense > $duree) {
    json_out(["status" => "error", "message" => "Incohérent : le temps d'effort intense dépasse la durée de la séance"], 400);
}

$ref_mvc = null;
if (($_POST['ref_mvc_mv'] ?? '') !== '') {
    $ref_mvc = entier_post('ref_mvc_mv', 100, 3300);
}

// mysqli ne lance pas d'exception ici (MYSQLI_REPORT_OFF dans bootstrap.php) :
// chaque execute() est vérifié et une erreur annule toute la transaction.
$conn->begin_transaction();
try {
    $brassard_id = null;
    $serie = trim($_POST['numero_serie'] ?? '');
    if ($serie !== '') {
        $firmware = isset($_POST['firmware']) ? trim($_POST['firmware']) : null;
        $brassard_id = brassard_pour_utilisateur($conn, $user_id, $serie, $firmware);
    }

    // Début et fin fixés par le serveur : l'horloge du téléphone peut être fausse (règle R6)
    $stmt = $conn->prepare(
        "INSERT INTO sessions_entrainement (user_id, brassard_id, discipline, debut, fin, donnees_simulees)
         VALUES (?, ?, ?, DATE_SUB(NOW(), INTERVAL ? SECOND), NOW(), ?)"
    );
    $stmt->bind_param("iisii", $user_id, $brassard_id, $discipline, $duree, $simule);
    if (!$stmt->execute()) {
        throw new RuntimeException($stmt->error);
    }
    $session_id = (int) $stmt->insert_id;
    $stmt->close();

    $stmt = $conn->prepare(
        "INSERT INTO resultats_emg (session_id, duree_s, nb_echantillons, intensite_moyenne_pct,
             intensite_max_pct, temps_effort_intense_s, nb_alertes, ref_mvc_mv)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $stmt->bind_param("iiiiiiii", $session_id, $duree, $nb_ech, $moyenne, $max, $intense, $nb_alertes, $ref_mvc);
    if (!$stmt->execute()) {
        throw new RuntimeException($stmt->error);
    }
    $stmt->close();

    $conn->commit();
} catch (Throwable $e) {
    $conn->rollback();
    json_out(["status" => "error", "message" => "Erreur lors de l'enregistrement de la séance"], 500);
}

json_out(["status" => "success", "message" => "Séance enregistrée !", "session_id" => $session_id]);
