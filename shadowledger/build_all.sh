#!/usr/bin/env bash
# build_all.sh - regenerates Stages 1-5 with fresh, randomized flags.
# Run this once per deployment/cohort. Requires the packages listed in
# README.md to already be installed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Stage 1: OSINT ==="
python3 "${SCRIPT_DIR}/stage1-osint/build_stage1.py"

echo -e "\n=== Stage 2: Steganography ==="
python3 "${SCRIPT_DIR}/stage2-stego/build_stage2.py"

echo -e "\n=== Stage 3: Cryptography ==="
python3 "${SCRIPT_DIR}/stage3-crypto/build_stage3.py"

echo -e "\n=== Stage 4: Forensics ==="
python3 "${SCRIPT_DIR}/stage4-forensics/build_stage4.py"

echo -e "\n=== Stage 5: Networking ==="
python3 "${SCRIPT_DIR}/stage5-network/build_stage5.py"

echo -e "\n=== All done ==="
echo "Each stage's SOLUTION.txt has been (re)written with the new flag."
echo "Collect them for your own grading/answer-key reference:"
find "${SCRIPT_DIR}" -name "SOLUTION.txt"
