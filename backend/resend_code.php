<?php
require __DIR__ . '/bootstrap.php';
require __DIR__ . '/mail_sender.php';
require_post();

$email = trim($_POST['email'] ?? '');
if ($email === '') {
    json_out(["status" => "error", "message" => "Champs manquants"]);
}

$stmt = $conn->prepare("SELECT id, verified FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Réponse identique si le compte n'existe pas, pour ne pas révéler les adresses inscrites
if ($user && !(int) $user['verified']) {
    $code = nouveauCodeVerification($conn, (int) $user['id']);
    if (!envoyerCodeEmail($email, $code)) {
        json_out(["status" => "error", "message" => "L'e-mail n'a pas pu être envoyé"]);
    }
}
json_out(["status" => "success", "message" => "Si le compte existe et n'est pas vérifié, un nouveau code a été envoyé."]);
