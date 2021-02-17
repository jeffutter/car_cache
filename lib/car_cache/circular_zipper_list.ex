defmodule CarCache.CircularZipperList do
  @doc """
  A simple functional zipper list used to approzimate a circular buffer.

  Based on: https://ferd.ca/yet-another-article-on-zippers.html
  """

  @type t :: {list(), list()}

  @spec new :: t()
  def new, do: {[], []}

  @spec next(t()) :: t()
  def next({[], [h]}), do: {[], [h]}
  def next({pre, [h]}), do: {[h], Enum.reverse(pre)}
  def next({pre, [h | t]}), do: {[h | pre], t}

  @spec prev(t()) :: t()
  def prev({[h], post}), do: {Enum.reverse(post), [h]}
  def prev({[h | t], post}), do: {t, [h | post]}

  @spec value(t()) :: any()
  def value({[], []}), do: nil
  def value({_, [cur | _]}), do: cur

  @spec remove(t()) :: t()
  def remove({[], []}), do: {[], []}
  def remove({pre, [_]}), do: {[], Enum.reverse(pre)}
  def remove({pre, [_ | post]}), do: {pre, post}

  @spec insert(t(), any()) :: t()
  def insert({pre, post}, val), do: {pre, [val | post]}

  @spec len(t) :: non_neg_integer()
  def len({pre, post}), do: length(pre) + length(post)

  @spec replace(t(), any) :: t()
  def replace({[], []}, val), do: insert({[], []}, val)
  def replace({pre, [_ | post]}, val), do: {pre, [val | post]}
end
