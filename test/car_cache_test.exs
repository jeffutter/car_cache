defmodule CarCacheTest do
  use ExUnit.Case

  use PropCheck
  use PropCheck.StateM.ModelDSL

  def key, do: non_neg_integer()
  def value, do: non_neg_integer()

  @moduletag timeout: 120_000
  property "stateful property", [:verbose, numtests: 2_500, max_size: 150] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        {:ok, pid} = CarCache.start_link(name: :test, max_size: 100)

        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r

        if pid && Process.alive?(pid) do
          GenServer.stop(pid)
        end

        (result == :ok)
        |> when_fail(print_report(r, cmds))
      end
    end
  end

  def initial_state, do: %{name: :test, inserted: %{}, full: false, max_size: 100}

  def command_gen(%{name: name, inserted: inserted}) when inserted == %{} do
    {:put, [name, key(), value()]}
  end

  def command_gen(%{name: name, inserted: inserted}) do
    known_key =
      inserted
      |> Map.keys()
      |> Enum.take_random(1)
      |> List.first()

    key = weighted_union([{1, known_key}, {4, key()}])

    frequency([
      {4, {:put, [name, key, value()]}},
      {1, {:get, [name, key]}}
    ])
  end

  defcommand :put do
    def impl(name, key, value) do
      CarCache.put(name, key, value)
    end

    def post(state, [name, key, value], _) do
      inserted = Map.put(state.inserted, key, value)
      full = length(Map.keys(inserted)) >= state.max_size

      if !full do
        v = CarCache.get(name, key)

        if value == v do
          true
        else
          IO.puts("#{value} != #{v}")
          false
        end
      end
    end

    def next(state, [_name, key, value], _) do
      full = length(Map.keys(state.inserted)) >= state.max_size

      %{state | inserted: Map.put(state.inserted, key, value), full: full}
    end
  end

  defcommand :get do
    def impl(name, key) do
      CarCache.get(name, key)
    end
  end
end
