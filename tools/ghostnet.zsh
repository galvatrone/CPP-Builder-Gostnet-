#compdef ghostnet ghostnet-ru
_ghostnet() {
    local -a commands
    commands=(build run test doctor setup watch clean check inspect languages init recent update auto-update completion)
    _arguments -C \
      '--target[Build target]:target:(native linux windows macos both)' \
      '--mode[Project engine]:mode:(auto files project cmake make cargo python go node dotnet maven gradle swift zig)' \
      '--type[Template language]:type:(c cpp cmake rust python go java javascript typescript csharp bash ruby php lua swift kotlin dart zig)' \
      '--run-file[Project entry]:file:_files' '--run[Run after building]' '--yes[Install without confirmation]' \
      '--no-animation[Disable animations]' '--help[Show help]' '--version[Show version]' \
      '1:command:($commands)' '*:project folder:_files -/'
}
compdef _ghostnet ghostnet ghostnet-ru
