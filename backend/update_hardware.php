<?php
// Mise à jour de l'état du brassard (à appeler par le brassard ou sa passerelle, en POST).
// L'appli Flutter, elle, lit l'état avec get_hardware.php et n'écrit jamais ici.
require __DIR__ . '/bootstrap.php';
require_post();

$user_id  = require_user($conn);
$connecte = ($_POST['connecte'] ?? '0') === '1' ? 1 : 0;
$batterie = isset($_POST['batterie']) ? max(0, min(100, intval($_POST['batterie']))) : null;

$stmt = $conn->prepare(
    "INSERT INTO hardware_status (user_id, connecte, batterie_niveau, derniere_synchro)
     VALUES (?, ?, ?, NOW())
     ON DUPLICATE KEY UPDATE connecte = VALUES(connecte), batterie_niveau = VALUES(batterie_niveau),
                             derniere_synchro = NOW()"
);
$stmt->bind_param("iii", $user_id, $connecte, $batterie);

if ($stmt->execute()) {
    json_out(["status" => "success"]);
}
json_out(["status" => "error", "message" => "Erreur lors de la mise à jour"]);
