import Config

config :oban_demo, ObanDemo.Repo,
  database: "oban_demo_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :oban_demo, ecto_repos: [ObanDemo.Repo]

config :oban_demo, Oban,
  repo: ObanDemo.Repo,
  # prune in 1 year
  prune: {:maxage, 60 * 60 * 24 * 365},
  crontab: false,
  queues: [batch_queue: 5, parallel_multi_batch_queue: 5, parallel_batch_queue: 5]
