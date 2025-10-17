# Dataset of Embedded Systems with Multiple Firmware Versions

This repository provides structured datasets of embedded and industrial systems across multiple firmware versions.  
Each dataset includes automated scripts for downloading, unpacking, and preparing firmware samples.

---

## Datasets Overview

### 1. OpenWRT Dataset (`openwrt_data/`)

**Contents**
- `download_openwrt_images.sh` – Automates downloading and unpacking multiple OpenWRT firmware images.  

---

### 2. WAGO PLC Dataset (`wago_data/`)

This dataset contains real-world firmware samples from WAGO PFC200 programmable logic controllers (PLCs).  
NOTE: The backdoored versions of dropbear are not fully functional as standalone binaries or as part of the firmware sample.

**Contents**
- `setup_wago_data.sh` – End-to-end automation script that:
  1. Downloads firmware versions `03.10.10` and `03.10.08` from WAGO’s public GitHub releases.  
  2. Extracts filesystem contents with `binwalk`.  
  3. Locates and removes the original `usr/sbin/dropbear` binary.  
  4. Inserts controlled replacement binaries:
     - `dropbear86-backdoor` → backdoor variant  
     - `dropbear86-clean` / `dropbear83-clean` → clean variants
  5. Supports choosing between stripped (firmware-like) and symbol-rich binaries via CLI flag.
  6. Produces three labeled datasets:
     - `03.10.10-backdoor`
     - `03.10.10-clean`
     - `03.10.08-clean`
  7. Moves final datasets into the `experiment_samples/` directory.

- `dropbear_samples/`  
  dropbear_samples/  
  ├─ stripped/  
  │  ├─ dropbear83-clean.stripped  
  │  ├─ dropbear86-clean.stripped  
  │  └─ dropbear86-backdoor.stripped  
  └─ symbols/dropbear86-clean  

  - `stripped/` contains firmware-realistic binaries with symbols removed.  
  - `symbols/` contains dropbear86-clean compiled with symbols (used as a reference for deriving function names that can be mapped to stripped binaries).

- `experiment_samples/` – Contains the final processed datasets after running the setup script.

---

## Dependencies

**Required Tools**
- `binwalk` (firmware unpacking)  
- `lzop` (decompression helper)  
- `rsync` (optional, faster copying)

**Install on Ubuntu/Debian**

    sudo apt-get update
    sudo apt-get install binwalk lzop squashfs-tools rsync
    pip install pandas requests

---

## Usage

### OpenWRT Dataset

    cd datasets/openwrt_data
    ./build_openwrt.sh

This will automatically download and unpack multiple OpenWRT versions for analysis.

---

### WAGO Dataset

Generate stripped firmware variants (default):

    cd datasets/wago_data
    ./setup_wago_data.sh

Explicitly use stripped binaries:

    ./setup_wago_data.sh --stripped

Use symbol-rich binaries:

    ./setup_wago_data.sh --symbols


After completion, `experiment_samples/` will contain:

    03.10.10-backdoor/
    03.10.10-clean/
    03.10.08-clean/

Each contains a fully unpacked firmware root filesystem with:

    usr/sbin/dropbear

replaced by the selected clean or backdoor sample.

---

## Example Mapping

| WAGO Firmware Version | Dropbear Sample (stripped)     | Dropbear Sample (symbols)     |
|-----------------------|---------------------------------|--------------------------------|
| 03.10.08 clean        | dropbear83-clean.stripped      | dropbear83-clean              |
| 03.10.10 clean        | dropbear86-clean.stripped      | dropbear86-clean              |
| 03.10.10 backdoor     | dropbear86-backdoor.stripped   | dropbear86-backdoor           |

---

## Source Attribution

- OpenWRT Firmware: [https://downloads.openwrt.org/](https://downloads.openwrt.org/)  
- WAGO PLC Firmware: [https://github.com/WAGO/pfc-firmware](https://github.com/WAGO/pfc-firmware)  

---
