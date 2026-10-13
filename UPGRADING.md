# Upgrading

## 0.7.0

This is a non-breaking upgrade. Rendered English interface text stays
byte-identical to `0.6.0`.

### What Changed

- Admin DSL chrome (section title/subtitle, screen titles, resource title,
  action labels and confirms, show-screen buttons, summary label, chart
  title/series, widget titles/info/period labels) resolves through
  `RecordingStudioAgents::Copy.t(..., default: …)`.
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
| `admin.section.subtitle` | Who ran, what they tried, and how heavy the model calls were. |
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

Left untranslated on purpose: Admin screen and resource subtitles (Admin search
reads those fields raw), Admin column headers / header tooltips / filter titles,
Admin cell values (status badges, On/Off, detail-row labels, Progress labels,
`None`), model validation messages, developer errors, logs, generator CLI, and
stored or user-authored data.

### Host Action Required

None for English hosts. Override keys under `recording_studio.agents` in the
host's `config/locales` when translating.
