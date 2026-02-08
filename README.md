# skillsync

## Shell Autocomplete

`skillsync` uses Swift ArgumentParser's built-in completion generation, which
includes every registered command and subcommand automatically.

Generate scripts:

```bash
skillsync --generate-completion-script bash > skillsync.bash
skillsync --generate-completion-script zsh > _skillsync
skillsync --generate-completion-script fish > skillsync.fish
```

Install for each shell:

```bash
# bash
mkdir -p ~/.local/share/bash-completion/completions
mv skillsync.bash ~/.local/share/bash-completion/completions/skillsync

# zsh
mkdir -p ~/.zsh/completions
mv _skillsync ~/.zsh/completions/_skillsync
grep -q 'fpath=(~/.zsh/completions $fpath)' ~/.zshrc || \
  echo 'fpath=(~/.zsh/completions $fpath)' >> ~/.zshrc
grep -q 'autoload -Uz compinit && compinit' ~/.zshrc || \
  echo 'autoload -Uz compinit && compinit' >> ~/.zshrc

# fish
mkdir -p ~/.config/fish/completions
mv skillsync.fish ~/.config/fish/completions/skillsync.fish
```

If installed from Homebrew using this repo's formula, completions for
`bash`/`zsh`/`fish` are installed automatically.
