defmodule CarCache.LRU do
  defstruct size: 0,
            queue: nil

  @type t :: %__MODULE__{
          size: non_neg_integer(),
          queue: :queue.queue()
        }

  @spec new() :: t()
  def new do
    %__MODULE__{
      size: 0,
      queue: :queue.new()
    }
  end

  @spec drop(t()) :: t()
  def drop(lru) do
    %__MODULE__{lru | queue: :queue.drop(lru.queue), size: lru.size - 1}
  end

  @spec member?(t(), any()) :: boolean()
  def member?(lru, key) do
    :queue.member(key, lru.queue)
  end

  @spec size(t()) :: non_neg_integer()
  def size(lru) do
    lru.size
  end

  @spec insert(t(), any()) :: t()
  def insert(lru, key) do
    queue = :queue.filter(&(&1 == key), lru.queue)
    queue = :queue.in(key, queue)
    %__MODULE__{lru | queue: queue, size: lru.size + 1}
  end
end
