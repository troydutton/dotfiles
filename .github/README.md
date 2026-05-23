# Dotfiles

My dotfiles.

# Setup

1. Create alias for managing the repository.
```bash
alias dot='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

2. Clone as a bare repository.
```bash
git clone --bare https://github.com/troydutton/dotfiles.git $HOME/.dotfiles
```

3. Hide untracked files.
```bash
dot --local status.showUntrackedFiles no
```

4. Checkout the files.
```bash
git checkout
```
