#!/usr/bin/env bash
# package_outputs.sh - run this AFTER build_all.sh (and after starting the
# Docker services) to separate what players should receive from what
# must stay private.
#
# Produces two folders at the repo root:
#   player_deliverables/   - safe to upload into CTFd as challenge attachments
#   admin_only/             - SOLUTION.txt files, source with embedded
#                             secrets (oracle key, etc.), and infra config.
#                             NEVER give this folder to players.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYER_DIR="${SCRIPT_DIR}/player_deliverables"
ADMIN_DIR="${SCRIPT_DIR}/admin_only"

rm -rf "${PLAYER_DIR}" "${ADMIN_DIR}"
mkdir -p "${PLAYER_DIR}/stage1-osint" \
         "${PLAYER_DIR}/stage2-stego" \
         "${PLAYER_DIR}/stage3-crypto" \
         "${PLAYER_DIR}/stage4-forensics" \
         "${PLAYER_DIR}/stage5-network"
mkdir -p "${ADMIN_DIR}"

echo "=== Collecting player-facing deliverables ==="

# Stage 1 - the whole mock site, zipped
( cd "${SCRIPT_DIR}/stage1-osint/site" && zip -rq "${PLAYER_DIR}/stage1-osint/stage1-osint.zip" . )
cp "${SCRIPT_DIR}/stage1-osint/CHALLENGE.md" "${PLAYER_DIR}/stage1-osint/"

# Stage 2 - the stego image
cp "${SCRIPT_DIR}/stage2-stego/dist/memo_backup.jpg" "${PLAYER_DIR}/stage2-stego/"
cp "${SCRIPT_DIR}/stage2-stego/CHALLENGE.md" "${PLAYER_DIR}/stage2-stego/"

# Stage 3 - the encrypted memo only (NOT crypto_oracle.py - it has the key)
cp "${SCRIPT_DIR}/stage3-crypto/dist/memo.txt.enc" "${PLAYER_DIR}/stage3-crypto/"
cp "${SCRIPT_DIR}/stage3-crypto/CHALLENGE.md" "${PLAYER_DIR}/stage3-crypto/"

# Stage 4 - the disk image and log
cp "${SCRIPT_DIR}/stage4-forensics/dist/endpoint.img" "${PLAYER_DIR}/stage4-forensics/"
cp "${SCRIPT_DIR}/stage4-forensics/dist/access.log" "${PLAYER_DIR}/stage4-forensics/"
cp "${SCRIPT_DIR}/stage4-forensics/CHALLENGE.md" "${PLAYER_DIR}/stage4-forensics/"

# Stage 5 - the pcap only (NOT ftp_share/ - that's served live by the
# container, not handed out as a file, and NOT build_stage5.py which
# contains the passphrase-generation logic)
cp "${SCRIPT_DIR}/stage5-network/dist/breach_capture.pcap" "${PLAYER_DIR}/stage5-network/"
cp "${SCRIPT_DIR}/stage5-network/CHALLENGE.md" "${PLAYER_DIR}/stage5-network/"

# Stage 6 has no downloadable files - it's a live target only (ctf-hard-box)

echo "=== Collecting admin-only files (solutions + anything with embedded secrets) ==="

for stage in stage1-osint stage2-stego stage3-crypto stage4-forensics stage5-network; do
    if [ -f "${SCRIPT_DIR}/${stage}/SOLUTION.txt" ]; then
        mkdir -p "${ADMIN_DIR}/${stage}"
        cp "${SCRIPT_DIR}/${stage}/SOLUTION.txt" "${ADMIN_DIR}/${stage}/"
    fi
done

# Source files that contain secrets/answers and must never reach players:
mkdir -p "${ADMIN_DIR}/stage3-crypto"
cp "${SCRIPT_DIR}/stage3-crypto/crypto_oracle.py" "${ADMIN_DIR}/stage3-crypto/"   # contains KEY
cp "${SCRIPT_DIR}/stage3-crypto/build_stage3.py" "${ADMIN_DIR}/stage3-crypto/"

mkdir -p "${ADMIN_DIR}/stage5-network"
cp "${SCRIPT_DIR}/stage5-network/build_stage5.py" "${ADMIN_DIR}/stage5-network/"
if [ -d "${SCRIPT_DIR}/stage5-network/ftp_share" ]; then
    cp -r "${SCRIPT_DIR}/stage5-network/ftp_share" "${ADMIN_DIR}/stage5-network/"
fi

mkdir -p "${ADMIN_DIR}/stage1-osint" && cp "${SCRIPT_DIR}/stage1-osint/build_stage1.py" "${ADMIN_DIR}/stage1-osint/"
mkdir -p "${ADMIN_DIR}/stage2-stego" && cp "${SCRIPT_DIR}/stage2-stego/build_stage2.py" "${ADMIN_DIR}/stage2-stego/"
mkdir -p "${ADMIN_DIR}/stage4-forensics" && cp "${SCRIPT_DIR}/stage4-forensics/build_stage4.py" "${ADMIN_DIR}/stage4-forensics/"

# One consolidated answer key for quick reference
{
    echo "=== Operation ShadowLedger - Consolidated Answer Key ==="
    echo "Generated: $(date)"
    echo ""
    for stage in stage1-osint stage2-stego stage3-crypto stage4-forensics stage5-network; do
        if [ -f "${SCRIPT_DIR}/${stage}/SOLUTION.txt" ]; then
            echo "--- ${stage} ---"
            cat "${SCRIPT_DIR}/${stage}/SOLUTION.txt"
            echo ""
        fi
    done
} > "${ADMIN_DIR}/ALL_SOLUTIONS_COMBINED.txt"

echo ""
echo "=== Done ==="
echo "Player-facing files (safe to upload to CTFd): ${PLAYER_DIR}"
find "${PLAYER_DIR}" -type f
echo ""
echo "Admin-only files (KEEP PRIVATE - solutions + secret-bearing source): ${ADMIN_DIR}"
find "${ADMIN_DIR}" -type f
