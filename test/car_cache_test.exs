defmodule CarCacheTest do
  use ExUnit.Case
  doctest CarCache

  use PropCheck
  use PropCheck.StateM.ModelDSL

  # def key, do: oneof([atom(), utf8()])
  # def value, do: atom()
  def key, do: non_neg_integer()
  def value, do: non_neg_integer()

  def cache_name do
    let [i <- integer(2, 10), s <- utf8(^i, 1)] do
      String.to_atom(s)
    end
  end

  @moduletag timeout: 120_000
  property "stateful property", [:verbose, numtests: 2_500, max_size: 150] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r

        (result == :ok)
        |> when_fail(print_report(r, cmds))
      end
    end
  end

  def initial_state, do: %{cache: nil, inserted: %{}, full: false, max_size: 0}

  def command_gen(%{cache: nil}) do
    {:create_cache, [cache_name(), integer(10, 1_000)]}
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
    def impl(name, max_size) do
      CarCache.new(name, max_size: max_size)
    end

    def next(state, [_name, max_size], cache) do
      %{state | cache: cache, max_size: max_size}
    end
  end

  defcommand :insert do
    def impl(cache, key, value) do
      CarCache.insert(cache, key, value)
    end

    def post(state, [_cache, key, value], cache) do
      inserted = Map.put(state.inserted, key, value)
      full = length(Map.keys(inserted)) >= state.max_size

      if full do
        invariants(cache, full)
      else
        v = CarCache.get(cache, key)

        if value == v do
          true
        else
          IO.puts("#{value} != #{v}")
          false
        end && invariants(cache, full)
      end
    end

    def next(state, [_cache, key, value], cache) do
      full = length(Map.keys(state.inserted)) >= state.max_size

      %{state | cache: cache, inserted: Map.put(state.inserted, key, value), full: full}
    end
  end

  defcommand :get do
    def impl(cache, key) do
      CarCache.get(cache, key)
    end

    def post(state, [cache, _key], _val) do
      full = length(Map.keys(state.inserted)) >= state.max_size

      invariants(cache, full)
    end
  end

  def invariants(cache, full) do
    i1(cache) && i2(cache) && i3(cache) && i4(cache) && i5(cache) && i6(cache) && i7(cache, full)
  end

  def i1(cache) do
    # I1 0 ≤ |T1| + |T2| ≤ c.
    if 0 <= cache.t1.size + cache.t2.size &&
         cache.t1.size + cache.t2.size <= cache.c do
      true
    else
      IO.puts("Post Condition 1 Failed: 0 <= #{cache.t1.size} + #{cache.t2.size} >= #{cache.c}")
      false
    end
  end

  def i2(cache) do
    # I2 0 ≤ |T1| + |B1| ≤ c.
    if 0 <= cache.t1.size + cache.b1.size &&
         cache.t1.size + cache.b1.size <= cache.c do
      true
    else
      IO.puts("Post Condition 2 Failed: 0 <= #{cache.t1.size} + #{cache.b1.size} >= #{cache.c}")
      false
    end
  end

  def i3(cache) do
    # I3 0 ≤ |T2| + |B2| ≤ 2c.
    if 0 <= cache.t2.size + cache.b2.size &&
         cache.t2.size + cache.b2.size <= 2 * cache.c do
      true
    else
      IO.puts("Post Condition 3 Failed: 0 <= #{cache.t2.size} + #{cache.b2.size} >= 2 * #{cache.c}")
      false
    end
  end

  def i4(cache) do
    # I4 0 ≤ |T1| + |T2| + |B1| + |B2| ≤ 2c.
    if 0 <= cache.t1.size + cache.t2.size + cache.b1.size + cache.b2.size &&
         cache.t1.size + cache.t2.size + cache.b1.size + cache.b2.size <= 2 * cache.c do
      true
    else
      IO.puts(
        "Post Condition 4 Failed: 0 <= #{cache.t1.size} + #{cache.t2.size} + #{cache.b1.size} + #{cache.b2.size} >= 2 * #{
          cache.c
        }"
      )

      false
    end
  end

  def i5(cache) do
    # I5 If |T1|+|T2|<c, then B1 ∪B2 is empty.
    if cache.t1.size + cache.t2.size < cache.c do
      if cache.b1.size == 0 && cache.b2.size == 0 do
        true
      else
        IO.puts("Post Condition 5 Failed: B1 or B2 not empty")
        false
      end
    else
      true
    end
  end

  def i6(cache) do
    # I6 If |T1|+|B1|+|T2|+|B2| ≥ c, then |T1|+|T2| = c.
    if cache.t1.size + cache.b1.size + cache.t2.size + cache.b2.size >= cache.c do
      if cache.t1.size + cache.t2.size == cache.c do
        true
      else
        IO.puts("Post Condition 6 Failed: #{cache.t1.size} + #{cache.t2.size} != #{cache.c}")
        false
      end
    else
      true
    end
  end

  def i7(cache, full) do
    # I7 Due to demand paging, once the cache is full, it remains full from then on.
    if full do
      if cache.t1.size + cache.t2.size == cache.c do
        true
      else
        IO.puts(
          "Post Condition 7 Failed: Cache did not remain full - #{cache.t1.size} + #{cache.t2.size} != #{cache.c}"
        )

        false
      end
    else
      true
    end
  end
end
