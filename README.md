# Operation ShadowLedger - CTF Play Box
## IE3132 Penetration Testing - Assignment 02 (Working Box)

A six-stage, seven-domain Capture-The-Flag box built around a single
NovaGrid Utilities breach-investigation scenario. This README lets you
deploy, run, and reset the entire box from the submitted files.

**Group:** IT24102014 _ IT24102019 _ IT24102083 _ IT24102146
**Members & roles:**
- IT24102014 — Sooriyakumara S.M.N.H - CTF Platform & Architecture
- IT24102019 — Balasooriya N.N - Challenge Design A (Stages 1–3)
- IT24102083 — Silva K.K.S - Challenge Design B (Stages 4–6)
- IT24102146 — Peiris M.I.T - Integration, Testing & Documentation

---

## 1. What's in the package
```
ctf-hard-box/                Stage 6 capstone (web app + host setup + attacker scripts)
  webapp/                      Flask app (JWT + pickle RCE), Dockerfile, compose
  host_setup/                  setup_host.sh (user2, sudo misconfig, decoy, honeypot)
  attacker_scripts/            jwt_forge.py, pickle_rce.py, evil.c (solver code)
  honeypot/                    SSH honeypot + log analyser
  docs/                        SOLUTION.md, DESIGN.md
shadowledger/                Stages 1-5
  stage1-osint/                build_stage1.py + CHALLENGE.md
  stage2-stego/                build_stage2.py + CHALLENGE.md
  stage3-crypto/               crypto_oracle.py, build_stage3.py, Dockerfile, compose
  stage4-forensics/            build_stage4.py + CHALLENGE.md
  stage5-network/              build_stage5.py, vsftpd Dockerfile, compose
  flag_utils.py                shared flag generator (meaningful + mixed)
  build_all.sh                 regenerates Stages 1-5 with fresh flags
  package_outputs.sh           splits player files vs admin/solution files
README.md                    this file
```
*(If a custom Next.js platform is also submitted, it is in `shadowledger-web/`
with its own README.)*

---

## 2. Requirements
- **Host:** Ubuntu Server 24.04.4 LTS (classic sudo — required for Stage 6;
  see §7 on why not 26.04), running in VirtualBox with a **Host-only**
  network adapter.
- **Attacker:** a separate Kali Linux VM on the **same host-only network**.
- Packages (install once on the box):
```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin python3-pip \
  steghide libimage-exiftool-perl mtools dosfstools zip vsftpd
pip3 install --break-system-packages pillow scapy paramiko
sudo systemctl enable --now docker
```

---

## 3. Deploy the box

### 3a. Stages 1–5 (challenge files + live services)
```bash
cd shadowledger
chmod +x build_all.sh package_outputs.sh
./build_all.sh            # generates fresh flags + files for stages 1-5
                          # (writes each stage's SOLUTION.txt — keep private)

# start the two live services:
cd stage3-crypto && sudo docker compose up -d --build && cd ..
cd stage5-network && sudo docker compose up -d --build && cd ..

# split player-facing files from admin/solution files:
./package_outputs.sh      # -> player_deliverables/ and admin_only/
```
**Before building Stage 5**, edit `stage5-network/vsftpd.conf` and set
`pasv_address` to the box's real host-only IP (needed for passive FTP from a
separate attacker VM).

### 3b. Stage 6 (capstone VM)
```bash
cd ctf-hard-box
# set the leaked-creds file to the box's real host-only IP first:
#   edit webapp/.internal/host_access.txt -> replace the IP placeholder
cd webapp && sudo docker compose up -d --build && cd ..
cd host_setup && sudo ./setup_host.sh && cd ..
# setup_host.sh prints user2's password + both flags — save these privately
```

### 3c. The platform (CTFd)
```bash
cd ~ && git clone https://github.com/CTFd/CTFd.git && cd CTFd
sudo docker compose up -d        # portal on :8000
```
Then in the CTFd admin UI, create the 6 challenges, paste each CHALLENGE.md
description, upload the matching file(s) from `player_deliverables/`, and set
each flag (exact match). Stage 6 is a live target (no file) and has two flags.

### 3d. Firewall (expose only intended ports)
```bash
sudo ufw enable
for p in 22 8000 4433 21 2222 31337 58421; do sudo ufw allow $p/tcp; done
sudo ufw allow 21100:21110/tcp    # FTP passive range
```

---

## 4. Flag format
- Stages 1–5: `NOVA{...}` (meaningful words + mixed letters/numbers)
- Stage 6: `flag{...}` (two flags: user + root)
Exact-match validation in CTFd. Flags are generated per-deployment by the
build scripts, never hardcoded.

---

## 5. Reset / recovery
- **Stages 1–5 files:** re-run `./build_all.sh` (fresh flags) then
  `./package_outputs.sh`.
- **Live services (3 & 5):** `sudo docker compose restart` in that stage's
  folder returns it to a clean state.
- **Stage 6:** restore the VM snapshot taken after setup, OR re-run
  `setup_host.sh` + `docker compose up -d --build`.
- **CTFd:** data persists in its Docker volumes; `docker compose restart`.

---

## 6. Isolation / security controls
- Single **host-only** virtual network; no bridged/NAT egress during play —
  nothing can reach institutional or public systems.
- Stage 1 OSINT data is **fully synthetic** — no real person's data.
- Only intentionally-vulnerable components; unrelated services firewalled off.
- Stage 6 host runs a decoy service (:31337) and an SSH honeypot (:2222,
  logs attempts, never grants access) for a detection/blue-team angle.

---

## 7. Changes from the Assignment 01 design (with justification)
1. **Stage 6 JWT verification implemented manually.** Modern PyJWT blocks the
   `alg:none` attack via its `decode()` function (raises `InvalidKeyError`),
   so the naive vulnerable implementation didn't work. The verifier now parses
   the JWT header manually to faithfully reproduce the historical alg:none
   vulnerability class — which is how the real vulnerable apps were written.
2. **OS pinned to Ubuntu 24.04.4 LTS (not newer).** Ubuntu 26.04 ships
   `sudo-rs`, which may silently ignore the `env_keep+=LD_PRELOAD` directive
   the Stage 6 privesc depends on. 24.04's classic sudo guarantees the tested
   chain behaves as designed.
3. **Stage 6 split into two flags** (user + root) for two-part scoring.
4. **vsftpd container fixes (Stage 5):** added the chroot directory and fixed
   file permissions so vsftpd serves correctly inside a minimal Docker image.

*(Full detail in the Member 4 video segment and `ctf-hard-box/docs/DESIGN.md`.)*

---

## 8. Self-developed scripts (LO3 evidence)
- **Stage 1:** `build_stage1.py` (challenge generation)
- **Stage 2:** `build_stage2.py`
- **Stage 3:** `crypto_oracle.py` (the oracle service), `build_stage3.py`
- **Stage 4:** `build_stage4.py`
- **Stage 5:** `build_stage5.py` (pcap + archive generation) + pcap decoder
- **Stage 6:** `jwt_forge.py`, `pickle_rce.py`, `evil.c`, `setup_host.sh`,
  honeypot + `analyze_honeypot_log.py`
- **Shared:** `flag_utils.py`, `build_all.sh`, `package_outputs.sh`

---

## 9. Acknowledged external tools / frameworks
CTFd (platform); Docker; Ubuntu; Flask, PyJWT, paramiko, scapy, Pillow
(Python libs); vsftpd; steghide, exiftool, mtools; and standard analysis
tools used on the attacker side (Wireshark, nmap, The Sleuth Kit, gcc,
CyberChef). All used for an isolated, authorized educational CTF only.
