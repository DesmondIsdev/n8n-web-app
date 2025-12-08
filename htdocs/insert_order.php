<?php
    
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once "db.php";

header('Content-Type: application/json; charset=utf-8');

// SECURITÉ
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
  echo json_encode(['error'=>'Invalid method']);
  exit;
}

$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$product = trim($_POST['product'] ?? '');
$phone = trim($_POST['phone'] ?? '');
$comment = trim($_POST['comment'] ?? '');

if ($name === '' || $email === '' || $product === '') {
  http_response_code(400);
  echo json_encode(['error'=>'Missing fields']);
  exit;
}

try {
    $stmt = $pdo->prepare("
        INSERT INTO orders (name,email,product,phone,comment)
        VALUES (:name,:email,:product,:phone,:comment)
    ");

    $stmt->execute([
      ':name' => $name,
      ':email' => $email,
      ':product' => $product,
      ':phone' => $phone,
      ':comment' => $comment
    ]);

    echo json_encode([
      'success' => true,
      'id' => $pdo->lastInsertId()
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error'=>'SQL error', 'message' => $e->getMessage()]);
}
