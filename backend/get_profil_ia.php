<?php
require __DIR__ . '/bootstrap.php';
require_post();

// ✅ L'utilisateur vient du jeton : impossible de lire le profil d'un autre
$user_id = require_user($conn);

// Dernier profil
$stmt = $conn->prepare("SELECT * FROM profil_ia WHERE user_id = ? ORDER BY id DESC LIMIT 1");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$profil = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$profil) {
    json_out(["status" => "no_profil"]);
}

// Tout l'historique
$hist = $conn->prepare(
    "SELECT objectif_principal, niveau_sportif, poids, created_at
     FROM profil_ia WHERE user_id = ? ORDER BY id DESC"
);
$hist->bind_param("i", $user_id);
$hist->execute();
$historique = $hist->get_result()->fetch_all(MYSQLI_ASSOC);
$hist->close();

json_out([
    "status" => "success",
    "profil" => [
        "objectif_principal"         => $profil['objectif_principal'],
        "niveau_sportif"             => $profil['niveau_sportif'],
        "poids"                      => (string) $profil['poids'],
        "taille"                     => (string) $profil['taille'],
        "frequence"                  => (string) $profil['frequence'],
        "pathologies_blessures"      => $profil['pathologies_blessures'] ?: 'Aucune',
        "antecedents_cardio_perso"   => (string) $profil['antecedents_cardio_perso'],
        "antecedents_cardio_famille" => (string) $profil['antecedents_cardio_famille'],
        "qualite_sommeil"            => $profil['qualite_sommeil'],
        "niveau_stress"              => (string) $profil['niveau_stress'],
        "created_at"                 => $profil['created_at'],
    ],
    "historique" => $historique,
]);
