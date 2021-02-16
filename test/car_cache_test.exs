defmodule CarCacheTest do
  use ExUnit.Case
  doctest CarCache

  use PropCheck
  use PropCheck.StateM.ModelDSL

  def key, do: oneof([atom(), utf8()])
  def value, do: any()
  def cache_name, do: atom()

  @moduletag timeout: 120_000
  property "stateful property", [:verbose, numtests: 500, max_size: 150] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r

        (result == :ok)
        |> when_fail(print_report(r, cmds))
      end
    end
  end

  def initial_state, do: %{cache: nil, inserted: %{}}

  def command_gen(%{cache: nil}) do
    {:create_cache, [cache_name()]}
  end

  def command_gen(%{cache: cache, inserted: inserted}) when inserted == %{} do
    {:insert, [cache, key(), value()]}
  end

  def command_gen(%{cache: cache, inserted: inserted}) do
    known_key =
      inserted
      |> Map.keys()
      |> Enum.take_random(1)
      |> List.first()

    key = weighted_union([{1, known_key}, {4, key()}])

    frequency([
      {4, {:insert, [cache, key, value()]}},
      {1, {:get, [cache, key]}}
    ])
  end

  defcommand :create_cache do
    def impl(name) do
      CarCache.new(name)
    end

    def next(state, _args, cache) do
      %{state | cache: cache}
    end
  end

  defcommand :insert do
    def impl(cache, key, value) do
      CarCache.insert(cache, key, value)
    end

    def post(_state, [_cache, key, value], cache) do
      v = CarCache.get(cache, key)
      v == value
    end

    def next(state, [_cache, key, value], cache) do
      %{cache: cache, inserted: Map.put(state.inserted, key, value)}
    end
  end

  defcommand :get do
    def impl(cache, key) do
      CarCache.get(cache, key)
    end
  end
end
