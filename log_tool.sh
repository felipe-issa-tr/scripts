#!/bin/bash

# --- Helper: Find the latest file matching our size constraints ---
_get_latest_valid_log() {
    local filter="$1"
    ls -lt | awk "NR > 1 && ($filter) {print \$9; exit}"
}

# --- Helper: Maintenance (Cleanup) ---
_log_clear() {
    local base_dir="/opt/combinator-farm/01/logs"
    local threshold=$(date -d "7 days ago" +%Y%m%d)

    echo "Scanning for logs older than 7 days (Before $threshold)..."
    local to_delete=()
    for dir in "$base_dir"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]; do
        [ -d "$dir" ] || continue
        [[ "$(basename "$dir")" < "$threshold" ]] && to_delete+=("$dir")
    done

    if [ ${#to_delete[@]} -eq 0 ]; then
        echo "Nothing to delete."
        return 0
    fi

    printf '%s\n' "${to_delete[@]}"
    read -p "Delete these ${#to_delete[@]} directories? (y/N): " confirm
    [[ "$confirm" == [yY] ]] && for dir in "${to_delete[@]}"; do rm -rf "$dir" && echo "Deleted $dir"; done
}

# --- Helper: Display the Help Menu ---
_log_help() {
    echo "Usage: .log [options]"
    echo "------------------------------------------------------------"
    echo "  (no args)  Show 5 newest valid logs"
    echo "  -t         Tail (-f) the newest valid log"
    echo "  -t -c      Tail AND filter for relevant keywords"
    echo "  -c         Grep 'claudelogs' in the LATEST finished log"
    echo "  --clear    Delete log folders older than 7 days"
    echo "  -h         Show this help menu"
    echo "------------------------------------------------------------"
}

# --- Main Entry Point ---
.log() {
    # --- CONFIGURATION (Constants) ---
    local MIN_SIZE=20000
    local MAX_SIZE=26000
    local SEARCH_PATTERN="claudelogs|Processing custom action"
    # ---------------------------------

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        _log_help
        return 0
    fi

    if [[ "$1" == "--clear" ]]; then
        _log_clear
        return 0
    fi

    local target="/opt/combinator-farm/01/logs/$(date +%Y%m%d)"
    if [ ! -d "$target" ]; then
        echo "No logs for today yet."
        return 1
    fi

    cd "$target"

    # Filter: Files are valid if they are smaller than 20k or larger than 26k
    local valid_filter="\$5 < $MIN_SIZE || \$5 > $MAX_SIZE"

    case "$1" in
        -c)
            # Use the MAX_SIZE as the threshold for "Big" files
            local file=$(_get_latest_valid_log "\$5 > $MAX_SIZE")
            if [ -n "$file" ]; then
                echo "--- Grepping 'claudelogs' in: $file ---"
                grep "claudelogs" "$file"
            fi
            ;;
        -t)
            local file=$(_get_latest_valid_log "$valid_filter")
            if [ -n "$file" ]; then
                if [[ "$2" == "-c" ]]; then
                    echo "--- Tailing & Filtering: $file ---"
                    echo "--- Applied Filters: $SEARCH_PATTERN ---"
		    tail -f "$file" | grep --line-buffered -E "$SEARCH_PATTERN"
                else
                    echo "--- Tailing: $file ---"
                    tail -f "$file"
                fi
            fi
            ;;
        *)
            echo "--- 5 Most Recent Valid Logs (Skipping $MIN_SIZE to $MAX_SIZE bytes) ---"
            ls -lt | awk "\$5 < $MIN_SIZE || \$5 > $MAX_SIZE" | head -n 6
            ;;
    esac
}
