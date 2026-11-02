<?php
// Modèle de configuration : copie ce fichier en config.local.php (ignoré par Git)
// puis remplace les valeurs par les tiennes.

return [
    // Base de données MySQL / MariaDB
    'db_host' => 'localhost',
    'db_user' => 'root',
    'db_pass' => '',
    'db_name' => 'athletix-pro',

    // Envoi du code de vérification (SMTP Gmail avec un mot de passe d'application)
    'smtp_host'      => 'smtp.gmail.com',
    'smtp_port'      => 587,
    'smtp_user'      => 'ton.email@exemple.com',
    'smtp_pass'      => 'MOT_DE_PASSE_APPLICATION',
    'smtp_from_name' => 'Athletix-Data',

    // Origine autorisée à appeler l'API (CORS). Exemple en local avec Flutter Web :
    // 'http://localhost:5000'. Ne pas mettre '*' en production.
    'allowed_origin' => 'http://localhost:5000',

    // Durée de validité d'un jeton de session, en heures
    'token_ttl_hours' => 168,
];
