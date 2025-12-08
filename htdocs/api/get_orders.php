<?php
    include_once '../db.php';
// get_orders.php
header('Content-Type: application/json; charset=utf-8');

$API_KEY = 'Abc123def456ghi789jkl'; // clé de sécurité que je défini pour cet api 

if (!isset($_GET['key']) || $_GET['key'] !== $API_KEY) {
  http_response_code(401);
  echo json_encode(['error'=>'Unauthorized']);
  exit;
}

// Récupération des données de la base de données
$stmt = $pdo->prepare("SELECT id,name,email,product,phone,comment,created_at FROM orders WHERE status='pending' ORDER BY id ASC LIMIT 50");
$stmt->execute();
$data = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo json_encode(['success'=>true, 'orders'=>$data]);
