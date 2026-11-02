<?php
require __DIR__ . '/bootstrap.php';
require_post();

const MAX_ESSAIS = 5;

$email = trim($_POST['email'] ?? '');
$code  = trim($_POST['code']  ?? '');

if ($email === '' || $code === '') {
    json_out(["status" => "error", "message" => "Champs manquants"]);
}

$stmt = $conn->prepare(
    "SELECT id, pseudo, verified, verification_code, verification_attempts,
            (verification_expires > NOW()) AS valide
     FROM users WHERE email = ?"
);
$stmt->bind_param("s", $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user || (int) $user['verified'] === 1 || $user['verification_code'] === null) {
    json_out(["status" => "error", "message" => "Aucune vérification en attente pour cet email"]);
}
if (!(int) $user['valide']) {
    json_out(["status" => "error", "message" => "Code expiré, demande un nouveau code"]);
}
if ((int) $user['verification_attempts'] >= MAX_ESSAIS) {
    json_out(["status" => "error", "message" => "Trop d'essais, demande un nouveau code"]);
}

$user_id = (int) $user['id'];

if (!hash_equals((string) $user['verification_code'], $code)) {
    $inc = $conn->prepare("UPDATE users SET verification_attempts = verification_attempts + 1 WHERE id = ?");
    $inc->bind_param("i", $user_id);
    $inc->execute();
    $inc->close();
    json_out(["status" => "error", "message" => "Code incorrect"]);
}

// ✅ Compte vérifié : le code est effacé pour ne pas être réutilisé
$update = $conn->prepare(
    "UPDATE users SET verified = 1, verification_code = NULL, verification_expires = NULL WHERE id = ?"
);
$update->bind_param("i", $user_id);
$update->execute();
$update->close();

json_out([
    "status"  => "success",
    "message" => "Compte vérifié !",
    "id"      => $user_id,
    "pseudo"  => $user['pseudo'],
    "token"   => create_token($conn, $user_id),
]);
