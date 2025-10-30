#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# --- Configuration ---
# List of mandatory tools 
MANDATORY_TOOLS=(subfinder amass assetfinder httpx waybackurls gau nuclei shodan katana)
GITHUB_URL="Highly recommend to continue the process after installation of these tools" 

GO_BIN_PATH="$HOME/go/bin"

SUBFINDER_CMD="$GO_BIN_PATH/subfinder"
HTTPX_CMD="$GO_BIN_PATH/httpx"
GAU_CMD="$GO_BIN_PATH/gau"
KATANA_CMD="$GO_BIN_PATH/katana"
NUCLEI_CMD="$GO_BIN_PATH/nuclei"
AMASS_CMD="amass"        # Keep flexible
ASSETFINDER_CMD="assetfinder" # Keep flexible
WAYBACKURLS_CMD="waybackurls" # Keep flexible
SHODAN_CMD="shodan"      # Keep flexible


RUN_NUCLEI=0
FORCE_CONTINUE=0
MISSING_TOOLS=()
TOOLS_TO_SKIP=()

# Function to display usage
usage() {
  echo -e "${GREEN}Usage Examples:${NC}"
  # Updated examples
  echo "   bash $0 example.com"
  echo "       -- OR --"
  echo "  ./$0 example.com"
  echo ""
  echo -e "${GREEN}Options:${NC}"
  echo "  <domain>: The target domain (e.g., example.com)"
  echo "  -n      : To run ALL three Nuclei scans (Standard, DAST, and IP). Results are saved in the nuclei-Scan directory."
  echo "  -f      : Use --force flag. Force execution even if mandatory tools are missing, skipping missing parts without asking."
  exit 1
}

check_tool() {
    local tool_name="$1"
    local tool_path_var_name="${tool_name^^}_CMD" # e.g., HTTPX_CMD
    local tool_cmd="${!tool_path_var_name}"
    
    local found_path=""
    if [ -x "$tool_cmd" ]; then
        found_path="$tool_cmd"
    fi
    
    if [ -z "$found_path" ]; then
        found_path=$(command -v "$tool_name" 2>/dev/null)
    fi

    if [ -n "$found_path" ] && [ -x "$found_path" ]; then

        declare -g "$tool_path_var_name"="$found_path"
        return 0 # Tool found and path updated
    fi
    
    return 1 # Tool not found
}

# Core function to handle missing tools
handle_missing_tools() {
    echo -e "${YELLOW}--- Dependency Check ---${NC}"
    
    # 1. Identify missing tools
    local tools_to_check=("subfinder" "httpx" "gau" "katana" "nuclei" "amass" "assetfinder" "waybackurls" "shodan")
    
    for tool in "${tools_to_check[@]}"; do
        if ! check_tool "$tool"; then
            MISSING_TOOLS+=("$tool")
        fi
    done

    # If no tools are missing, exit gracefully
    if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
        echo -e "${GREEN}[+] All required tools found.${NC}"
        return
    fi
    
    echo -e "${RED}[!] WARNING: The following required tools are missing:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo -e "    - ${RED}$tool${NC}"
    done

    # 2. Check for --force flag
    if [ "$FORCE_CONTINUE" -eq 1 ]; then
        echo -e "${YELLOW}[!] --force flag detected. Skipping missing tools and continuing...${NC}"
        TOOLS_TO_SKIP=("${MISSING_TOOLS[@]}")
        return
    fi

    # 3. Interactive Prompt
    echo ""
    read -r -p "Do you want to continue the process, neglecting the missing tools? (y/n): " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${YELLOW}[!] Continuing without missing tools. Output files may be empty or incomplete.${NC}"
        TOOLS_TO_SKIP=("${MISSING_TOOLS[@]}")
    else
        echo -e "${RED}[!] Execution aborted. Please install the missing tools.${NC}"
        echo -e "${YELLOW}Reference: $GITHUB_URL${NC}"
        exit 1
    fi
}

# Check if a tool should be skipped
should_skip() {
    local tool_name="$1"
    for skip_tool in "${TOOLS_TO_SKIP[@]}"; do
        if [ "$tool_name" == "$skip_tool" ]; then
            return 0 # True (skip the tool)
        fi
    done
    return 1 # False (run the tool)
}

