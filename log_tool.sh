#!/bin/bash

# --- Helper: Find the latest file matching our size constraints ---
# Usage: _get_latest_valid_log "size_filter_string"
_get_latest_valid_log() {
    local filter="$1"
    # ls -lt sorts by time; awk applies the filter and returns the 9th column (filename)
    ls -lt | awk "NR > 1 && ($filter) {print \$9; exit}"
}

# --- Helper: Display the Help Menu ---
_log_help() {
    echo "Usage: .log [options]"
    echo "------------------------------------------------------------"
    echo "  (no args)  Jump to today's log dir & show 5 newest valid logs"
    echo "  -t         Tail (-f) the newest valid log (>25k or <20k)"
    echo "  -c         Grep 'claudelogs' in the LATEST file > 26k"
    echo "  -h         Show this help menu"
    echo "------------------------------------------------------------"
}

# --- Main Entry Point ---
.log() {
    # 1. Check for help flag first
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _log_help
        return 0
    fi

    local target="/opt/combinator-farm/01/logs/$(date +%Y%m%d)"
    
    # 2. Directory Validation
    if [ ! -d "$target" ]; then
        echo "Directory for today does not exist yet: $target"
        return 1
    fi

    cd "$target"
    echo "Switched to: $target"

    # 3. Handle specific flags
    case "$1" in
        -c)
            # Logic: Latest file > 26000
            local file=$(_get_latest_valid_log "\$5 > 26000")
            if [ -n "$file" ]; then
                echo "--- Grepping 'claudelogs' in: $file ($(ls -lh "$file" | awk '{print $5}')) ---"
                grep "claudelogs" "$file"
            else
                echo "No logs found > 26000 bytes."
            fi
            ;;
            
        -t)
            # Logic: Newest within your specific ranges
            local file=$(_get_latest_valid_log "\$5 < 20000 || \$5 > 25000")
            if [ -n "$file" ]; then
                echo -e "\n--- Tailing: $file ---"
                tail -f "$file"
            fi
            ;;

        *)
            # Default behavior (no args or unknown args)
            echo "--- 5 Most Recent Valid Logs (Skipping useless files) ---"
            ls -lt | awk '$5 < 20000 || $5 > 25000' | head -n 5
            ;;
    esac
}
