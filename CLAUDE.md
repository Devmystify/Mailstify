# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mailstify is a Mailchimp clone (email marketing: lists, subscribers, campaigns) built as a **step-by-step tutorial codebase**. Work progresses in numbered parts on branches like `part_6`. Expect intentionally-incomplete features: code marked `Will be finalized in Part 7` (e.g. campaign `status` tracking) is a future step, not dead code.

Naming gotcha: the product is "Mailstify" but the Rails application module and Kamal service are still named `MailchimpClone` / `mailchimp_clone` (see `config/application.rb`, `config/deploy.yml`).

## Stack

- **Rails 8.0.3**, Ruby 3.4.6, **SQLite** for everything.
- **Hotwire** (Turbo + Stimulus) with **importmap**: there is no Node.js, no `package.json`, no bundler/webpack. JS deps are pinned in `config/importmap.rb` and vendored. Propshaft is the asset pipeline.
- **Solid Queue / Solid Cache / Solid Cable**: database-backed, no Redis.
- **Action Text** (Trix) for campaign rich-text bodies; **Active Storage** for attachments; **bcrypt** for auth.

### Multi-database

Each environment uses 4 separate SQLite databases: `primary`, `cache`, `queue`, `cable` (see `config/database.yml`). Migrations are split by directory:
- App migrations → `db/migrate`
- Queue/cache/cable → `db/queue_migrate`, `db/cache_migrate`, `db/cable_migrate` (managed by the Solid gems; you rarely touch these).

## Commands

```bash
bin/setup                # install gems + prepare DBs (use bin/setup --skip-server to not boot)
bin/dev                  # run the app (just `rails server`; no JS build step needed)
bin/rails console
bin/rails db:prepare     # create+migrate all 4 databases; db:migrate for app changes

bin/rubocop              # lint (rubocop-rails-omakase); -a to autocorrect
bin/brakeman --no-pager  # security static analysis
bin/importmap audit      # audit pinned JS deps for CVEs
bin/importmap pin <pkg>  # add a JS dependency

bin/rspec                # run the RSpec suite; see Tests. Never bare `rspec`
```

CI (`.github/workflows/ci.yml`, on PRs + pushes to `main`) runs exactly three jobs: **brakeman**, **importmap audit**, **rubocop**. The RSpec suite is **not** wired into CI yet, so run `bin/rspec` locally before pushing.

### Tests

The test framework is **RSpec** (`rspec-rails`). Specs live under `spec/` (`spec/requests/`, etc.); config is in `spec/rails_helper.rb`, `spec/spec_helper.rb`, and `.rspec`.

- Run with **`bin/rspec`** (or `bundle exec rspec`). **Never bare `rspec`**: it bypasses Bundler, so Ruby 4.0.1's default `erb 6.0.4` activates and clashes with the locked `erb 5.1.1` (`Gem::LoadError`). The `bin/` binstub loads Bundler first, so it works.
- Minitest / the `rails/test_unit/railtie` is intentionally left disabled in `config/application.rb`; RSpec doesn't need it. Don't use `bin/rails test` (the bundle has minitest 6, which Rails 8.0.3's runner can't drive).
- Request specs hit `ApplicationController`'s `allow_browser versions: :modern`, which only 406s a browser reporting a version *below* the modern threshold. The rack-test default (no `User-Agent`) passes, so specs need no UA header. Don't hard-code one; it drifts as Rails raises the threshold.
- `use_transactional_fixtures` is on, so data created in an example rolls back automatically.
- Mailer previews stay in `test/mailers/previews/` (Action Mailer's preview path also includes RSpec's `spec/mailers/previews/`).

Note: `.ruby-version` says `3.4.6`, but this machine runs Ruby `4.0.1` (and 3.4.6 isn't installed). The lockfile has no `RUBY VERSION` pin, so the bundle still resolves under 4.0.1, but a version manager that honors `.ruby-version` will fail to select an interpreter.

### Background jobs in development (important)

The Active Job adapter is `solid_queue` in **all** environments, including development. `perform_later` / `deliver_later` only enqueue. Nothing runs them unless a worker is up. To actually process jobs (e.g. sending a campaign) locally, run a worker alongside the server:

```bash
bin/jobs                          # Solid Queue worker
# or boot Puma with the in-process supervisor:
SOLID_QUEUE_IN_PUMA=true bin/dev
```

In production (Kamal), `SOLID_QUEUE_IN_PUMA=true` runs the supervisor inside Puma on the web server.

## Architecture

### Authentication (Rails 8 built-in generator pattern)

- `Authentication` concern (`app/controllers/concerns/authentication.rb`) is included in `ApplicationController`, so **every controller requires login by default** via `before_action :require_authentication`. Opt a controller/action out with `allow_unauthenticated_access only: %i[...]` (see `SessionsController`).
- Current user/session live in `Current` (`ActiveSupport::CurrentAttributes`): use `Current.user` and `Current.session`, never a `current_user` helper.
- Sessions are persisted `Session` records keyed by a signed, permanent, httponly `session_id` cookie. Login is rate-limited.

### Multi-tenancy / authorization convention

There is no Pundit/CanCan. Authorization is enforced by **always scoping queries through the owning association**, e.g. `Current.user.lists.find(...)`, `Current.user.campaigns.new(...)`. Subscribers belong to a list, not directly to a user, so `User has_many :subscribers, through: :lists` exposes `Current.user.subscribers` for scoping (used by `SubscribersController#index` and `#set_subscriber`). When you add controller actions, scope through `Current.user` rather than looking records up by bare id. It's the security boundary.

Data model: `User` → many `lists` & `campaigns`; `List` → many `subscribers` & `campaigns`; `Subscriber` belongs to a `List` (email unique **per list**); `Campaign` belongs to a `User` and a `List` and `has_rich_text :body`.

### Campaign send pipeline (two-stage fan-out)

`POST /campaigns/:id/send_campaign` → guards that `body` is present → `CampaignDispatchJob.perform_later(campaign)`. The dispatch job iterates `list.subscribers.find_each` and enqueues one `CampaignMailer.campaign_email(campaign, subscriber).deliver_later` per subscriber. So one user click = one dispatch job that spawns N mailer jobs. Keep the dispatch job orchestration-only; per-recipient work belongs in the mailer job.

### Hotwire / Turbo Streams UI

The main interactive surface is the **list show page**, where subscribers are created/destroyed inline without full reloads. `SubscribersController` `create`/`destroy` respond with `turbo_stream` arrays that `prepend`/`remove` rows, `replace` the form, `update` the `subscriber-count`, and toggle the empty-state partial, all targeted by `dom_id` helpers (`dom_id(list, :subscribers)`, etc.). When changing subscriber markup, keep the partial names and `dom_id` targets in sync across the controller, `_subscriber`, `_form`, `_subscribers_table`, and `_empty_state` partials.

Note: newer controllers use Rails 8 `params.expect(...)` (lists, subscribers) while `CampaignsController` uses the older `params.require(...).permit(...)`.