while getopts ":nf" opt; do
  case $opt in
    n)
      RUN_NUCLEI=1
      ;;
    f)

      FORCE_CONTINUE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

shift $((OPTIND - 1))
DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
  usage
fi

# RUN DEPENDENCY CHECK HERE
handle_missing_tools

# --- Setup Directories ---
BASE_NAME="${DOMAIN%.*}"
OUTPUT_DIR="${BASE_NAME}"
mkdir -p "$OUTPUT_DIR"

ALL_DOMAINS_FILE="$OUTPUT_DIR/All-domains.txt"
TEMP_SUBFINDER="$OUTPUT_DIR/subfinder.tmp"
TEMP_AMASS="$OUTPUT_DIR/amass.tmp"
TEMP_ASSETFINDER="$OUTPUT_DIR/assetfinder.tmp"

URLS_DIR="$OUTPUT_DIR/Urls"
mkdir -p "$URLS_DIR"
WAYBACK_LIVE_FILE="$URLS_DIR/wayback_urls.txt"
GAU_LIVE_FILE="$URLS_DIR/gau_urls.txt"
KATANA_LIVE_FILE="$URLS_DIR/katana_urls.txt"
ALL_PATH_URLS_FILE="$URLS_DIR/all_path_urls.txt"

NUCLEI_DIR="$OUTPUT_DIR/nuclei-Scan"

echo -e "${GREEN}[+] Target: $DOMAIN${NC}"

# --- Step 1: Subdomain Enumeration ---
echo -e "${GREEN}[+] Starting Subdomain Enumeration...${NC}"

# Run Subfinder
if ! should_skip subfinder; then
    echo -e "${GREEN}[+] Running Subfinder... (concurrently)${NC}"
    "$SUBFINDER_CMD" -d "$DOMAIN" -o "$TEMP_SUBFINDER" 2>/dev/null &
    PID_SUBFINDER=$!
else
    echo -e "${YELLOW}[!] Skipping Subfinder.${NC}"
    PID_SUBFINDER=-1 # Placeholder PID
fi

# Run AssetFinder
if ! should_skip assetfinder; then
    echo -e "${GREEN}[+] Running AssetFinder... (concurrently)${NC}"
    "$ASSETFINDER_CMD" --subs-only "$DOMAIN" > "$TEMP_ASSETFINDER" &
    PID_ASSETFINDER=$!
else
    echo -e "${YELLOW}[!] Skipping AssetFinder.${NC}"
    PID_ASSETFINDER=-1 # Placeholder PID
fi

# Run Amass
if ! should_skip amass; then
    echo -e "${GREEN}[+] Running Amass (passive mode)... (concurrently)${NC}"
    "$AMASS_CMD" enum -d "$DOMAIN" -passive -o "$TEMP_AMASS" 2>/dev/null &
    PID_AMASS=$!
else
    echo -e "${YELLOW}[!] Skipping Amass.${NC}"
    PID_AMASS=-1 # Placeholder PID
fi

# Wait only for running processes
echo -e "${GREEN}[+] Waiting for active subdomain enumeration tools to complete...${NC}"
for pid in $PID_SUBFINDER $PID_ASSETFINDER $PID_AMASS; do
    if [ "$pid" -ne -1 ]; then
        wait "$pid"
    fi
done

# Combine, Sort, and Deduplicate
echo -e "${GREEN}[+] Combining and de-duplicating subdomains into $ALL_DOMAINS_FILE...${NC}"
find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.tmp" -exec cat {} + 2>/dev/null | sort -u > "$ALL_DOMAINS_FILE"

echo -e "${GREEN}[+] Cleaning up independent subdomain lists...${NC}"
rm -f "$TEMP_SUBFINDER" "$TEMP_AMASS" "$TEMP_ASSETFINDER"

DOMAIN_COUNT=$(wc -l < "$ALL_DOMAINS_FILE" 2>/dev/null || echo 0)
echo -e "${GREEN}[+] Found $DOMAIN_COUNT unique subdomains.${NC}"


