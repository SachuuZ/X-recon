# 📡 AutoReconX: Resilient Reconnaissance Script

AutoReconX automates the initial reconnaissance phase using multiple tools for asset discovery and optional vulnerability scanning. It features **dynamic tool path discovery** and an **interactive dependency check** for portability.

---

## 🛠 Dependencies (9 Tools)

The script checks for these mandatory tools:

- **Subdomains:** `subfinder`, `amass`, `assetfinder`
- **Liveness/Paths:** `httpx`, `waybackurls`, `gau`, `katana`
- **Scanning/IPs:** `nuclei` (optional), `shodan`

### Setup Commands

1. **Make executable:** 
   ```bash
   chmod +x rexon.sh
   ```

2. **Initialize Shodan:** 
   ```bash
   shodan init <API_KEY>
   ```

---

## 🚀 Usage

The target domain is a positional argument.

### Syntax

```bash
bash rexon.sh example.com [options]
# OR
./rexon.sh example.com [options]
```

### Flags

| Flag | Purpose |
|------|---------|
| `-n` | Runs ALL three Nuclei scans (Standard, DAST, IP) |
| `-f` | Forces execution, ignoring dependency prompts (non-interactive) |

### Examples

| Command | Action |
|---------|--------|
| `./rexon.sh target.com` | Fast Discovery (No Nuclei Scans) |
| `./rexon.sh target.com -n` | Full Scan (Discovery + 3 Nuclei Scans) |

---

## 📂 Output Structure

All results are saved in a directory named after the domain (`[domain]/`).

### Main Directory (`[domain]/`)

| File | Content |
|------|---------|
| `All-domains.txt` | Merged subdomains |
| `httpx.txt` | Live web host URLs |
| `shodan.txt` | Infrastructure IPs |
| `google-dorks.txt` | Google search links |
| `github-dorks.txt` | GitHub search links |

### Urls Directory (`[domain]/Urls/`)

| File | Content |
|------|---------|
| `all_path_urls.txt` | Master list of all unique paths (Input for DAST scan) |

### nuclei-Scan Directory (Only with `-n`)

| File | Based On |
|------|----------|
| `standard_nuclei_output.txt` | Live subdomains (`httpx.txt`) |
| `dast-result.txt` | Master path list (`all_path_urls.txt`) |
| `ip_nuclei_output.txt` | Infrastructure IPs (`shodan.txt`) |

---

### Gathering Info step-by-step can be such a drag so i've come up with this solution. If any major update or improvement to be done do reach out
