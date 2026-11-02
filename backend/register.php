<?php
require __DIR__ . '/bootstrap.php';
require __DIR__ . '/mail_sender.php';
require_post();

$pseudo = trim($_POST['pseudo'] ?? '');
$email  = trim($_POST['email']  ?? '');
$pass   = $_POST['password'] ?? '';
$sport  = trim($_POST['sport']  ?? '');

if ($pseudo === '' || $email === '' || $pass === '') {
    json_out(["status" => "error", "message" => "Champs manquants"]);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_out(["status" => "error", "message" => "Email invalide"]);
}
if (strlen($pass) < 6) {
    json_out(["status" => "error", "message" => "Mot de passe trop court (min. 6 caractères)"]);
}

// ✅ Le mot de passe n'est jamais stocké en clair
$hash = password_hash($pass, PASSWORD_DEFAULT);

$stmt = $conn->prepare("INSERT INTO users (pseudo, email, password_hash, sport) VALUES (?, ?, ?, ?)");
$stmt->bind_param("ssss", $pseudo, $email, $hash, $sport);

if (!$stmt->execute()) {
    json_out(["status" => "error", "message" => "Email déjà utilisé ou erreur SQL"]);
}
$user_id = $stmt->insert_id;
$stmt->close();

$code = nouveauCodeVerification($conn, $user_id);

// ✅ Le code n'est jamais renvoyé dans la réponse, même si l'e-mail échoue
if (envoyerCodeEmail($email, $code)) {
    json_out(["status" => "success", "mail_sent" => true, "message" => "Athlète créé, mail envoyé !"]);
}
json_out([
    "status"    => "success",
    "mail_sent" => false,
    "message"   => "Athlète créé, mais l'e-mail n'a pas pu être envoyé. Utilise « Renvoyer le code ».",
]);
