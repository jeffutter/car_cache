defmodule CarCache.Clock do
  alias CarCache.CircularZipperList

  defstruct name: nil,
            size: 0,
            data_table: nil,
            czl: CircularZipperList.new()

  @type t :: %__MODULE__{
          name: atom(),
          size: non_neg_integer(),
          data_table: :ets.tid(),
          czl: CircularZipperList.t()
        }

  @spec new(atom(), :ets.tid(), Keyword.t()) :: t()
  def new(name, data_table, _opts \\ []) do
    %__MODULE__{
      name: name,
      size: 0,
      data_table: data_table,
      czl: CircularZipperList.new()
    }
  end

  @spec pop(t()) :: {any(), any(), 0 | 1, t()}
  def pop(clock) do
    name = clock.name
    key = CircularZipperList.value(clock.czl)
    [{^key, value, ^name, ref_bit}] = :ets.lookup(clock.data_table, key)

    :ets.delete(clock.data_table, key)

    czl = CircularZipperList.remove(clock.czl)

    {key, value, ref_bit, %__MODULE__{clock | czl: czl, size: clock.size - 1}}
  end

  @spec member?(t(), any()) :: boolean()
  def member?(clock, key) do
    name = clock.name

    case :ets.lookup(clock.data_table, key) do
      [{^key, _value, ^name, _ref_bit}] -> true
      _ -> false
    end
  end

  @spec size(t()) :: non_neg_integer()
  def size(clock) do
    clock.size
  end

  @spec insert(t(), any(), any()) :: t()
  def insert(clock, key, value) do
    czl = CircularZipperList.insert(clock.czl, key)
    czl = CircularZipperList.next(czl)
    :ets.insert(clock.data_table, {key, value, clock.name, 0})

    %__MODULE__{clock | czl: czl, size: clock.size + 1}
  end
end
