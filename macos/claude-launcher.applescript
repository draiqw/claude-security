on run
    set launcher to (POSIX path of (path to home folder)) & ".local/bin/claude-web"
    try
        do shell script quoted form of launcher
    on error errText
        display alert "Claude Web" message errText
    end try
end run
