<?php
// Lecture seule de l'état du brassard de l'utilisateur connecté.
require __DIR__ . '/bootstrap.php';
require_post();

$user_id = require_user($conn);

// Le brassard est considéré comme déconnecté s'il ne s'est pas synchronisé depuis 2 minutes
$stmt = $conn->prepare(
    "SELECT connecte, batterie_niveau, derniere_synchro,
            (derniere_synchro > DATE_SUB(NOW(), INTERVAL 2 MINUTE)) AS recent
     FROM hardware_status WHERE user_id = ?"
);
$stmt->bind_param("i", $user_id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();

json_out([
    "status"      => "success",
    "connected"   => $row ? ((int) $row['connecte'] === 1 && (int) $row['recent'] === 1) : false,
    "battery"     => ($row && $row['batterie_niveau'] !== null) ? (int) $row['batterie_niveau'] : null,
    "last_sync"   => $row['derniere_synchro'] ?? null,
]);
