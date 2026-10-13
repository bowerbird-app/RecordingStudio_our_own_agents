# Upgrading

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
  English string literals. They are not I18n keys and do not return callables.
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
