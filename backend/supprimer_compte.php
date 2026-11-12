<?php
// RGPD, droit à l'effacement (article 17) : supprime le compte et TOUTES ses données
// (profils, séances, résultats, calibrations, jetons, par ON DELETE CASCADE).
// Le mot de passe est redemandé pour éviter une suppression avec un téléphone prêté ou volé.
// Les brassards restent (matériel de l'école) mais ne sont plus liés à personne (ON DELETE SET NULL).
require __DIR__ . '/bootstrap.php';
require_post();
$user_id = require_user($conn);

$password = $_POST['password'] ?? '';
$stmt = $conn->prepare("SELECT password_hash FROM users WHERE id = ?");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();
if (!$user || !is_string($password) || !password_verify($password, $user['password_hash'])) {
    json_out(["status" => "error", "message" => "Mot de passe incorrect"], 403);
}

$stmt = $conn->prepare("DELETE FROM users WHERE id = ?");
$stmt->bind_param("i", $user_id);
if (!$stmt->execute() || $stmt->affected_rows !== 1) {
    json_out(["status" => "error", "message" => "Suppression impossible"], 500);
}
$stmt->close();
json_out(["status" => "success", "message" => "Compte et données supprimés"]);
