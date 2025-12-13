#------------------------------------------------------------------------------
# macOS-specific helpers sourced by .bash_profile when IS_MAC=true
#------------------------------------------------------------------------------

# shellcheck shell=bash

[[ "${IS_MAC:-false}" == "true" ]] || return 0

gosu() {
    if ! has_cmd osascript; then
        echo "osascript is required for gosu." >&2
        return 1
    fi
    /usr/bin/osascript <<'EOT'
tell application "Terminal"
    set newTab to do script "sudo -s"
    set theWindow to first window of (every window whose tabs contains newTab)
    repeat with i from 1 to (count of theWindow's tabs)
        if (item i of theWindow's tabs) is newTab then set tabNumber to i
    end repeat
    set current settings of newTab to settings set "Red Sands"
end tell
EOT
}

cdf() {
    if ! has_cmd osascript; then
        echo "osascript is required for cdf." >&2
        return 1
    fi
    local currFolderPath
    currFolderPath=$(/usr/bin/osascript <<'EOT'
tell application "Finder"
    try
        set currFolder to (folder of the front window as alias)
    on error
        set currFolder to (path to desktop folder as alias)
    end try
    POSIX path of currFolder
end tell
EOT
)
    echo "cd to \"$currFolderPath\""
    cd "$currFolderPath" || return
}
