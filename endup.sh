#!/bin/bash
set -e

# stop server if running
cd /home/dhiraj/Desktop/projects/ai-os-export-documentation/
docker compose down

# prune unused images
docker image prune -f
docker builder prune -f
docker images
docker ps
docker system df
