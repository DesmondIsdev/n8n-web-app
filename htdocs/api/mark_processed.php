<?php
    include_once '../db.php';

// mark_processed.php
header('Content-Type: application/json; charset=utf-8');
$API_KEY = '123Abc456def789ghi';
if (!isset($_POST['key']) || $_POST['key'] !== $API_KEY) {
  http_response_code(401); echo json_encode(['error'=>'Unauthorized']); exit;
}
$id = isset($_POST['id']) ? intval($_POST['id']) : 0;
if ($id <= 0) { http_response_code(400); echo json_encode(['error'=>'Invalid id']); exit; }




$stmt = $pdo->prepare("UPDATE orders SET status='processed' WHERE id=:id");
$stmt->execute([':id'=>$id]);
echo json_encode(['success'=>true]);