# --- Step 2: Liveness Probing (Active Subdomains) ---
if ! should_skip httpx && [ "$DOMAIN_COUNT" -gt 0 ]; then
    echo -e "${GREEN}[+] Running HTTPX on active subdomains...${NC}"
    cat "$ALL_DOMAINS_FILE" | "$HTTPX_CMD" -silent -title -content-length | tee "$OUTPUT_DIR/httpx.txt"
else
    echo -e "${YELLOW}[!] Skipping HTTPX (Tool missing or no domains found).${NC}"
    # Create an empty file if it was skipped due to missing tool, to prevent later errors
    touch "$OUTPUT_DIR/httpx.txt"
fi

# --- Step 3: Active Crawling with Katana ---
if ! should_skip katana && [ -s "$OUTPUT_DIR/httpx.txt" ]; then
    echo -e "${GREEN}[+] Running Katana (Active Crawler) on live hosts...${NC}"
    # Katana crawls the live root hosts found by httpx to find internal links
    "$KATANA_CMD" -list "$OUTPUT_DIR/httpx.txt" -silent -depth 3 -c 50 | sort -u > "$KATANA_LIVE_FILE"
    echo -e "${GREEN}[+] Live Katana URLs saved to $KATANA_LIVE_FILE${NC}"
else
    echo -e "${YELLOW}[!] Skipping Katana (Tool missing or no live hosts found).${NC}"
    touch "$KATANA_LIVE_FILE"
fi


# --- Step 4: Nuclei Scan (Standard) - CONDITIONAL on -n and Tool Presence ---
if [ "$RUN_NUCLEI" -eq 1 ]; then
    if ! should_skip nuclei; then
        echo -e "${GREEN}[+] Creating nuclei-Scan directory and running Nuclei (standard scan)...${NC}"
        mkdir -p "$NUCLEI_DIR"
        # Uses the host list from httpx
        "$NUCLEI_CMD" -l "$OUTPUT_DIR/httpx.txt" -o "$NUCLEI_DIR/standard_nuclei_output.txt"
    else
        echo -e "${YELLOW}[!] Skipping standard Nuclei scan: Nuclei tool is missing.${NC}"
    fi
else
    echo -e "${GREEN}[!] Skipping standard Nuclei scan (Step 4). Use the -n flag to enable ALL Nuclei scans.${NC}"
fi


# -------------------------------------------------------------------
# --- Step 5 & 6: Historical URL Discovery and Liveness Check ---
# -------------------------------------------------------------------
echo -e "${GREEN}[+] Starting historical URL discovery in $URLS_DIR...${NC}"

# --- Step 5: Wayback URLs (Conditional) ---
if ! should_skip waybackurls && ! should_skip httpx; then
    echo -e "${GREEN}[+] Fetching Wayback URLs and checking liveness...${NC}"
    # Note: Using the dynamically resolved command path
    "$WAYBACKURLS_CMD" "$DOMAIN" | "$HTTPX_CMD" -silent | tee "$WAYBACK_LIVE_FILE"
    echo -e "${GREEN}[+] Live Wayback URLs saved to $WAYBACK_LIVE_FILE${NC}"
else
    echo -e "${YELLOW}[!] Skipping Wayback URLs (waybackurls or httpx missing).${NC}"
    touch "$WAYBACK_LIVE_FILE"
fi

# --- Step 6: Gau URLs (Conditional) ---
if ! should_skip gau && ! should_skip httpx; then
    echo -e "${GREEN}[+] Fetching Gau URLs and checking liveness...${NC}"
    # Note: Using the dynamically resolved command path
    "$GAU_CMD" "$DOMAIN" | "$HTTPX_CMD" -silent | tee "$GAU_LIVE_FILE"
    echo -e "${GREEN}[+] Live Gau URLs saved to $GAU_LIVE_FILE${NC}"
else
    echo -e "${YELLOW}[!] Skipping Gau URLs (gau or httpx missing).${NC}"
    touch "$GAU_LIVE_FILE"
fi


