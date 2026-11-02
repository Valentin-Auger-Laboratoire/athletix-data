<?php
require __DIR__ . '/bootstrap.php';
require_post();

$email    = trim($_POST['email'] ?? '');
$password = $_POST['password'] ?? '';

if ($email === '' || $password === '') {
    json_out(["status" => "error", "message" => "Champs manquants"]);
}

$stmt = $conn->prepare("SELECT id, pseudo, password_hash, verified FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Même message si l'email ou le mot de passe est faux
if (!$user || !password_verify($password, $user['password_hash'])) {
    json_out(["status" => "error", "message" => "Email ou mot de passe incorrect"]);
}

// ✅ Un compte non vérifié ne peut pas se connecter
if ((int) $user['verified'] !== 1) {
    json_out([
        "status"     => "error",
        "unverified" => true,
        "message"    => "Compte non vérifié : entre le code reçu par e-mail",
    ]);
}

$user_id = (int) $user['id'];
json_out([
    "status"  => "success",
    "message" => "Connexion réussie",
    "pseudo"  => $user['pseudo'],
    "id"      => $user_id,
    "token"   => create_token($conn, $user_id),
]);
