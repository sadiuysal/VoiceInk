
## Filesystem Context (optional, no OCR)
- Enable with defaults key `UseFilesystemContext = true`.
- VoiceInk builds a per-project dictionary from README/CLAUDE/manifests and top-level filenames.
- Optional: add a shell helper to publish cwd to `~/.voiceink/cwd` for better project detection:

```bash
# ~/.zshrc
autoload -U add-zsh-hook
_voiceink_publish_cwd() { printf "%s" "$PWD" > "$HOME/.voiceink/cwd"; }
add-zsh-hook precmd _voiceink_publish_cwd
```

Privacy: reads only allowlisted files; no network; stored locally in Application Support.

