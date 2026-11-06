# Upgrading

## 0.10.1

Development and dummy locks use Rails 8.1.4.1. rack 3.2.8, nokogiri 1.19.7, loofah 2.25.3, rails-html-sanitizer 1.7.2, and dummy net-ssh 7.3.8 are unchanged. Ruby is 3.3.13. There is no migration. Hosts should bump their own Rails lock to 8.1.4.1.

## 0.10.0

**Breaking.** `RecordingStudioAgents::Admin::LastFourWeeksPeriod` is removed. That constant was the module prepended onto `RecordingStudioAdmin::Period`, including `from_preset_key`. It is not an alias of `LastFourWeeks`. Use `RecordingStudioAdmin::Period` for presets.

**Breaking.** `LastFourWeeks::LOOKBACK_DAYS` is removed. Call `LastFourWeeks.lookback_days`, which reads `RecordingStudioAdmin::Period::LAST_4_WEEKS_LOOKBACK_DAYS`.

This gem no longer prepends `RecordingStudioAdmin::Period`. Runs and Usage by agent still default to Last 4 weeks. There is no migration in this gem.

## 0.9.1

Staff screens that must ignore the switched product workspace set `RecordingStudioAdmin` `config.current_root_recording_resolver` to a callable that returns nil. Delete any prepend of `RecordingStudioAdmin::ApplicationController#current_root_recording`.

Model-call lists that must include workspace runs set `RecordingStudioAI` `config.admin_runs_scope`. The callable receives the Admin context and returns a `RecordingStudioAI::Run` relation. Delete any prepend of `AdminScreens::RecordingStudioAIWidgets#runs_scope`.

Put host admin sections on the Zeitwerk path and call `RecordingStudioAdmin.register_section`. It replaces a reloaded class of the same name. There is no migration in this gem.

## 0.9.0

Development and dummy apps pin Recording Studio `v6.3.0` and the core 6 addon set: FlatPack `v0.1.332`, Accessible `v0.24.0`, Admin `v2.8.1`, AI `v0.19.5`, Logs `v0.7.1`, Metrics `v0.7.0`, Trashable `v0.12.0`. The dummy also pins Root Switchable `v0.11.3`, Cache `v0.6.0`, and Web Search `v0.6.0`.

The gemspec requires `recording_studio` `>= 6.3.0`, `< 7` and `recording_studio_admin` `>= 2.8.1`, `< 3.0`. Do not pin `view_component` in this gem. Tailwind stays until Admin tables no longer need a host Tailwind build. Development and dummy locks use nokogiri 1.19.7 and rails-html-sanitizer 1.7.2.

`RecordingStudio::UsesDefaultLayout` is gone. Set `config.layout = "recording_studio/default_layout"` on Admin and Accessible.

There is no migration in this gem. Hosts still install the upstream migrations from Recording Studio AI, Accessible, Logs, and Root Switchable, then run `bin/rails db:migrate`. The dummy copies the AI, Accessible, and Logs migrations newer than `20261010000014` into `test/dummy/db/migrate` and `test/dummy/db/schema.rb` so a schema load can boot. It does not apply engine migrations at boot. The first admin on an owned root is `RecordingStudioAccessible.bootstrap_owner_access!`. Accessible 0.24 refuses `grant_access` for a role the manager does not already hold, so the seed starts with `bootstrap_owner_access!`.

The dummy no longer copies Admin's section template. The section grid is Admin's `cols: 3`. The widget partial `recording_studio_admin/shared/_widget` remains. The footer ghost button uses the widget link label. Failed runs links to runs. Hungry agents links to agents. Number cards still say More. List rows set `--list-item-padding-x` to 0.

## 0.8.10

The dummy sign-in shell and the Admin layout override are FlatPack `PageLayout`. Sidebar spacing is `Stack`. Home and the playground use `fp-layout-content`, so the column inset matches the top bar. The playground agent switch is the `playground-agent` Stimulus controller. Step notes use `CodeBlock`. Table row actions stay Admin's ghost button. `data-theme="rounded"` is unchanged. There is no migration.

## 0.8.9

The dummy keeps `test/dummy/app/assets/stylesheets/admin_tables.css` for its own Admin screens. That file is not shipped. It lines the table frame up with the card edge. The rounded border-width rule is in `@layer theme` inside `:where()`, so FlatPack's rounded theme still wins. Below 768px about 1rem of the Actions column stays in view, and the table frame clips its horizontal scrollbar to the card radius. `cascade_layers.css` is also dummy-only and must be the first stylesheet, before `yield :head`, so Tailwind utilities beat the base reset. There is no migration.

## 0.8.8

`Runtime`, ledger persistence, and admin queries live in smaller files under the same constants. `Runtime#call`, `Persistence::RunLedger`, `Persistence::Opening`, and `Admin::Queries` behave as before. There is no migration.

