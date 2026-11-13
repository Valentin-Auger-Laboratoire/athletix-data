<?php
require __DIR__ . '/bootstrap.php';
require __DIR__ . '/limites.php';
require_post();

$email    = trim($_POST['email'] ?? '');
$password = $_POST['password'] ?? '';

if ($email === '' || $password === '') {
    json_out(["status" => "error", "message" => "Champs manquants"]);
}

// Trop d'échecs récents pour cet e-mail ou depuis cette adresse : refusé AVANT de vérifier le mot de passe
$cle_email = cle_essai($email);
$cle_ip = cle_essai(adresse_client());
verifier_essais($conn, 'connexion', $cle_email);
verifier_essais($conn, 'connexion_ip', $cle_ip);

$stmt = $conn->prepare("SELECT id, pseudo, password_hash, verified FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Même message si l'email ou le mot de passe est faux
if (!$user || !password_verify($password, $user['password_hash'])) {
    noter_essai($conn, 'connexion', $cle_email);
    noter_essai($conn, 'connexion_ip', $cle_ip);
    json_out(["status" => "error", "message" => "Email ou mot de passe incorrect"]);
}
effacer_essais($conn, 'connexion', $cle_email);

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
