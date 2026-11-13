<?php
// Enregistre une séance terminée et son résumé EMG (voir architecture/INTEGRATION.md).
// Appelé par l'application à la fin d'une séance, jamais par le brassard lui-même.
require __DIR__ . '/bootstrap.php';
require __DIR__ . '/brassard.php';
require_post();

$user_id = require_user($conn);

$discipline = trim($_POST['discipline'] ?? '');
if ($discipline === '' || mb_strlen($discipline) > 50) {
    json_out(["status" => "error", "message" => "Champ invalide : discipline (1 à 50 caractères)"], 400);
}

$duree      = entier_post('duree_s', 1, 21600);               // 6 h maximum
$nb_ech     = entier_post('nb_echantillons', 0, 2000000);
$moyenne    = entier_post('intensite_moyenne_pct', 0, 255);   // format du paquet GATT
$max        = entier_post('intensite_max_pct', 0, 255);
$intense    = entier_post('temps_effort_intense_s', 0, 21600);
$nb_alertes = entier_post('nb_alertes', 0, 65535);
$simule     = ($_POST['simule'] ?? '0') === '1' ? 1 : 0;

if ($moyenne > $max) {
    json_out(["status" => "error", "message" => "Incohérent : l'intensité moyenne dépasse l'intensité maximale"], 400);
}
if ($intense > $duree) {
    json_out(["status" => "error", "message" => "Incohérent : le temps d'effort intense dépasse la durée de la séance"], 400);
}

// Facultatif : mesures du téléphone, contexte, résumé enrichi (migration 003)
$distance   = entier_post_facultatif('distance_m', 0, 1000000);
$denivele   = entier_post_facultatif('denivele_m', 0, 20000);
$vitesse    = decimal_post_facultatif('vitesse_moy_kmh', 0, 150);
$nb_pas     = entier_post_facultatif('nb_pas', 0, 200000);
$fc_moy     = entier_post_facultatif('fc_moy', 30, 230);
$fc_max     = entier_post_facultatif('fc_max', 30, 240);
$temp       = decimal_post_facultatif('temperature_c', -50, 60);
$humidite   = entier_post_facultatif('humidite_pct', 0, 100);
$meteo      = entier_post_facultatif('meteo_code', 0, 99);
$ressenti   = entier_post_facultatif('ressenti_fatigue', 0, 10);
$douleur    = entier_post_facultatif('douleur', 0, 10);
$sommeil    = texte_post_facultatif('sommeil', 20);
$commentaire = texte_post_facultatif('commentaire', 500);
$mode_adapte = ($_POST['mode_adapte'] ?? '0') === '1' ? 1 : 0;
$zone_repos   = entier_post_facultatif('temps_zone_repos_s', 0, 21600);
$zone_moderee = entier_post_facultatif('temps_zone_moderee_s', 0, 21600);
$zone_soutenue = entier_post_facultatif('temps_zone_soutenue_s', 0, 21600);
$contractions = entier_post_facultatif('nb_contractions', 0, 65535);
$fatigue      = entier_post_facultatif('indice_fatigue_pct', -100, 1000);
$courbe       = courbe_post();
// Fatigue par la fréquence médiane (migration 005, source RAW seulement)
$mdf_debut    = decimal_post_facultatif('mdf_debut_hz', 0, 1000);
$mdf_fin      = decimal_post_facultatif('mdf_fin_hz', 0, 1000);
$baisse_mdf   = decimal_post_facultatif('baisse_mdf_pct', -100, 100);
$courbe_mdf   = courbe_mdf_post();
$series       = entier_post_facultatif('nb_series', 0, 65535);
$trace        = trace_post();
$client_uuid  = uuid_post();
// Séance envoyée plus tard (pas de réseau à la fin) : le téléphone indique depuis combien de
// secondes elle est finie. Écart relatif mesuré par le téléphone, donc juste même si son horloge
// est à la mauvaise heure (règle R6). 30 jours au plus.
$il_y_a = entier_post('fin_il_y_a_s', 0, 2592000, 0);
if ($fc_moy !== null && $fc_max !== null && $fc_moy > $fc_max) {
    json_out(["status" => "error", "message" => "Incohérent : la fréquence cardiaque moyenne dépasse la maximale"], 400);
}

$ref_mvc = null;
if (($_POST['ref_mvc_mv'] ?? '') !== '') {
    $ref_mvc = entier_post('ref_mvc_mv', 100, 3300);
}

