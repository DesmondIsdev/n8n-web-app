# QUICK FIX for 403 Forbidden Error

## Problem
The container is running with an OLD image from before the Dockerfile was fixed.
The new Dockerfile that copies files correctly hasn't been deployed yet.

## Solution: Rebuild with New Dockerfile

### On Your Deployment Server

```bash
# SSH to your server
ssh root@your-deployment-server

# Navigate to deployment directory
cd n8n-web-app

# Stop containers
docker-compose down

# Remove old images (IMPORTANT!)
docker rmi n8n-web-app:latest n8n-web-app:* 2>/dev/null || true

# Rebuild with updated Dockerfile
docker-compose build --no-cache

# Start containers
docker-compose up -d

# Wait for startup
sleep 15

# Verify files are in container
docker-compose exec web ls -la /var/www/html/

# You should see:
# -rw-r--r-- 1 www-data www-data  610 ... index.php  ← THIS MUST BE THERE!
# -rw-r--r-- 1 www-data www-data 9968 ... index2.html
# -rw-r--r-- 1 www-data www-data  842 ... .htaccess
# drwxr-xr-x 2 www-data www-data 4096 ... api

# Test
curl http://localhost:8282
```

## If Files Still Missing

The htdocs directory might not have been transferred. Copy files manually:

```bash
# On deployment server
cd n8n-web-app

# Check if htdocs exists
ls -la htdocs/

# If htdocs is empty or missing, you need to transfer it
# From your local machine or Jenkins:
scp -r htdocs/ root@your-server:n8n-web-app/

# Then rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Or Use Jenkins to Deploy

**Recommended: Let Jenkins deploy the fix**

1. Commit and push all changes:
   ```bash
   git add Dockerfile htdocs/.htaccess verify-deployment.sh
   git commit -m "Fix: Explicit file copying in Dockerfile to resolve 403 error"
   git push origin master
   ```

2. Jenkins will:
   - Build with new Dockerfile
   - Transfer updated files
   - Deploy to server
   - Verify deployment

3. Approve the production deployment when prompted

## Verify the Fix

After rebuilding, you should see in the build output:
```
=== Files in /var/www/html ===
total 32
drwxr-xr-x 3 www-data www-data 4096 Dec 11 03:40 .
drwxr-xr-x 3 root     root     4096 Dec 11 03:40 ..
-rw-r--r-- 1 www-data www-data  842 Dec 11 03:40 .htaccess
drwxr-xr-x 2 www-data www-data 4096 Dec 11 03:40 api
-rw-r--r-- 1 www-data www-data  713 Dec 11 03:40 db.php
-rw-r--r-- 1 www-data www-data  610 Dec 11 03:40 index.php      ← MUST BE HERE!
-rw-r--r-- 1 www-data www-data 9968 Dec 11 03:40 index2.html
-rw-r--r-- 1 www-data www-data 1194 Dec 11 03:40 insert_order.php
-rw-r--r-- 1 www-data www-data   60 Dec 11 03:40 test_db.php
=== End of file listing ===
```

## Test

```bash
# Should return HTML (not 403)
curl http://localhost:8282

# Or visit in browser
# http://your-server-ip:8282
```

## Why This Happened

1. Dockerfile was fixed locally
2. But the running container uses the OLD image
3. Docker doesn't automatically rebuild
4. Need to explicitly rebuild with `--no-cache` to use new Dockerfile

## Next Steps

Once working, the 403 error should be gone and you'll see your order form!
