defmodule CarCache.Clock do
  @moduledoc """
  Data structure representing a "CLOCK".

  This implementation uses a circular zipper list to track the clock hand and
  an ETS table to store the data (and for quick lookups.)
  """

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

  @doc """
  Return a new/empty Clock
  """
  @spec new(atom(), :ets.tid(), Keyword.t()) :: t()
  def new(name, data_table, _opts \\ []) do
    %__MODULE__{
      name: name,
      size: 0,
      data_table: data_table,
      czl: CircularZipperList.new()
    }
  end

  @doc """
  Pop the next value after the clock hand
  """
  @spec pop(t()) :: {any(), any(), 0 | 1, t()}
  def pop(clock) do
    name = clock.name
    key = CircularZipperList.value(clock.czl)
    [{^key, value, ^name, ref_bit}] = :ets.lookup(clock.data_table, key)

    :ets.delete(clock.data_table, key)

    czl = CircularZipperList.remove(clock.czl)

    {key, value, ref_bit, %__MODULE__{clock | czl: czl, size: clock.size - 1}}
  end

  @doc """
  Check if the clock contains a given key
  """
  @spec member?(t(), any()) :: boolean()
  def member?(clock, key) do
    name = clock.name

    case :ets.lookup(clock.data_table, key) do
      [{^key, _value, ^name, _ref_bit}] -> true
      _ -> false
    end
  end

  @doc """
  Insert a new key/value behind the clock hand
  """
  @spec insert(t(), any(), any()) :: t()
  def insert(clock, key, value) do
    czl =
      clock.czl
      |> CircularZipperList.insert(key)
      |> CircularZipperList.next()

    :ets.insert(clock.data_table, {key, value, clock.name, 0})

    %__MODULE__{clock | czl: czl, size: clock.size + 1}
  end

  @doc """
  Deletes a given key from the clock without adjusting the clock hand
  """
  @spec delete(t(), any()) :: t()
  def delete(clock, key) do
    name = clock.name
    czl = CircularZipperList.delete(clock.czl, key)

    size =
      case czl == clock.czl do
        true -> clock.size
        false -> clock.size - 1
      end

    [{^key, _value, ^name, _ref_bit}] = :ets.lookup(clock.data_table, key)

    :ets.delete(clock.data_table, key)

    %__MODULE__{clock | czl: czl, size: size}
  end
end
