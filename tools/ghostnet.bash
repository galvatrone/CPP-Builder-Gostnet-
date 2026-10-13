_ghostnet_complete() {
    local current="${COMP_WORDS[COMP_CWORD]}" previous="${COMP_WORDS[COMP_CWORD-1]}" words
    case "$previous" in
        --target) words='native linux windows macos both' ;;
        --mode) words='auto files project cmake make cargo python go node dotnet maven gradle swift zig' ;;
        --type) words='c cpp cmake rust python go java javascript typescript csharp bash ruby php lua swift kotlin dart zig' ;;
        completion) words='bash zsh powershell' ;;
        auto-update) words='enable disable status' ;;
        *) words='build run test doctor setup watch clean check inspect languages init recent update auto-update completion --help --version --target --mode --type --run-file --run --yes --no-animation' ;;
    esac
    COMPREPLY=()
    mapfile -t COMPREPLY < <(compgen -W "$words" -- "$current")
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        mapfile -t COMPREPLY < <(compgen -f -- "$current")
    fi
}
complete -o filenames -F _ghostnet_complete ghostnet ghostnet-ru
