function fish_greeting                                            
    # do nothing
    fastfetch
end 

if status is-interactive
    starship init fish | source
end
set -gx STARSHIP_CONFIG ~/.config/starship/config.toml

# uv
fish_add_path "$HOME/.local/share/../bin"
