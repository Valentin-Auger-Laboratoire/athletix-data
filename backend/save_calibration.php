<?php
// Enregistre une calibration : la référence 100 % (contraction maximale, MVC) mesurée par le brassard.
// Une ligne par calibration pour garder l'historique (voir architecture/MCD_MLD.md, défaut D4).
require __DIR__ . '/bootstrap.php';
require __DIR__ . '/brassard.php';
require_post();

$user_id = require_user($conn);

$serie   = trim($_POST['numero_serie'] ?? '');
$ref_mvc = entier_post('ref_mvc_mv', 100, 3300);   // plage du convertisseur 0–3,3 V (règle R3)
if ($serie === '') {
    json_out(["status" => "error", "message" => "Champ manquant : numero_serie"], 400);
}
$firmware = isset($_POST['firmware']) ? trim($_POST['firmware']) : null;

$brassard_id = brassard_pour_utilisateur($conn, $user_id, $serie, $firmware);

$stmt = $conn->prepare("INSERT INTO calibrations (brassard_id, user_id, ref_mvc_mv) VALUES (?, ?, ?)");
$stmt->bind_param("iii", $brassard_id, $user_id, $ref_mvc);
if (!$stmt->execute()) {
    json_out(["status" => "error", "message" => "Erreur lors de l'enregistrement de la calibration"], 500);
}
json_out(["status" => "success", "message" => "Calibration enregistrée", "ref_mvc_mv" => $ref_mvc]);
