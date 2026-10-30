# Upgrading

## 0.8.3

Development and dummy apps pin FlatPack `v0.1.331` (`view_component` 4.20.0).

Admin 2.3 through 2.5 and core 4.6 break on FlatPack `v0.1.331`. Those gems pass Card `style:`, PageNav `back_icon` and `anchor_label`, and TopNav `always_display`. Hosts on those gems should keep FlatPack `v0.1.207`. FlatPack `v0.1.331` is the pin once Admin 2.5.2 and core 6.3 are pinned. This repo's dummy overrides hide the break until then.

`recording_studio_admin` is `>= 2.0.6`, `< 2.6`. There is no migration.

## 0.8.0

Pin `recording_studio_metrics` to `>= 0.3.0`, `< 0.4`. Development and dummy Gemfiles use GitHub tag `v0.3.1`.

### What Changed

- The metrics dependency allows `0.3.x` and stops before `0.4`.
- Recording Studio MCP `v0.17.0` names one tool per metric by replacing the dot with a hyphen.
- `agent_runs-over_time` takes `from`, `to`, and `interval`. `agent_runs-by_status`, `agent_runs-by_agent`, `agent_evaluations-by_verdict`, and `agent_evaluations-avg_score` do not take that window.
- HTTP paths are unchanged. Registration and `api_authorize` are unchanged.

### Host Action Required

Pin the metrics gem. There is no migration.

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
