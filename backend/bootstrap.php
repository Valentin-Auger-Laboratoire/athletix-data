<?php
// Inclus en tête de chaque script de l'API : CORS, JSON, connexion BDD et authentification.

require_once __DIR__ . '/config.php';

$config = athletix_config();

// ✅ CORS limité à l'origine configurée
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '' && $origin === $config['allowed_origin']) {
    header("Access-Control-Allow-Origin: $origin");
    header("Vary: Origin");
    header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, ngrok-skip-browser-warning");
}
header("Content-Type: application/json");

// ✅ Répondre immédiatement aux requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

mysqli_report(MYSQLI_REPORT_OFF);
$conn = new mysqli($config['db_host'], $config['db_user'], $config['db_pass'], $config['db_name']);
if ($conn->connect_error) {
    json_out(["status" => "error", "message" => "Connexion BDD échouée"], 500);
}
$conn->set_charset('utf8mb4');

function json_out(array $data, int $code = 200): void
{
    http_response_code($code);
    echo json_encode($data);
    exit();
}

function require_post(): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        json_out(["status" => "error", "message" => "Méthode non autorisée"], 405);
    }
}

// Crée un jeton de session pour l'utilisateur. Seul le hash SHA-256 est stocké en base.
function create_token(mysqli $conn, int $user_id): string
{
    $token = bin2hex(random_bytes(32));
    $hash  = hash('sha256', $token);
    $ttl   = (int) athletix_config()['token_ttl_hours'];

    $stmt = $conn->prepare(
        "INSERT INTO auth_tokens (user_id, token_hash, expires_at)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))"
    );
    $stmt->bind_param("isi", $user_id, $hash, $ttl);
    $stmt->execute();
    $stmt->close();

    return $token;
}

// Renvoie l'id de l'utilisateur lié au jeton envoyé en POST, ou répond 401.
function require_user(mysqli $conn): int
{
    $token = $_POST['token'] ?? '';
    if (!is_string($token) || !preg_match('/^[a-f0-9]{64}$/', $token)) {
        json_out(["status" => "error", "message" => "Session invalide"], 401);
    }

    $hash = hash('sha256', $token);
    $stmt = $conn->prepare("SELECT user_id FROM auth_tokens WHERE token_hash = ? AND expires_at > NOW()");
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        json_out(["status" => "error", "message" => "Session expirée, reconnecte-toi"], 401);
    }
    return (int) $row['user_id'];
}
