<?php
// insert_order.php

// config DB — remplace par tes valeurs InfinityFree
$dbhost = 'sql206.infinityfree.com';
$dbname = 'if0_40626529_n8n';
$dbuser = 'if0_40626529';
$dbpass = '0O1j1hXq5TBg0wL';

try {
  $pdo = new PDO(
      "mysql:host=$dbhost;dbname=$dbname;charset=utf8mb4", 
      $dbuser, 
      $dbpass,
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]
  );
} catch (Exception $e) {
      http_response_code(500);
      echo json_encode(['error'=>'DB connection failed']);
      exit;
}
