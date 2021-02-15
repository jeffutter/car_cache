defmodule CarCache.Clock do
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

  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, 1_000)

    data_name = :"#{name}_data"
    clock_name = :"#{name}_clock"

    data_table = :ets.new(data_name, [:named_table, :set, :protected, {:read_concurrency, true}])
    clock_table = :ets.new(clock_name, [:named_table, :ordered_set, :protected])

    for i <- 1..max_size do
      :ets.insert(clock_table, {i, nil, 0})
    end

    %__MODULE__{
      max_size: max_size,
      size: 0,
      data_name: data_name,
      clock_name: clock_name,
      data_table: data_table,
      clock_table: clock_table
    }
  end

  @spec get(t(), any()) :: any()
  def get(clock, key) do
    case :ets.lookup(clock.data_table, key) do
      [] ->
        nil

      [{^key, value, 0, pos}] ->
        promote(clock, key, value, pos)
        value

      [{^key, value, 1, _pos}] ->
        value
    end
  end

  @spec pop(t()) :: {any(), any(), 0 | 1, t()}
  def pop(clock) do
    p = clock.position

    case :ets.lookup(clock.clock_table, p) do
      [{^p, key, ref_bit}] when ref_bit == 0 or ref_bit == 1 ->
        [{^key, value, ^ref_bit, ^p}] = :ets.lookup(clock.data_table, key)

        :ets.delete(clock.data_table, key)
        :ets.insert(clock.clock_table, {p, nil, 0})

        {key, value, ref_bit, %__MODULE__{clock | position: p + 1, size: clock.size - 1}}
    end
  end

  @spec member?(t(), any()) :: boolean()
  def member?(clock, key) do
    :ets.member(clock.data_table, key)
  end

  @spec size(t()) :: non_neg_integer()
  def size(clock) do
    clock.size
  end

  @spec promote(t(), any(), any(), non_neg_integer()) :: t()
  def promote(clock, key, value, pos) do
    case :ets.lookup(clock.data_table, key) do
      [{^key, ^value, 0, ^pos}] ->
        promote(clock, key, pos)

        :ok

      _ ->
        :ok
    end

    clock
  end

  @spec insert(t(), any(), any()) :: t()
  def insert(clock, key, value) do
    Enum.reduce_while(
      Stream.map(clock.position..(clock.max_size + clock.position - 1), &rem(&1, clock.max_size)),
      clock,
      fn p, clock ->
        case :ets.lookup(clock.clock_table, p) do
          [{^p, nil, 0}] ->
            insert_at(clock, p, key, value)

            {:halt, %{clock | position: p + 1, size: clock.size + 1}}

          [{^p, old_key, 0}] ->
            :ets.delete(clock.data_table, old_key)

            insert_at(clock, p, key, value)

            {:halt, %{clock | position: p + 1}}

          [{^p, key, 1}] ->
            demote(clock, key, p)

            {:halt, %{clock | position: p + 1}}

          _ ->
            {:cont, %{clock | position: p + 1}}
        end
      end
    )
  end

  defp insert_at(state, pos, key, value) do
    :ets.insert(state.data_table, {key, value, 0, pos})
    :ets.insert(state.clock_table, {pos, key, 0})
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
