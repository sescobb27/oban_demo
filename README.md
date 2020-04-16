# ObanDemo

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `oban_demo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_demo, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/oban_demo](https://hexdocs.pm/oban_demo).

# Scheduling Jobs

## Batches Using plain Multis and Transactions

```elixir
batch_insert_prev = System.monotonic_time(:millisecond)
ObanDemo.batch_insert(1..100_000)
batch_insert_next = System.monotonic_time(:millisecond)
batch_insert_next - batch_insert_prev
```

## Batches Using Parallel Multis and Transactions

```elixir
parallel_multi_batch_insert_prev = System.monotonic_time(:millisecond)
ObanDemo.parallel_multi_batch_insert(1..100_000)
parallel_multi_batch_insert_next = System.monotonic_time(:millisecond)
parallel_multi_batch_insert_next - parallel_multi_batch_insert_prev
```

## Batches Using Parallel insert_all

```elixir
parallel_batch_insert_prev = System.monotonic_time(:millisecond)
ObanDemo.parallel_batch_insert(1..100_000)
parallel_batch_insert_next = System.monotonic_time(:millisecond)
parallel_batch_insert_next - parallel_batch_insert_prev
```

## Scale Queue

```elixir
Oban.scale_queue(:parallel_batch_queue, 10)
```

## Check How Jobs Grow In DB

```sql
select count(*) from oban_jobs where queue='batch_queue';
select count(*) from oban_jobs where queue='parallel_multi_batch_queue';
select count(*) from oban_jobs where queue='parallel_batch_queue';
```