## 0.8.7

`api_authorize` for agent metrics is `RecordingStudioAgents::Admin::MetricsAccess`. It still allows a view on the admin root through Accessible. The Metrics module does not call Accessible itself. `RecordingStudioAgents::Api::Access` warns and forwards to `Admin::MetricsAccess` for this release.

Turn on and turn off inherit `RecordingStudioAdmin::ApplicationController`. This gem no longer defines `current_root_recording`. The redirect uses the `:admin` surface path, so a mount such as `/staff` stays on `/staff`. There is no migration.

## 0.8.6

**Breaking.** `RecordingStudioAgents::Engine.apply_model_extensions` and `apply_controller_extensions` are removed. The engine no longer applies `hooks.extend_model` or `hooks.extend_controller`. If this gem's hooks still have those blocks at boot, it logs a warning with the registered model and controller names. `before_initialize`, `on_configuration`, and `after_initialize` are unchanged. There is no migration.

The dummy registers `DummyStudioProvider` for Gemini (`:gemini`) and TypeSafe (`:typesafe`) through `RecordingStudioAI.register_provider` when `gemini_api_key` and `openai_api_key` are blank. Do not prepend `RecordingStudioAI` to stub `generate`.

## 0.8.4

The engine no longer draws `GET /recording_studio_agents`. `recording_studio_agents.root_path` is gone. Hosts that linked that path or health-checked the mount need another URL. There is no migration.

## 0.8.3

Development and dummy apps pin FlatPack `v0.1.331` (`view_component` 4.20.0).

Admin 2.3 through 2.5 and core 4.6 break on FlatPack `v0.1.331`. Those gems pass Card `style:`, PageNav `back_icon` and `anchor_label`, and TopNav `always_display`. Hosts on those gems should keep FlatPack `v0.1.207`. FlatPack `v0.1.331` is the pin once Admin 2.5.2 and core 6.3 are pinned. This repo's dummy overrides hide the break until then.

`recording_studio_admin` is `>= 2.0.6`, `< 2.6`. There is no migration.

## 0.8.1

`recording_studio_metrics` is `>= 0.3.0`, `< 1.0`. Development and dummy Gemfiles still use GitHub tag `v0.3.1`.

The 0.8.0 note below described the earlier `< 0.4` ceiling. 0.8.1 replaced that ceiling. There is no migration.

## 0.8.0

0.8.0 pinned `recording_studio_metrics` to `>= 0.3.0`, `< 0.4`. Development and dummy Gemfiles used GitHub tag `v0.3.1`. 0.8.1 lifted the ceiling to `< 1.0`.

### What Changed

- The metrics dependency allows `0.3.x` and stops before `0.4`.
- Recording Studio MCP `v0.17.0` names one tool per metric by replacing the dot with a hyphen.
- `agent_runs-over_time` takes `from`, `to`, and `interval`. `agent_runs-by_status`, `agent_runs-by_agent`, `agent_evaluations-by_verdict`, and `agent_evaluations-avg_score` do not take that window.
- HTTP paths are unchanged. Registration and `api_authorize` are unchanged.

### Host Action Required

0.8.1 replaced this pin. Use `>= 0.3.0`, `< 1.0`. There is no migration.

The host still registers Metrics HTTP once. This gem does not call `RecordingStudioMetrics::Api.register!`.

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

MCP builds its tools from the metrics already exposed on `:operations`. Staff with AdminRoot `:view` can read them. A public token or a non-admin operations token is denied.

## 0.7.0

Rendered English Admin DSL chrome stays byte-identical to `0.6.0` as string
literals. Enablement flashes resolve through I18n with English in
`config/locales/en.yml` (no English `default:` on call sites).

### What Changed

- Enablement flashes (`%{name} is on.` / `%{name} is off.`) resolve through
  `RecordingStudioAgents::Copy.t(...)`. English comes only from
  `config/locales/en.yml`.
- Admin DSL values (section/screen/resource titles and subtitles, link text,
  action text, confirms, column titles, widget titles/info, chart labels) stay
  English string literals and are not I18n keys.
- Boot-order host override under
  `test/dummy/config/locales/recording_studio_agents_boot_override.en.yml`
  covers the rarely shown turn-off flash key.

Keys added (under `recording_studio.agents`):

| Key | English |
| --- | --- |
| `flashes.agent_on` | `%{name} is on.` |
| `flashes.agent_off` | `%{name} is off.` |

Left untranslated on purpose: Admin DSL chrome (titles, subtitles, links,
actions, confirms, columns, widgets, charts), model validation messages,
developer errors, logs, generator CLI, and stored or user-authored data.

### Host Action Required

None for English hosts. Override keys under `recording_studio.agents.flashes`
in the host's `config/locales` when translating enablement flashes.
