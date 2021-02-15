defmodule CarCache.LRU do
  defstruct max_size: 1_000,
            size: 0,
            data_name: nil,
            lru_name: nil,
            data_table: nil,
            lru_table: nil

  @type t :: %__MODULE__{
          max_size: non_neg_integer(),
          size: non_neg_integer(),
          data_name: atom(),
          lru_name: atom(),
          data_table: :ets.tid(),
          lru_table: :ets.tid()
        }

  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, 1_000)

    data_name = :"#{name}_data"
    lru_name = :"#{name}_lru"

    data_table = :ets.new(data_name, [:named_table, :ordered_set, :protected, {:read_concurrency, true}])

    lru_table = :ets.new(lru_name, [:named_table, :ordered_set, :protected])

    %__MODULE__{
      max_size: max_size,
      size: 0,
      data_name: data_name,
      lru_name: lru_name,
      data_table: data_table,
      lru_table: lru_table
    }
  end

  @spec get(t(), any()) :: any()
  def get(lru, key) do
    case :ets.lookup(lru.data_table, key) do
      [] ->
        nil

      [{^key, value, _}] ->
        touch(lru, key)

        value
    end
  end

  @spec pop(t()) :: {any(), any(), t()}
  def pop(lru) do
    ts = :ets.first(lru.lru_table)
    [{^ts, key}] = :ets.lookup(lru.lru_table, ts)
    [{^key, value, ^ts}] = :ets.lookup(lru.data_table, key)

    :ets.delete(lru.lru_table, ts)
    :ets.delete(lru.data_table, key)

    {key, value, %__MODULE__{lru | size: lru.size - 1}}
  end

  @spec member?(t(), any()) :: boolean()
  def member?(lru, key) do
    :ets.member(lru.data_table, key)
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
    case :ets.lookup(lru.data_table, key) do
      [] ->
        :ok

      [{^key, _value, old_ts}] ->
        ts = System.monotonic_time()

        :ets.update_element(lru.data_table, key, {3, ts})
        :ets.delete(lru.lru_table, old_ts)
        :ets.insert(lru.lru_table, {ts, key})

        :ok
    end
  end

  defp do_insert(state, key, value) do
    ts = System.monotonic_time()
    :ets.insert(state.lru_table, {ts, key})
    :ets.insert(state.data_table, {key, value, ts})
  end
end
