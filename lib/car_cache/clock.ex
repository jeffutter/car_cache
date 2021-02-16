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

  @spec get(t(), any()) :: {any(), t()}
  def get(clock, key) do
    name = clock.name

    case :ets.lookup(clock.data_table, key) do
      [] ->
        {nil, clock}

      [{^key, value, ^name, 0}] ->
        clock = promote(clock, key)
        {value, clock}

      [{^key, value, ^name, 1}] ->
        {value, clock}
    end
  end

  @spec promote(t(), any()) :: t()
  def promote(clock, key) do
    case CLL.value(clock.cll) do
      {^key, 0} ->
        cll = CLL.replace(clock.cll, {key, 1})
        :ets.update_element(clock.data_table, key, {4, 0})

        %__MODULE__{clock | cll: cll}

      {^key, 1} ->
        clock

      {_other_key, _} ->
        cll = CLL.next(clock.cll)
        clock = %__MODULE__{clock | cll: cll}
        promote(clock, key)
    end
  end

  @spec pop(t()) :: {any(), any(), 0 | 1, t()}
  def pop(clock) do
    name = clock.name
    {key, ref_bit} = CLL.value(clock.cll)
    [{^key, value, ^name, ^ref_bit}] = :ets.lookup(clock.data_table, key)

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
    cll = CLL.insert(clock.cll, {key, 0})
    cll = CLL.next(cll)
    :ets.insert(clock.data_table, {key, value, clock.name, 0})

    %__MODULE__{clock | cll: cll, size: clock.size + 1}
  end

  #   case CLL.value(clock.cll) do
  #     nil ->
  #       cll = CLL.insert(clock.cll, {key, 0})
  #       :ets.insert(clock.data_table, {key, value, 0})

  #       %__MODULE__{clock | cll: cll, size: clock.size + 1}

  #     {old_key, 0} ->
  #       cll = CLL.replace(clock.cll, {key, 0})

  #       :ets.delete(clock.data_table, old_key)
  #       :ets.insert(clock.data_table, {key, value, 0})

  #       %__MODULE__{clock | cll: cll, size: clock.size + 1}

  #     {old_key, 1} ->
  #       :ets.update_element(clock.data_table, old_key, {3, 0})
  #       cll = CLL.replace(clock.cll, {old_key, 0})

  #       clock = %__MODULE__{clock | cll: cll}

  #       insert(clock, key, value)
  #   end
  # end
end
