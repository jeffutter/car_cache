defmodule CarCache.Clock do
  use GenServer

  defstruct max_size: 1_000,
            size: 0,
            position: 0,
            data_name: nil,
            clock_name: nil,
            data_table: nil,
            clock_table: nil

  @type t :: %__MODULE__{
          max_size: non_neg_integer(),
          size: non_neg_integer(),
          data_name: atom(),
          clock_name: atom(),
          data_table: :ets.tid(),
          clock_table: :ets.tid()
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

      [{^key, value, 0, pos}] ->
        promote(name, key, value, pos)
        value

      [{^key, value, 1, _pos}] ->
        value
    end
  end

  def insert(name, key, value) do
    GenServer.cast(name, {:insert, key, value})
  end

  @impl true
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 1_000)
    name = Keyword.fetch!(opts, :name)

    data_name = :"#{name}_data"
    clock_name = :"#{name}_clock"

    data_table = :ets.new(data_name, [:named_table, :set, :protected, {:read_concurrency, true}])
    clock_table = :ets.new(clock_name, [:named_table, :ordered_set, :protected])

    for i <- 1..max_size do
      :ets.insert(clock_table, {i, nil, 0})
    end

    state = %__MODULE__{
      max_size: max_size,
      data_name: data_name,
      clock_name: clock_name,
      data_table: data_table,
      clock_table: clock_table
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:promote, key, value, pos}, state) do
    case :ets.lookup(state.data_table, key) do
      [{^key, ^value, 0, ^pos}] ->
        promote(state, key, pos)

        :ok

      _ ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:insert, key, value}, state) do
    state =
      Enum.reduce_while(
        Stream.map(state.position..(state.max_size + state.position - 1), &rem(&1, state.max_size)),
        state,
        fn p, state ->
          case :ets.lookup(state.clock_table, p) do
            [{^p, nil, 0}] ->
              insert_at(state, p, key, value)

              {:halt, %{state | position: p + 1}}

            [{^p, old_key, 0}] ->
              :ets.delete(state.data_table, old_key)

              insert_at(state, p, key, value)

              {:halt, %{state | position: p + 1}}

            [{^p, key, 1}] ->
              demote(state, key, p)

              {:halt, %{state | position: p + 1}}

            _ ->
              {:cont, %{state | position: p + 1}}
          end
        end
      )

    {:noreply, state}
  end

  defp insert_at(state, pos, key, value) do
    :ets.insert(state.data_table, {key, value, 0, pos})
    :ets.insert(state.clock_table, {pos, key, 0})
  end

  defp promote(name, key, value, pos) do
    GenServer.cast(name, {:promote, key, value, pos})
  end

  defp promote(state, key, pos) do
    :ets.update_element(state.data_table, key, {3, 1})
    :ets.update_element(state.clock_table, pos, {3, 1})
  end

  defp demote(state, key, pos) do
    :ets.update_element(state.data_table, key, {3, 0})
    :ets.update_element(state.clock_table, pos, {3, 0})
  end
end
