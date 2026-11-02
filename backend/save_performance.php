<?php
require __DIR__ . '/bootstrap.php';
require_post();

$user_id = require_user($conn);

$scores = [];
foreach (['force', 'endurance', 'vitesse', 'technique', 'recuperation'] as $champ) {
    $scores[$champ] = max(0, min(100, intval($_POST[$champ] ?? 0)));
}

// 1. On crée d'abord une session d'entraînement
$stmt = $conn->prepare("INSERT INTO sessions_entrainement (user_id) VALUES (?)");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$session_id = $stmt->insert_id;
$stmt->close();

// 2. On insère les scores dans la table performances
$stmt = $conn->prepare("INSERT INTO performances
    (session_id, user_id, score_force, score_endurance, score_vitesse, score_technique, score_recuperation)
    VALUES (?, ?, ?, ?, ?, ?, ?)");
$stmt->bind_param("iiiiiii", $session_id, $user_id, $scores['force'], $scores['endurance'],
    $scores['vitesse'], $scores['technique'], $scores['recuperation']);

if ($stmt->execute()) {
    json_out(["status" => "success", "message" => "Performance enregistrée !"]);
}
json_out(["status" => "error", "message" => "Erreur lors de l'enregistrement"]);
