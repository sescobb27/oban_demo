import Config

config :oban_demo, ObanDemo.Repo,
  database: "oban_demo_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :oban_demo, ecto_repos: [ObanDemo.Repo]
