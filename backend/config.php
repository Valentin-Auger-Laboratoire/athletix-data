<?php
// Configuration unique du backend (base de données + SMTP + CORS).
// Les valeurs réelles sont lues dans config.local.php, qui n'est jamais versionné.

function athletix_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }

    $local = __DIR__ . '/config.local.php';
    if (!is_file($local)) {
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode([
            'status'  => 'error',
            'message' => 'config.local.php manquant : copie config.example.php en config.local.php',
        ]);
        exit();
    }

    $defaults = require __DIR__ . '/config.example.php';
    $config = array_merge($defaults, require $local);
    return $config;
}
