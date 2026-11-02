<?php
require __DIR__ . '/bootstrap.php';
require_post();

$token = $_POST['token'] ?? '';
if (is_string($token) && $token !== '') {
    $hash = hash('sha256', $token);
    $stmt = $conn->prepare("DELETE FROM auth_tokens WHERE token_hash = ?");
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    $stmt->close();
}
json_out(["status" => "success"]);
