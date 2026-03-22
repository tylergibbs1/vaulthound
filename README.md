# Vaulthound

**The environment layer for macOS developers.**

Vaulthound sits between your projects and your tools, always knowing which environment you're in and making sure the right variables reach the right processes. It manages `.env` files, stores secrets in Keychain with Touch ID, injects variables into any process, and has a built-in API client — all in a native SwiftUI app.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Why

Every developer on macOS has the same invisible mess: `.env` files scattered across 20 projects, API keys copy-pasted from Slack, secrets hardcoded in `.zshrc`, and no single place that answers "what is my local environment right now?"

No tool owns the `.env` file. Doppler and Infisical are cloud dashboards. direnv is a shell hook with no UI. 1Password CLI stores secrets but doesn't understand projects. Yaak and Bruno are API clients that encrypt secrets for their own use but don't manage your broader environment.

Vaulthound is the missing layer.

## Features

### Environment Management
- **Filesystem-aware** — auto-detects projects and `.env` files when you add a directory
- **Multi-environment** — local, staging, production side-by-side with one-click switching
- **Secret storage** — Keychain-backed per-variable encryption with Touch ID reveal
- **Environment diffing** — compare staging vs production before deploys (⌘⇧D)
- **`.env` import/export** — drag and drop `.env` files from Finder, or use the file picker
- **Secret detection** — auto-identifies API keys for OpenAI, Anthropic, Stripe, AWS, GitHub, and 10+ other providers

### Shell Injection
- **CLI companion** — `vaulthound exec -- npm start` injects the right env vars into any process
- **Shell hook** — `eval "$(vaulthound hook zsh)"` auto-loads variables when you `cd` into a project (like direnv but with Keychain secrets and a GUI)
- **Any terminal, any IDE** — works everywhere, not locked to one tool

### API Client
- **REST client** — GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
- **Variable interpolation** — `{{BASE_URL}}/api/users/{{USER_ID}}` resolves from active environment
- **Response viewer** — syntax-highlighted JSON/XML, headers tab, timing breakdown
- **Import** — Postman (v2.1 JSON), cURL commands
- **Export** — cURL, Swift URLSession, Python requests
- **Cookie jar** — per-domain cookie persistence
- **Response history** — last 50 responses per request

### Route Discovery
- **Auto-detects API routes** from framework file conventions when you add a project
- **Next.js** — App Router (`app/**/route.ts`) and Pages Router (`pages/api/**/*.ts`)
- **SvelteKit** — `src/routes/**/+server.ts`
- **Nuxt** — `server/api/**/*.ts` with method-specific filenames
- Converts `[id]` segments to `{{id}}` template variables automatically

### Menu Bar Companion
- Always-visible environment status without opening the main window
- Quick-switch environments, copy variables to clipboard
- Status indicators: green = all secrets filled, yellow = missing secrets

### Native macOS
- **SwiftUI** — three-column NavigationSplitView, system materials, SF Symbols
- **Keyboard shortcuts** — ⌘N, ⌘⇧N, ⌘⏎, ⌘E, ⌘⇧D, ⌘1/⌘2 for mode switching
- **Accessibility** — VoiceOver labels on every control, focus management, keyboard navigation
- **Dark mode** — respects system appearance, accent color, Dynamic Type
- **Menu bar** — native `MenuBarExtra` with quick copy

## Architecture

```
┌──────────────────────────────────────────────────┐
│ macOS                                            │
│  ┌─────────────┐  ┌──────────────────────────┐   │
│  │ Menu Bar UI │  │ Main Window (SwiftUI)    │   │
│  └──────┬──────┘  └────────────┬─────────────┘   │
│         └───────────┬──────────┘                 │
│                     │ XPC                        │
│              ┌──────┴──────┐                     │
│              │   Daemon    │                     │
│              │  - FSEvents │                     │
│              │  - Env Index│                     │
│              │  - Keychain │                     │
│              │  - Socket   │                     │
│              └──────┬──────┘                     │
│                     │ Unix Socket                │
│         ┌───────────┼───────────┐                │
│    ┌────┴────┐ ┌────┴────┐ ┌───┴─────┐          │
│    │  CLI    │ │  Shell  │ │   IDE   │          │
│    │  exec   │ │  Hook   │ │  .env   │          │
│    └─────────┘ └─────────┘ └─────────┘          │
└──────────────────────────────────────────────────┘
```

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (macOS 14+) |
| Navigation | Three-column NavigationSplitView |
| Data | SwiftData |
| Secrets | Security framework (Keychain) + LocalAuthentication (Touch ID) |
| Networking | Foundation URLSession |
| CLI | Swift Argument Parser |
| File watching | FSEvents via XPC daemon |
| Menu bar | MenuBarExtra (.window style) |

## Getting Started

### Prerequisites

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build

```bash
git clone https://github.com/tylergibbs/vaulthound.git
cd vaulthound
xcodegen generate
open Vaulthound.xcodeproj
```

Build and run the **Vaulthound** scheme (⌘R).

On first launch, sample projects ("acme-web" and "weather-app") are seeded with realistic environments, variables, and API requests so you can explore the app immediately.

### CLI

Build the **vaulthound-cli** scheme, then:

```bash
# Inject environment into a command
vaulthound exec --project ~/Developer/myapp --env staging -- npm start

# Auto-detect project from current directory
vaulthound exec -- python main.py

# List detected projects
vaulthound list

# Print environment variables
vaulthound env --project ~/Developer/myapp --export

# Generate shell hook
eval "$(vaulthound hook zsh)"   # or bash, fish
```

## Project Structure

```
vaulthound/
├── project.yml                    # XcodeGen spec
├── VaulthoundApp/                 # Main macOS app (SwiftUI)
│   ├── Scenes/                    # MainWindow, Settings, StatusBar
│   ├── Sidebar/                   # Project browser, collection tree
│   ├── Environment/               # Variable editor, detail view, diff
│   ├── APIClient/                 # Request builder, response viewer
│   ├── MenuBar/                   # Menu bar companion views
│   ├── Import/                    # Postman, cURL importers
│   ├── Export/                    # cURL, Swift, Python exporters
│   └── Services/                  # Keychain, biometric, HTTP, clipboard
├── VaulthoundDaemon/              # XPC service (FSEvents, socket server)
├── vaulthound-cli/                # CLI companion (exec, list, env, hook)
└── VaulthoundKit/                 # Shared Swift package
    └── Sources/
        ├── VaulthoundModels/      # SwiftData models + protocols
        ├── VaulthoundCore/        # Business logic (parsers, codecs, route discovery)
        └── VaulthoundSecurity/    # Keychain + Touch ID wrappers
```

## Tests

```bash
cd VaulthoundKit
swift test
```

79 tests across 10 suites covering: `.env` parsing, secret detection, variable interpolation, cURL parsing, Postman import, route discovery (Next.js/SvelteKit/Nuxt), project file management, cookie handling, Keychain operations, and secure references.

## Roadmap

- [ ] **V1.1** — Shell hook (direnv-style), 1Password CLI integration, AWS Secrets Manager, `.env.example` missing value detection
- [ ] **V1.2** — Team onboarding wizard, encrypted exports, GraphQL support, AI provider spend tracking
- [ ] **V2.0** — HashiCorp Vault, WebSocket testing, pre/post-request scripting, Spotlight integration

## License

MIT
