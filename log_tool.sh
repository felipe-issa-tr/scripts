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

# --- Helper: The Tail Watchdog ---
_log_tail() {
    local filter_mode="$1"  # This will be "-c" or empty
    local pattern="claudelogs|Processing custom action"
    local limit=60
    
    # Always tail the absolute latest file
    local file=$(ls -t | head -n 1)

    if [ -z "$file" ]; then
        echo "No log files found in this directory."
        return 1
    fi

    if [[ "$filter_mode" == "-c" ]]; then
        echo "--- Tailing & Filtering: $file ---"
        echo "--- Applied Filters: $pattern ---"
        { tail -f "$file" | grep --line-buffered -E "$pattern" & } 2>/dev/null
    else
        echo "--- Tailing: $file ---"
        { tail -f "$file" & } 2>/dev/null
    fi
    
    local tail_pid=$!
    disown $tail_pid 
    echo "--- Watchdog: Closing after ${limit}s of silence ---"

    while true; do
        local start_time=$(stat -c %Y "$file")
        sleep "$limit"
        local end_time=$(stat -c %Y "$file")

        if [ "$start_time" -eq "$end_time" ]; then
            echo -e "\n--- No updates for ${limit}s. Ending session. ---"
            kill "$tail_pid" 2>/dev/null
            break
        fi
    done
}


# --- Helper: Display the Help Menu ---
_log_help() {
    echo "Usage: .log [options]"
    echo "------------------------------------------------------------"
    echo "  (no args)  Show 5 newest valid logs"
    echo "  -t         Tail (-f) the newest valid log"
    echo "  -t -c      Tail AND filter for relevant keywords"
    echo "  -c         Grep 'claudelogs' in the LATEST finished log"
    echo "  -v         Open the LATEST finished log (>$MAX_SIZE) in VI"
    echo "  --clear    Delete log folders older than 7 days"
    echo "  -h         Show this help menu"
    echo "------------------------------------------------------------"
}

# --- Main Entry Point ---
.log() {
    # --- CONFIGURATION (Constants) ---
    local MIN_SIZE=24000
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
            # Call the helper function
            _log_tail "$2" "$SEARCH_PATTERN" "$INACTIVITY_LIMIT"
            ;;

	-v)
            # Find the latest file specifically larger than 26k
            local file=$(_get_latest_valid_log "\$5 > $MAX_SIZE")
            if [ -n "$file" ]; then
                echo "--- Opening in VI: $file ---"
                vi "$file"
            else
                echo "No finished logs (>$MAX_SIZE bytes) found."
            fi
            ;;
        *)
            echo "--- 5 Most Recent Valid Logs (Skipping $MIN_SIZE to $MAX_SIZE bytes) ---"
            ls -lt | awk "\$5 < $MIN_SIZE || \$5 > $MAX_SIZE" | head -n 6
            ;;
    esac
}
