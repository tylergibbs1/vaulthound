import ArgumentParser

struct HookCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hook",
        abstract: "Print a shell hook that auto-loads environment variables on directory change"
    )

    @Argument(help: "Shell to generate the hook for (zsh, bash, or fish)")
    var shell: Shell

    enum Shell: String, ExpressibleByArgument, CaseIterable {
        case zsh
        case bash
        case fish
    }

    func run() throws {
        switch shell {
        case .zsh:  print(zshHook)
        case .bash: print(bashHook)
        case .fish: print(fishHook)
        }
    }
}

// MARK: - Shell hook scripts

extension HookCommand {
    private var zshHook: String {
        """
        _vaulthound_hook() {
          local env_output
          if [[ -d .vaulthound ]] || [[ -f .env ]] || [[ -d .git ]]; then
            env_output=$(vaulthound env --project "$PWD" --export 2>/dev/null)
            if [[ $? -eq 0 ]] && [[ -n "$env_output" ]]; then
              eval "$env_output"
            fi
          fi
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook chpwd _vaulthound_hook
        _vaulthound_hook
        """
    }

    private var bashHook: String {
        """
        _vaulthound_hook() {
          local env_output
          if [[ -d .vaulthound ]] || [[ -f .env ]] || [[ -d .git ]]; then
            env_output=$(vaulthound env --project "$PWD" --export 2>/dev/null)
            if [[ $? -eq 0 ]] && [[ -n "$env_output" ]]; then
              eval "$env_output"
            fi
          fi
        }
        if [[ -z "$_VAULTHOUND_ORIGINAL_PROMPT_COMMAND" ]]; then
          _VAULTHOUND_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
        fi
        PROMPT_COMMAND="_vaulthound_hook${_VAULTHOUND_ORIGINAL_PROMPT_COMMAND:+;$_VAULTHOUND_ORIGINAL_PROMPT_COMMAND}"
        _vaulthound_hook
        """
    }

    private var fishHook: String {
        """
        function _vaulthound_hook --on-variable PWD
          if test -d .vaulthound; or test -f .env; or test -d .git
            set -l env_output (vaulthound env --project "$PWD" --export 2>/dev/null)
            if test $status -eq 0; and test -n "$env_output"
              eval "$env_output"
            end
          end
        end
        _vaulthound_hook
        """
    }
}
