# My zsh configs

## Prerequisites

For proper functioning of mentioned below items please install the following using your system's package manager:

- zsh (or check if the version is not too far off)
- [ohmyzsh](https://ohmyz.sh/#install)
  - [zsh-nix-shell](https://github.com/chisui/zsh-nix-shell)
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md)
  - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md)
- [bat](https://github.com/sharkdp/bat?tab=readme-ov-file#installation)
- [fzf](https://github.com/junegunn/fzf)
- [fzf-git](https://github.com/junegunn/fzf-git.sh)
- [eza](https://github.com/eza-community/eza?tab=readme-ov-file#installation)
- [git-extras](https://github.com/tj/git-extras/blob/main/Installation.md)

## Custom theme: agnoster-mini

A compact variant of the [agnoster](https://github.com/ohmyzsh/ohmyzsh/wiki/Themes#agnoster) theme.

Changes from agnoster:
- No `user@host` segment
- Path shortened to last 2 directories (e.g. `apps/infra-central`)
- `$` / `#` suffix to distinguish normal user from root
- Removed unused segments (bzr, hg, terraform, AWS)
- Keeps git branch + dirty state, virtualenv/conda, status indicators

### Install

```bash
cp agnoster-mini.zsh-theme ~/.oh-my-zsh/custom/themes/
```

Then set in `~/.zshrc`:

```bash
ZSH_THEME="agnoster-mini"
```
