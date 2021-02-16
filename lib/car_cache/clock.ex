defmodule CarCache.Clock do
  alias CarCache.CLL

  defstruct name: nil,
            size: 0,
            data_table: nil,
            cll: CLL.new()

  @type t :: %__MODULE__{
          name: atom(),
          size: non_neg_integer(),
          data_table: :ets.tid(),
          cll: CLL.t()
        }

  @spec new(atom(), :ets.tid(), Keyword.t()) :: t()
  def new(name, data_table, _opts \\ []) do
    %__MODULE__{
      name: name,
      size: 0,
      data_table: data_table,
      cll: CLL.new()
    }
  end

  @spec pop(t()) :: {any(), any(), 0 | 1, t()}
  def pop(clock) do
    name = clock.name
    key = CLL.value(clock.cll)
    [{^key, value, ^name, ref_bit}] = :ets.lookup(clock.data_table, key)

    :ets.delete(clock.data_table, key)

    cll = CLL.remove(clock.cll)

    {key, value, ref_bit, %__MODULE__{clock | cll: cll, size: clock.size - 1}}
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
    cll = CLL.insert(clock.cll, key)
    cll = CLL.next(cll)
    :ets.insert(clock.data_table, {key, value, clock.name, 0})

    %__MODULE__{clock | cll: cll, size: clock.size + 1}
  end
end
