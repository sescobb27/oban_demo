defmodule ObanDemo.Repo.Migrations.ObanUniqueArgs do
  use Ecto.Migration

  def change do
    create(index("oban_jobs", [:queue, :args], unique: true))
  end
end
