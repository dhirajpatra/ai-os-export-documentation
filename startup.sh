#!/bin/bash
set -e

# stop server if running
docker compose down

# start server
cd /home/dhiraj/Desktop/projects/ai-os-export-documentation/
docker compose up -d

# check server status
docker ps

# check images
docker images

# prune unused images
docker image prune -f
docker builder prune -f
docker images
docker ps
docker system df
