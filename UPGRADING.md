# Upgrading

## 0.7.0

Rendered English interface text stays byte-identical to `0.6.0`. Hosts that read
Admin DSL title/link/action fields as String values must evaluate the callables
Admin now returns (see below).

### What Changed

- Admin DSL chrome (section title, screen titles, resource title, action labels
  and confirms, show-screen buttons, summary label, chart title/series, widget
  titles/info/period labels) resolves through
  `RecordingStudioAgents::Copy.t(...)`. English comes only from
  `config/locales/en.yml`; call sites do not pass English `default:`.
- `Section.title`, section `links[].text`, the screen and resource `title`, and
  the `turn_on` / `turn_off` action `text` now return callables that Admin
  evaluates at render. Hosts reading those fields directly must evaluate them
  (for example with `evaluate`) instead of treating them as String literals.
- Section, screen, and resource `subtitle` stay English string literals (Admin
  search reads those fields raw).
- Enablement flashes (`%{name} is on.` / `%{name} is off.`) resolve through
  `Copy.t`.
- Boot-order host override under
  `test/dummy/config/locales/recording_studio_agents_boot_override.en.yml`
  covers the rarely shown failed-runs widget info key.

Keys added (under `recording_studio.agents`):

| Key | English |
| --- | --- |
| `flashes.agent_on` | `%{name} is on.` |
| `flashes.agent_off` | `%{name} is off.` |
| `admin.section.title` | Agents admin |
| `admin.links.agents` | Agents |
| `admin.links.runs` | Runs |
| `admin.links.tasks` | Tasks |
| `admin.links.usage` | Usage by agent |
| `admin.links.evaluations` | Evaluations |
| `admin.links.agent` | Agent |
| `admin.links.skill` | Skill |
| `admin.links.tool` | Tool |
| `admin.screens.agents.title` | Agents |
| `admin.screens.runs.title` | Runs |
| `admin.screens.tasks.title` | Tasks |
| `admin.screens.usage.title` | Usage by agent |
| `admin.screens.evaluations.title` | Evaluations |
| `admin.resource.agents.title` | Agents |
| `admin.resource.agents.turn_off` | Turn off |
| `admin.resource.agents.turn_on` | Turn on |
| `admin.resource.agents.confirm_turn_off` | Turn off `%{name}`? |
| `admin.resource.agents.confirm_turn_on` | Turn on `%{name}`? |
| `admin.buttons.runs` | Runs |
| `admin.buttons.calls` | Calls |
| `admin.summary.agents` | Agents |
| `admin.chart.attempts_title` | Attempts |
| `admin.chart.attempts_series` | Attempts |
| `admin.widgets.failed_runs.title` | Failed runs |
| `admin.widgets.failed_runs.info` | The last attempts that did not finish. Open Runs if you need to retry from the host. |
| `admin.widgets.attempts_this_period.title` | Attempts this period |
| `admin.widgets.attempts_this_period.info` | How many times an agent started in the last 4 weeks, versus the 4 weeks before that. |
| `admin.widgets.tokens_this_period.title` | Tokens this period |
| `admin.widgets.tokens_this_period.info` | Model-call tokens for those attempts. Shows blank if AI history was cleaned. |
| `admin.widgets.hungry_agents.title` | Hungry agents |
| `admin.widgets.hungry_agents.info` | Who used the most model-call tokens in the last 4 weeks. |
| `admin.widgets.period_label` | Last 4 weeks |

Left untranslated on purpose: Admin section, screen, and resource subtitles
(Admin search reads those fields raw), Admin column headers / header tooltips /
filter titles, Admin cell values (status badges, On/Off, detail-row labels,
Progress labels, `None`), model validation messages, developer errors, logs,
generator CLI, and stored or user-authored data.

### Host Action Required

English hosts that only render through Admin need no change. Hosts that read
`Section.title`, `links[].text`, screen/resource `title`, or turn on/off action
`text` directly must evaluate those callables. Override keys under
`recording_studio.agents` in the host's `config/locales` when translating.
