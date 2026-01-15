#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Prebuild Docker Image
# Build the Docker image ahead of time so setup.sh is fast
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════════════════════"
echo "  Pre-building Donna Agent Docker Image"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "This only needs to be done once (or after Dockerfile changes)."
echo "After this, ./setup.sh will start containers in seconds."
echo ""

cd "$SCRIPT_DIR"

# Build the image
echo "Building image..."
time docker compose build

echo ""
echo "✅ Image built! Future setup.sh runs will be fast."
echo ""
echo "To verify: docker images | grep donna"
docker images | grep donna || echo "(image built but may have different name)"