// mysqli ne lance pas d'exception ici (MYSQLI_REPORT_OFF dans bootstrap.php) :
// chaque execute() est vérifié et une erreur annule toute la transaction.
// Déjà reçue (renvoi après une réponse perdue) : on renvoie la même séance, sans doublon
if ($client_uuid !== null) {
    $stmt = $conn->prepare("SELECT id FROM sessions_entrainement WHERE user_id = ? AND client_uuid = ?");
    $stmt->bind_param("is", $user_id, $client_uuid);
    $stmt->execute();
    $deja = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($deja) {
        json_out(["status" => "success", "message" => "Séance déjà enregistrée", "session_id" => (int) $deja['id'],
                  "deja_enregistree" => true]);
    }
}

$conn->begin_transaction();
try {
    $brassard_id = null;
    $serie = trim($_POST['numero_serie'] ?? '');
    if ($serie !== '') {
        $firmware = isset($_POST['firmware']) ? trim($_POST['firmware']) : null;
        $brassard_id = brassard_pour_utilisateur($conn, $user_id, $serie, $firmware, batterie_post());
    }

    // Début et fin fixés par le serveur : l'horloge du téléphone peut être fausse (règle R6)
    $stmt = $conn->prepare(
        "INSERT INTO sessions_entrainement (user_id, brassard_id, discipline, debut, fin, donnees_simulees,
             distance_m, denivele_m, vitesse_moy_kmh, nb_pas, fc_moy, fc_max, temperature_c, humidite_pct,
             meteo_code, ressenti_fatigue, douleur, sommeil, commentaire, mode_adapte, trace_gps, client_uuid)
         VALUES (?, ?, ?, DATE_SUB(NOW(), INTERVAL ? SECOND), DATE_SUB(NOW(), INTERVAL ? SECOND),
                 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $debut_il_y_a = $duree + $il_y_a;
    $stmt->bind_param("iisiiiiidiiidiiiississ", $user_id, $brassard_id, $discipline, $debut_il_y_a, $il_y_a, $simule,
        $distance, $denivele, $vitesse, $nb_pas, $fc_moy, $fc_max, $temp, $humidite,
        $meteo, $ressenti, $douleur, $sommeil, $commentaire, $mode_adapte, $trace, $client_uuid);
    if (!$stmt->execute()) {
        throw new RuntimeException($stmt->error, $stmt->errno);
    }
    $session_id = (int) $stmt->insert_id;
    $stmt->close();

    $stmt = $conn->prepare(
        "INSERT INTO resultats_emg (session_id, duree_s, nb_echantillons, intensite_moyenne_pct,
             intensite_max_pct, temps_effort_intense_s, nb_alertes, temps_zone_repos_s, temps_zone_moderee_s,
             temps_zone_soutenue_s, nb_contractions, nb_series, indice_fatigue_pct, courbe, ref_mvc_mv,
             mdf_debut_hz, mdf_fin_hz, baisse_mdf_pct, courbe_mdf)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $stmt->bind_param("iiiiiiiiiiiiisiddds", $session_id, $duree, $nb_ech, $moyenne, $max, $intense, $nb_alertes,
        $zone_repos, $zone_moderee, $zone_soutenue, $contractions, $series, $fatigue, $courbe, $ref_mvc,
        $mdf_debut, $mdf_fin, $baisse_mdf, $courbe_mdf);
    if (!$stmt->execute()) {
        throw new RuntimeException($stmt->error, $stmt->errno);
    }
    $stmt->close();

    $conn->commit();
} catch (Throwable $e) {
    $conn->rollback();
    // Deux envois simultanés de la même séance : le second bute sur l'index unique (erreur 1062).
    // Ce n'est pas une erreur pour l'utilisateur : la séance est bien enregistrée.
    if ($client_uuid !== null && $e->getCode() === 1062) {
        $stmt = $conn->prepare("SELECT id FROM sessions_entrainement WHERE user_id = ? AND client_uuid = ?");
        $stmt->bind_param("is", $user_id, $client_uuid);
        $stmt->execute();
        $deja = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($deja) {
            json_out(["status" => "success", "message" => "Séance déjà enregistrée", "session_id" => (int) $deja['id'],
                      "deja_enregistree" => true]);
        }
    }
    json_out(["status" => "error", "message" => "Erreur lors de l'enregistrement de la séance"], 500);
}

json_out(["status" => "success", "message" => "Séance enregistrée !", "session_id" => $session_id]);
