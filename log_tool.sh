#!/bin/bash
.log() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: .log [options]"
        echo "--------------------------------------------------------"
        echo "  (no args)  Jump to today's log dir & show 5 newest valid logs"
        echo "  -t         Tail (-f) the newest valid log (>25k or <20k)"
        echo "  -c         Grep 'claudelogs' in the LATEST file > 26000 bytes"
        echo "  -h         Show this help menu"
        echo "--------------------------------------------------------"
        return 0
    fi

    local target="/opt/combinator-farm/01/logs/$(date +%Y%m%d)"
    if [ -d "$target" ]; then
        cd "$target"

        echo "Switched to: $target"

        # New -c logic: Latest file > 26000 bytes
        if [ "$1" == "-c" ]; then
            # 1. ls -lt sorts by time (newest first)
            # 2. awk skips the 'total' line, checks size ($5), and prints the first match ($9)
            local latest_big=$(ls -lt | awk 'NR > 1 && $5 > 26000 {print $9; exit}')
            
            if [ -n "$latest_big" ]; then
                echo "--- Grepping 'claudelogs' in Latest Valid Log: $latest_big ($(ls -lh $latest_big | awk '{print $5}')) ---"
                grep "claudelogs" "$latest_big"
            else
                echo "No logs found newer than 26000 bytes."
            fi
            return 0
        fi

        # ls -lt sorts by time
        # awk filters out lines where the 5th column (size) is 21466 or 21467
        #ls -lt | awk '$5 != 21979 && $5 != 21980 && $5 != 22120 && $5 != 22421' | head -n 5
	ls -lt | awk '$5 < 23000 || $5 > 26000' | head -n 5


	# The 't' part: if the first argument is -t, tail the newest valid log
        if [ "$1" == "-t" ]; then
            # We grab the filename ($9) of the first line that matches your size filter
            local newest=$(ls -lt | awk 'NR > 1 && ($5 < 20000 || $5 > 25000) {print $9; exit}')
            if [ -n "$newest" ]; then
                echo -e "\n--- Tailing: $newest ---"
                tail -f "$newest"
            fi
        fi
    else
        echo "Directory for today does not exist yet: $target"
    fi
}
