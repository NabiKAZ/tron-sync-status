#!/bin/bash
#
# status.sh — Live sync progress monitor for a local TRON full node.
#
# Compares the latest block number reported by your local node
# (http://127.0.0.1:8090) against the TronGrid public API, and prints
# a continuously updating, color-coded status line: how far behind
# you are, how fast you're syncing, and an ETA to catch up.
#
# Usage:
#   ./status.sh            # refresh every 10s (default)
#   ./status.sh 20         # refresh every 20s
#
# Requirements: bash, curl, jq, bc
#
# Author: NabiKAZ (https://github.com/NabiKAZ)
# Project: https://github.com/NabiKAZ/tron-sync-status

# ---- Parse refresh interval from CLI argument -----------------------------
if [[ -n "$1" ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]; then
        INTERVAL="$1"
    else
        echo "Invalid interval '$1', using default (10s)"
        INTERVAL=10
    fi
else
    INTERVAL=10
fi

# ---- Colors -----------------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
ETA_COLOR='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# Previous-iteration values, used to compute deltas / speed / ETA
PREV_LOCAL=""
PREV_NET=""
PREV_TIME=""
PREV_REMAIN=""

# Formats a signed integer delta as " (+N)", " (-N)", or " (0)" in gray.
fmt_delta() {
    local d=$1
    if [[ $d -gt 0 ]]; then
        echo -e "${GRAY} (+$d)${NC}"
    elif [[ $d -lt 0 ]]; then
        echo -e "${GRAY} ($d)${NC}"
    else
        echo -e "${GRAY} (0)${NC}"
    fi
}

# Converts a duration in seconds to a human-readable "Xh Ym Zs" string.
fmt_duration() {
    local total=$1
    local h=$((total / 3600))
    local m=$(((total % 3600) / 60))
    local s=$((total % 60))
    if [[ $h -gt 0 ]]; then
        printf "%dh %dm %ds" "$h" "$m" "$s"
    elif [[ $m -gt 0 ]]; then
        printf "%dm %ds" "$m" "$s"
    else
        printf "%ds" "$s"
    fi
}

while true; do

    # Fetch the latest block height from the local node
    LOCAL_RAW=$(curl -s --max-time 30 \
        -X POST http://127.0.0.1:8090/wallet/getnowblock)
    LOCAL=$(echo "$LOCAL_RAW" | jq -r \
        ".block_header.raw_data.number" 2>/dev/null)

    # Fetch the latest block height from the public network via JSON-RPC (returned as a hex string)
    NET_HEX=$(curl -s --max-time 30 \
        https://api.trongrid.io/jsonrpc \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result' 2>/dev/null)
    if [[ "$NET_HEX" =~ ^0x[0-9a-fA-F]+$ ]]; then
        NET=$((NET_HEX))
    else
        NET=""
    fi

    NOW_TS=$(date +%s)
    NOW_HUMAN=$(date "+%Y-%m-%d %H:%M:%S")

    # Bail out of this iteration if either response didn't contain a valid number
    if ! [[ "$LOCAL" =~ ^[0-9]+$ ]] || ! [[ "$NET" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}[$NOW_HUMAN] Error: Local='$LOCAL' Network='$NET_HEX'${NC}"
        sleep "$INTERVAL"
        continue
    fi

    REMAIN=$((NET - LOCAL))

    SPEED="N/A"
    ETA="N/A"
    if [[ -n "$PREV_LOCAL" && -n "$PREV_TIME" ]]; then
        DT=$((NOW_TS - PREV_TIME))
        DB=$((LOCAL - PREV_LOCAL))
        DR=$((REMAIN - PREV_REMAIN))
        if [[ $DT -gt 0 ]]; then
            # Local sync speed in blocks/second
            SPEED=$(printf "%.2f" "$(echo "scale=4; $DB/$DT" | bc)")

            # ETA is based on how fast the gap (Remain) itself is shrinking,
            # not just local speed — this accounts for the network also
            # producing new blocks while we sync.
            if [[ $DR -lt 0 ]]; then
                CLOSE_RATE=$((-DR))  # blocks the gap shrank by in DT seconds
                ETA_SEC=$(echo "$REMAIN * $DT / $CLOSE_RATE" | bc)
                if [[ "$ETA_SEC" =~ ^[0-9]+$ ]]; then
                    ETA=$(fmt_duration "$ETA_SEC")
                fi
            elif [[ $DR -eq 0 && $REMAIN -eq 0 ]]; then
                ETA="Synced"
            else
                ETA="Not closing"
            fi
        fi
    fi

    # Per-value deltas vs. the previous iteration (empty on first run)
    LOCAL_DELTA=""
    NET_DELTA=""
    REMAIN_DELTA=""
    if [[ -n "$PREV_LOCAL" ]]; then
        LOCAL_DELTA=$(fmt_delta $((LOCAL - PREV_LOCAL)))
        NET_DELTA=$(fmt_delta $((NET - PREV_NET)))
        REMAIN_DELTA=$(fmt_delta $((REMAIN - PREV_REMAIN)))
    fi

    # Color the Remain value by how far behind we are
    if [[ $REMAIN -le 5 ]]; then
        REMAIN_COLOR="${GREEN}${REMAIN}${NC}"
    elif [[ $REMAIN -le 100 ]]; then
        REMAIN_COLOR="${BLUE}${REMAIN}${NC}"
    else
        REMAIN_COLOR="${WHITE}${REMAIN}${NC}"
    fi

    echo -e \
"${CYAN}[$NOW_HUMAN]${NC} \
Local=${BOLD}$LOCAL${NC}${LOCAL_DELTA} \
Network=${BOLD}$NET${NC}${NET_DELTA} \
Remain=${REMAIN_COLOR}${REMAIN_DELTA} \
Speed=${YELLOW}${SPEED} blk/s${NC} \
ETA=${ETA_COLOR}${ETA}${NC}"

    PREV_LOCAL=$LOCAL
    PREV_NET=$NET
    PREV_TIME=$NOW_TS
    PREV_REMAIN=$REMAIN

    sleep "$INTERVAL"
done