# --- Step 7: Nuclei DAST on ALL Paths (Historical + Katana) (CONDITIONAL) ---
echo -e "${GREEN}[+] Combining ALL URL paths for DAST scan (Historical + Katana)...${NC}"
# Combine historical (Wayback/Gau) AND current crawl (Katana) paths
cat "$WAYBACK_LIVE_FILE" "$GAU_LIVE_FILE" "$KATANA_LIVE_FILE" | sort -u > "$ALL_PATH_URLS_FILE"

if [ "$RUN_NUCLEI" -eq 1 ]; then
    if ! should_skip nuclei; then
        echo -e "${GREEN}[+] Running Nuclei DAST on Combined Paths list...${NC}"
        mkdir -p "$NUCLEI_DIR" # Ensure directory exists if it wasn't made in Step 4
        # Output stored in the new directory
        # WARNING: Update the hardcoded DAST template path for your own system!
        "$NUCLEI_CMD" -l "$ALL_PATH_URLS_FILE" -dast -t /Users/cyborg/BugBounty/Tools/fuzzing-templates/ -o "$NUCLEI_DIR/dast-result.txt"
    else
        echo -e "${YELLOW}[!] Skipping Nuclei DAST scan: Nuclei tool is missing.${NC}"
    fi
else
    echo -e "${GREEN}[!] Skipping Nuclei DAST scan (Step 7). Use the -n flag to enable ALL Nuclei scans.${NC}"
fi


# --- Step 8: Shodan Search (Conditional) ---
if ! should_skip shodan; then
    echo -e "${GREEN}[+] Searching Shodan for domain IPs...${NC}"
    "$SHODAN_CMD" search "ssl:'$DOMAIN'" --fields ip_str --limit 1000 > "$OUTPUT_DIR/shodan.txt"
else
    echo -e "${YELLOW}[!] Skipping Shodan Search (Tool missing).${NC}"
    touch "$OUTPUT_DIR/shodan.txt"
fi


# --- Step 9: Nuclei Scan (IPs) (CONDITIONAL) ---
if [ "$RUN_NUCLEI" -eq 1 ]; then
    if ! should_skip nuclei; then
        echo -e "${GREEN}[+] Running Nuclei on Shodan IPs...${NC}"
        mkdir -p "$NUCLEI_DIR"
        "$NUCLEI_CMD" -l "$OUTPUT_DIR/shodan.txt" -o "$NUCLEI_DIR/ip_nuclei_output.txt"
    else
        echo -e "${YELLOW}[!] Skipping Nuclei IP scan: Nuclei tool is missing.${NC}"
    fi
else
    echo -e "${GREEN}[!] Skipping Nuclei IP scan (Step 9). Use the -n flag to enable ALL Nuclei scans.${NC}"
fi


# --- Step 10: Google Dorking Links ---
echo -e "${GREEN}[+] Google Dorking Links:${NC}"
GOOGLE_DORKS="$OUTPUT_DIR/google-dorks.txt"
echo "https://www.google.com/search?q=site:$DOMAIN+ext:env+OR+ext:log+OR+ext:bak+OR+ext:sql" > "$GOOGLE_DORKS"
echo "https://www.google.com/search?q=site:$DOMAIN+inurl:admin+OR+inurl:login" >> "$GOOGLE_DORKS"
echo "https://www.google.com/search?q=site:$DOMAIN+intitle:index.of" >> "$GOOGLE_DORKS"
cat "$GOOGLE_DORKS"

# --- Step 11: GitHub Dorking Links ---
echo -e "${GREEN}[+] GitHub Dorking Links:${NC}"
GITHUB_DORKS="$OUTPUT_DIR/github-dorks.txt"
echo "https://github.com/search?q=$DOMAIN" > "$GITHUB_DORKS"
echo "https://github.com/search?q=$DOMAIN+password" >> "$GITHUB_DORKS"
echo "https://github.com/search?q=$DOMAIN+secret" >> "$GITHUB_DORKS"
echo "https://github.com/search?q=$DOMAIN+api_key" >> "$GITHUB_DORKS"
cat "$GITHUB_DORKS"

echo -e "${GREEN}[+] Recon complete! All results in: $OUTPUT_DIR${NC}"
