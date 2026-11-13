<?php
// Limite du nombre d'essais (migration 006) : ralentit qui essaie des mots de passe en boucle.
//   - connexion : 5 échecs pour un même e-mail en 15 min, puis blocage jusqu'à ce que le plus ancien sorte
//     de la fenêtre ; 30 échecs pour une même adresse IP (plusieurs e-mails essayés) ;
//   - renvoi du code de vérification : 3 demandes pour un même e-mail en 15 min (évite d'inonder une boîte) ;
//   - suppression du compte : 5 mots de passe faux en 15 min.
// Les clés sont des empreintes SHA-256 : la table ne contient ni e-mail ni adresse IP en clair.

const LIMITES = [
    'connexion'    => [5, 900],
    'connexion_ip' => [30, 900],
    'renvoi_code'  => [3, 900],
    'suppression'  => [5, 900],
];

function cle_essai(string $valeur): string
{
    return hash('sha256', mb_strtolower(trim($valeur)));
}

function adresse_client(): string
{
    return $_SERVER['REMOTE_ADDR'] ?? 'inconnue';  // pas X-Forwarded-For : il se falsifie
}

/** Secondes d'attente si la limite est atteinte, sinon 0. */
function attente_essais(mysqli $conn, string $action, string $cle): int
{
    [$max, $fenetre] = LIMITES[$action];
    $stmt = $conn->prepare(
        "SELECT COUNT(*) AS n, TIMESTAMPDIFF(SECOND, NOW(), MIN(quand) + INTERVAL ? SECOND) AS reste
         FROM tentatives WHERE action = ? AND cle = ? AND quand > NOW() - INTERVAL ? SECOND"
    );
    $stmt->bind_param("issi", $fenetre, $action, $cle, $fenetre);
    $stmt->execute();
    $r = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int) $r['n'] >= $max ? max(1, (int) $r['reste']) : 0;
}

/** Refuse la requête (HTTP 429) si la limite est atteinte. */
function verifier_essais(mysqli $conn, string $action, string $cle): void
{
    $attente = attente_essais($conn, $action, $cle);
    if ($attente > 0) {
        $minutes = (int) ceil($attente / 60);
        json_out(["status" => "error", "trop_d_essais" => true, "attente_s" => $attente,
                  "message" => "Trop d'essais : réessaie dans $minutes min"], 429);
    }
}

function noter_essai(mysqli $conn, string $action, string $cle): void
{
    $stmt = $conn->prepare("INSERT INTO tentatives (action, cle) VALUES (?, ?)");
    $stmt->bind_param("ss", $action, $cle);
    $stmt->execute();
    $stmt->close();
    // Ménage : rien n'est gardé plus d'un jour
    $conn->query("DELETE FROM tentatives WHERE quand < NOW() - INTERVAL 1 DAY");
}

function effacer_essais(mysqli $conn, string $action, string $cle): void
{
    $stmt = $conn->prepare("DELETE FROM tentatives WHERE action = ? AND cle = ?");
    $stmt->bind_param("ss", $action, $cle);
    $stmt->execute();
    $stmt->close();
}
