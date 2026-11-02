<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/../PHPMailer/src/Exception.php';
require_once __DIR__ . '/../PHPMailer/src/PHPMailer.php';
require_once __DIR__ . '/../PHPMailer/src/SMTP.php';

function envoyerCodeEmail(string $destinataire, string $code): bool
{
    $config = athletix_config();
    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host       = $config['smtp_host'];
        $mail->SMTPAuth   = true;
        $mail->Username   = $config['smtp_user'];
        $mail->Password   = $config['smtp_pass'];
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = (int) $config['smtp_port'];
        $mail->CharSet    = 'UTF-8';

        $mail->setFrom($config['smtp_user'], $config['smtp_from_name']);
        $mail->addAddress($destinataire);

        $mail->isHTML(true);
        $mail->Subject = 'Ton code de vérification Athletix';
        $mail->Body    = "Bonjour, ton code de validation est : <b>$code</b>. Il est valable 10 minutes.";

        $mail->send();
        return true;
    } catch (Exception $e) {
        return false;
    }
}

// Génère un nouveau code à 6 chiffres valable 10 minutes et remet le compteur d'essais à zéro.
function nouveauCodeVerification(mysqli $conn, int $user_id): string
{
    $code = (string) random_int(100000, 999999);
    $stmt = $conn->prepare(
        "UPDATE users SET verification_code = ?, verification_expires = DATE_ADD(NOW(), INTERVAL 10 MINUTE),
         verification_attempts = 0 WHERE id = ?"
    );
    $stmt->bind_param("si", $code, $user_id);
    $stmt->execute();
    $stmt->close();
    return $code;
}
