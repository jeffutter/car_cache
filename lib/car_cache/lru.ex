defmodule CarCache.LRU do
  defstruct name: nil,
            max_size: 1_000,
            size: 0,
            lru_name: nil,
            data_table: nil,
            lru_table: nil

  @type t :: %__MODULE__{
          name: atom(),
          max_size: non_neg_integer(),
          size: non_neg_integer(),
          lru_name: atom(),
          data_table: :ets.tid(),
          lru_table: :ets.tid()
        }

  @spec new(atom(), :ets.tid(), Keyword.t()) :: t()
  def new(name, data_table, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, 1_000)

    lru_name = :"#{name}_lru"

    lru_table = :ets.new(lru_name, [:named_table, :ordered_set, :protected])

    %__MODULE__{
      name: name,
      max_size: max_size,
      size: 0,
      lru_name: lru_name,
      data_table: data_table,
      lru_table: lru_table
    }
  end

  @spec pop(t()) :: {any(), any(), t()}
  def pop(lru) do
    name = lru.name
    ts = :ets.first(lru.lru_table)
    [{^ts, key}] = :ets.lookup(lru.lru_table, ts)
    [{^key, value, ^name, ^ts}] = :ets.lookup(lru.data_table, key)

    :ets.delete(lru.lru_table, ts)
    :ets.delete(lru.data_table, key)

    {key, value, %__MODULE__{lru | size: lru.size - 1}}
  end

  @spec member?(t(), any()) :: boolean()
  def member?(lru, key) do
    name = lru.name

    case :ets.lookup(lru.data_table, key) do
      [{^key, _value, ^name, _ts}] -> true
      _ -> false
    end
  end

  @spec size(t()) :: non_neg_integer()
  def size(lru) do
    lru.size
  end

  @spec insert(t(), any(), any()) :: t()
  def insert(lru, key, value) do
    size =
      case lru.size < lru.max_size do
        true ->
          do_insert(lru, key, value)

          lru.size + 1

        false ->
          old_ts = :ets.first(lru.lru_table)
          [{^old_ts, old_key}] = :ets.lookup(lru.lru_table, old_ts)

          :ets.delete(lru.lru_table, old_ts)
          :ets.delete(lru.data_table, old_key)

          do_insert(lru, key, value)

          lru.size
      end

    %__MODULE__{lru | size: size}
  end

  @spec touch(t(), any()) :: :ok
  def touch(lru, key) do
    name = lru.name

    case :ets.lookup(lru.data_table, key) do
      [] ->
        :ok

      [{^key, _value, ^name, old_ts}] ->
        ts = System.monotonic_time()

        :ets.update_element(lru.data_table, key, {4, ts})
        :ets.delete(lru.lru_table, old_ts)
        :ets.insert(lru.lru_table, {ts, key})

        :ok
    end
  end

  defp do_insert(state, key, value) do
    ts = System.monotonic_time()
    :ets.insert(state.lru_table, {ts, key})
    :ets.insert(state.data_table, {key, value, state.name, ts})
  end
end
