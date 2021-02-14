defmodule CarCache.LRU do
  use GenServer

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

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def get(name, key, fun) when is_function(fun, 0) do
    case get(name, key) do
      nil ->
        value = fun.()
        insert(name, key, value)
        value

      value ->
        value
    end
  end

  def get(name, key) do
    table = :"#{name}_data"

    case :ets.lookup(table, key) do
      [] ->
        nil

      [{^key, value, _}] ->
        touch(name, key)

        value
    end
  end

  def insert(name, key, value) do
    GenServer.cast(name, {:insert, key, value})
  end

  defp touch(name, key) do
    GenServer.cast(name, {:touch, key})
  end

  @impl true
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 1_000)
    name = Keyword.fetch!(opts, :name)

    data_name = :"#{name}_data"
    lru_name = :"#{name}_lru"

    data_table = :ets.new(data_name, [:named_table, :ordered_set, :protected, {:read_concurrency, true}])

    lru_table = :ets.new(lru_name, [:named_table, :ordered_set, :protected])

    state = %__MODULE__{
      max_size: max_size,
      size: 0,
      data_name: data_name,
      lru_name: lru_name,
      data_table: data_table,
      lru_table: lru_table
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:insert, key, value}, state) do
    size =
      case state.size < state.max_size do
        true ->
          do_insert(state, key, value)

          state.size + 1

        false ->
          old_ts = :ets.first(state.lru_table)
          [{^old_ts, old_key}] = :ets.lookup(state.lru_table, old_ts)

          :ets.delete(state.lru_table, old_ts)
          :ets.delete(state.data_table, old_key)

          do_insert(state, key, value)

          state.size
      end

    {:noreply, %{state | size: size}}
  end

  @impl true
  def handle_cast({:touch, key}, state) do
    case :ets.lookup(state.data_table, key) do
      [] ->
        :ok

      [{^key, _value, old_ts}] ->
        ts = System.monotonic_time()

        :ets.update_element(state.data_table, key, {3, ts})
        :ets.delete(state.lru_table, old_ts)
        :ets.insert(state.lru_table, {ts, key})
    end

    {:noreply, state}
  end

  defp do_insert(state, key, value) do
    ts = System.monotonic_time()
    :ets.insert(state.lru_table, {ts, key})
    :ets.insert(state.data_table, {key, value, ts})
  end
end
