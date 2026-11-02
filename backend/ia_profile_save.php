<?php
require __DIR__ . '/bootstrap.php';
require_post();

// ✅ L'utilisateur vient du jeton : impossible d'écrire dans le profil d'un autre
$user_id = require_user($conn);

$objectif    = $_POST['objectif_principal']    ?? '';
$niveau      = $_POST['niveau_sportif']        ?? '';
$poids       = intval($_POST['poids']          ?? 0);
$taille      = intval($_POST['taille']         ?? 0);
$frequence   = intval($_POST['frequence']      ?? 0);
$pathologies = $_POST['pathologies_blessures'] ?? 'Aucune';
$sommeil     = $_POST['qualite_sommeil']       ?? '';
$stress      = intval($_POST['niveau_stress']  ?? 5);
$cardioPerso = ($_POST['antecedents_cardio_perso']   ?? '0') === '1' ? 1 : 0;
$cardioFam   = ($_POST['antecedents_cardio_famille'] ?? '0') === '1' ? 1 : 0;

// ✅ TOUJOURS INSÉRER — pour garder l'historique complet
$stmt = $conn->prepare("INSERT INTO profil_ia
    (user_id, objectif_principal, niveau_sportif, poids, taille, frequence, pathologies_blessures,
     qualite_sommeil, niveau_stress, antecedents_cardio_perso, antecedents_cardio_famille, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())");
// pathologies_blessures et qualite_sommeil sont des chaînes (s), pas des entiers
$stmt->bind_param("issiiissiii", $user_id, $objectif, $niveau, $poids, $taille, $frequence,
    $pathologies, $sommeil, $stress, $cardioPerso, $cardioFam);

if ($stmt->execute()) {
    json_out(["status" => "success", "message" => "Profil IA sauvegardé !"]);
}
json_out(["status" => "error", "message" => "Erreur lors de l'enregistrement du profil"]);
