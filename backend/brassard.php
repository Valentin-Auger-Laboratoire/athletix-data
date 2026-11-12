<?php
// Fonctions communes aux routes qui reçoivent des données du brassard (via l'application).
// Le brassard est identifié par son numéro de série GATT (0x2A25), voir architecture/GATT.md.

// Lit un entier POST et vérifie qu'il est dans [min, max]. Répond une erreur précise sinon.
function entier_post(string $champ, int $min, int $max, ?int $defaut = null): int
{
    $brut = $_POST[$champ] ?? null;
    if ($brut === null || $brut === '') {
        if ($defaut !== null) {
            return $defaut;
        }
        json_out(["status" => "error", "message" => "Champ manquant : $champ"], 400);
    }
    if (!is_string($brut) || !preg_match('/^-?\d+$/', $brut)) {
        json_out(["status" => "error", "message" => "Champ invalide : $champ doit être un entier"], 400);
    }
    $valeur = (int) $brut;
    if ($valeur < $min || $valeur > $max) {
        json_out(["status" => "error", "message" => "Champ invalide : $champ doit être entre $min et $max"], 400);
    }
    return $valeur;
}

// Crée le brassard s'il est inconnu, sinon le met à jour, et le lie à l'utilisateur.
// Renvoie son id. Un brassard qui change de main est simplement réattribué (prototype).
function brassard_pour_utilisateur(mysqli $conn, int $user_id, string $numero_serie, ?string $firmware, ?int $batterie = null): int
{
    if (!preg_match('/^[A-Za-z0-9-]{4,32}$/', $numero_serie)) {
        json_out(["status" => "error", "message" => "Numéro de série du brassard invalide"], 400);
    }
    if ($firmware !== null && ($firmware === '' || mb_strlen($firmware) > 20)) {
        $firmware = null;
    }

    // id = LAST_INSERT_ID(id) : insert_id renvoie aussi l'id quand la ligne existait déjà
    $stmt = $conn->prepare(
        "INSERT INTO brassards (user_id, numero_serie, firmware, batterie_niveau, derniere_synchro)
         VALUES (?, ?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id), user_id = VALUES(user_id),
             firmware = COALESCE(VALUES(firmware), firmware),
             batterie_niveau = COALESCE(VALUES(batterie_niveau), batterie_niveau),
             derniere_synchro = NOW()"
    );
    $stmt->bind_param("issi", $user_id, $numero_serie, $firmware, $batterie);
    if (!$stmt->execute()) {
        json_out(["status" => "error", "message" => "Erreur lors de l'enregistrement du brassard"], 500);
    }
    $id = (int) $stmt->insert_id;
    $stmt->close();
    return $id;
}

// Niveau de batterie facultatif (caractéristique GATT 0x2A19), en %.
function batterie_post(): ?int
{
    if (($_POST['batterie'] ?? '') === '') {
        return null;
    }
    return entier_post('batterie', 0, 100);
}

// Entier facultatif : null si le champ est absent ou vide, sinon contrôlé comme entier_post().
function entier_post_facultatif(string $champ, int $min, int $max): ?int
{
    if (($_POST[$champ] ?? '') === '') {
        return null;
    }
    return entier_post($champ, $min, $max);
}

// Nombre décimal facultatif (point ou virgule), contrôlé dans [min, max].
function decimal_post_facultatif(string $champ, float $min, float $max): ?float
{
    $brut = $_POST[$champ] ?? '';
    if ($brut === '') {
        return null;
    }
    $brut = str_replace(',', '.', (string) $brut);
    if (!is_numeric($brut)) {
        json_out(["status" => "error", "message" => "Champ invalide : $champ doit être un nombre"], 400);
    }
    $v = (float) $brut;
    if ($v < $min || $v > $max) {
        json_out(["status" => "error", "message" => "Champ invalide : $champ doit être entre $min et $max"], 400);
    }
    return round($v, 1);
}

// Texte facultatif, coupé à $max caractères.
function texte_post_facultatif(string $champ, int $max): ?string
{
    $t = trim((string) ($_POST[$champ] ?? ''));
    if ($t === '') {
        return null;
    }
    return mb_substr($t, 0, $max);
}

// Courbe résumée : tableau JSON d'au plus 2 000 entiers entre 0 et 255. Renvoie le JSON normalisé.
function courbe_post(): ?string
{
    $brut = $_POST['courbe'] ?? '';
    if ($brut === '') {
        return null;
    }
    $valeurs = json_decode((string) $brut, true);
    if (!is_array($valeurs) || count($valeurs) > 2000) {
        json_out(["status" => "error", "message" => "Champ invalide : courbe (tableau d'au plus 2000 valeurs)"], 400);
    }
    foreach ($valeurs as $v) {
        if (!is_int($v) || $v < 0 || $v > 255) {
            json_out(["status" => "error", "message" => "Champ invalide : courbe (entiers de 0 à 255)"], 400);
        }
    }
    return json_encode(array_values($valeurs));
}
