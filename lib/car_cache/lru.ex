defmodule CarCache.LRU do
  @moduledoc """
  Datastructure to represent a LRU list.

  The structure is approximated with the :queue module.

  It is O(1) complexity for most operations with the exception of member/2
  """

  defstruct size: 0,
            queue: nil

  @type t :: %__MODULE__{
          size: non_neg_integer(),
          queue: :queue.queue()
        }

  @doc """
  Return a new/empty LRU list
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      size: 0,
      queue: :queue.new()
    }
  end

  @doc """
  Drop the the item at the head (the item that has been in the list the longest) of the list
  """
  @spec drop(t()) :: t()
  def drop(lru) do
    %__MODULE__{lru | queue: :queue.drop(lru.queue), size: lru.size - 1}
  end

  @doc """
  Check if the given key is a membor of the list
  """
  @spec member?(t(), any()) :: boolean()
  def member?(lru, key) do
    :queue.member(key, lru.queue)
  end

  @doc """
  Insert an item at the tail of the list
  """
  @spec insert(t(), any()) :: t()
  def insert(lru, key) do
    queue = :queue.filter(&(&1 != key), lru.queue)
    queue = :queue.in(key, queue)
    %__MODULE__{lru | queue: queue, size: lru.size + 1}
  end

  @doc """
  Remove an item from the list
  """
  @spec delete(t(), any()) :: t()
  def delete(lru, key) do
    queue = :queue.filter(&(&1 != key), lru.queue)

    size =
      case queue == lru.queue do
        true -> lru.size
        false -> lru.size - 1
      end

    %__MODULE__{lru | queue: queue, size: size}
  end
end
