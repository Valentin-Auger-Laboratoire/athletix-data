<?php
// État du dernier brassard utilisé par l'utilisateur connecté (lecture seule).
// Les valeurs sont enregistrées par l'application à chaque calibration ou séance
// (table brassards, voir architecture/MCD_MLD.md). Le brassard ne parle jamais au serveur.
require __DIR__ . '/bootstrap.php';
require_post();

$user_id = require_user($conn);

// « Relié » = synchronisé par l'application depuis moins de 2 minutes
$stmt = $conn->prepare(
    "SELECT numero_serie, firmware, batterie_niveau, derniere_synchro,
            (derniere_synchro > DATE_SUB(NOW(), INTERVAL 2 MINUTE)) AS recent
     FROM brassards WHERE user_id = ?
     ORDER BY derniere_synchro DESC LIMIT 1"
);
$stmt->bind_param("i", $user_id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();

json_out([
    "status"       => "success",
    "connected"    => $row ? (int) $row['recent'] === 1 : false,
    "battery"      => ($row && $row['batterie_niveau'] !== null) ? (int) $row['batterie_niveau'] : null,
    "last_sync"    => $row['derniere_synchro'] ?? null,
    "numero_serie" => $row['numero_serie'] ?? null,
    "firmware"     => $row['firmware'] ?? null,
]);
