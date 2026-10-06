#!/usr/bin/env bash
# deploy_shadowledger.sh
#
# Run this from YOUR OWN MACHINE (the one with SSH access to the Ubuntu
# Server VM) - not inside any sandboxed environment. It:
#   1. Wipes all existing Docker containers/images/volumes/networks on the VM
#   2. Uploads ctf-hard-box/ and shadowledger/ to the VM over SSH (rsync)
#   3. Runs the host setup script + brings up all Docker services on the VM
#   4. Runs the packaging script to split player-facing vs admin-only files
#   5. Copies the admin-only bundle (solutions, secrets) BACK to your own
#      machine, so it never sits exposed on the target VM longer than needed
#
# Requires: ssh access already working (see earlier steps in this
# conversation), rsync installed locally (apt install rsync / brew install
# rsync), and the two project folders present locally:
#   ./ctf-hard-box/
#   ./shadowledger/
#
# Usage:
#   chmod +x deploy_shadowledger.sh
#   ./deploy_shadowledger.sh user@192.168.56.108
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 user@vm-ip"
    exit 1
fi
REMOTE="$1"
REMOTE_HOME="~"   # adjust if your remote home isn't the default

echo "=================================================="
echo " Step 1: Wiping ALL existing Docker state on ${REMOTE}"
echo "=================================================="
ssh "${REMOTE}" '
    set -e
    echo "--- stopping every running container ---"
    sudo docker ps -q | xargs -r sudo docker stop

    echo "--- removing every container (running or stopped) ---"
    sudo docker ps -aq | xargs -r sudo docker rm -f

    echo "--- removing every image ---"
    sudo docker images -q | xargs -r sudo docker rmi -f

    echo "--- removing every custom network ---"
    sudo docker network ls --filter type=custom -q | xargs -r sudo docker network rm

    echo "--- removing every volume ---"
    sudo docker volume ls -q | xargs -r sudo docker volume rm -f

    echo "--- final full prune (build cache, dangling everything) ---"
    sudo docker system prune -af --volumes

    echo "--- confirming clean state ---"
    sudo docker ps -a
    sudo docker images
    sudo docker network ls
    sudo docker volume ls
'

echo "=================================================="
echo " Step 2: Uploading project folders to ${REMOTE}"
echo "=================================================="
rsync -avz --progress ./ctf-hard-box/ "${REMOTE}:${REMOTE_HOME}/ctf-hard-box/"
rsync -avz --progress ./shadowledger/ "${REMOTE}:${REMOTE_HOME}/shadowledger/"

echo "=================================================="
echo " Step 3: Building and starting everything on ${REMOTE}"
echo "=================================================="
ssh "${REMOTE}" '
    set -e

    echo "--- Stage 6: host setup (user2, sudo misconfig, decoy, honeypot, flags) ---"
    cd ~/ctf-hard-box/host_setup
    sudo ./setup_host.sh

    echo "--- Stage 6: building the web app ---"
    cd ~/ctf-hard-box/webapp
    sudo docker compose up -d --build

    echo "--- Stages 1-5: building fresh randomized challenges ---"
    cd ~/shadowledger
    ./build_all.sh

    echo "--- Stage 3: starting the crypto oracle ---"
    cd ~/shadowledger/stage3-crypto
    sudo docker compose up -d --build

    echo "--- Stage 5: starting the network segment ---"
    cd ~/shadowledger/stage5-network
    sudo docker compose up -d --build

    echo "--- Packaging player-facing vs admin-only files ---"
    cd ~/shadowledger
    ./package_outputs.sh

    echo "--- Locking down the firewall ---"
    sudo ufw --force enable
    sudo ufw allow 22/tcp
    sudo ufw allow 58421/tcp
    sudo ufw allow 31337/tcp
    sudo ufw allow 2222/tcp
    sudo ufw allow 4433/tcp
    sudo ufw allow 21/tcp
    sudo ufw allow 21100:21110/tcp
    sudo ufw allow 8000/tcp
    sudo ss -tulpn
'

echo "=================================================="
echo " Step 4: Pulling the admin-only bundle back to THIS machine"
echo "=================================================="
mkdir -p ./admin_only_from_vm
rsync -avz "${REMOTE}:${REMOTE_HOME}/shadowledger/admin_only/" ./admin_only_from_vm/

echo "=================================================="
echo " Done."
echo " - Player-facing files are on the VM at ~/shadowledger/player_deliverables/"
echo "   (upload these into CTFd as challenge attachments)"
echo " - Admin-only files (solutions, secrets) are now ALSO copied locally to"
echo "   ./admin_only_from_vm/ on this machine - keep this folder private."
echo " - The Stage 6 setup_host.sh output (user2 password, both flags) was"
echo "   printed above during Step 3 - copy it from your terminal scrollback"
echo "   now, since it is not saved to a file automatically."
echo "=================================================="
