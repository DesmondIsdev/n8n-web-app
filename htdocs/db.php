<?php
// db.php - Database configuration

// Get database configuration from environment variables with fallback to InfinityFree values
$dbhost = getenv('DB_HOST') ?: 'sql206.infinityfree.com';
$dbname = getenv('DB_NAME') ?: 'if0_40626529_n8n';
$dbuser = getenv('DB_USER') ?: 'if0_40626529';
$dbpass = getenv('DB_PASS') ?: '0O1j1hXq5TBg0wL';

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
