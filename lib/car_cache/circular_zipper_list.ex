defmodule CarCache.CircularZipperList do
  @moduledoc """
  A simple functional zipper list used to approximate a circular buffer.

  Based on: https://ferd.ca/yet-another-article-on-zippers.html
  """

  @type t :: {list(), list()}

  @doc """
  Create a new/empty circular zipper list
  """
  @spec new :: t()
  def new, do: {[], []}

  @doc """
  Move the cursor to the next item in the list
  """
  @spec next(t()) :: t()
  def next({[], [h]}), do: {[], [h]}
  def next({pre, [h]}), do: {[h], Enum.reverse(pre)}
  def next({pre, [h | t]}), do: {[h | pre], t}

  @doc """
  Move the cursor to the previous item in the list
  """
  @spec prev(t()) :: t()
  def prev({[h], post}), do: {Enum.reverse(post), [h]}
  def prev({[h | t], post}), do: {t, [h | post]}

  @doc """
  Get the value at the current cursor
  """
  @spec value(t()) :: any()
  def value({[], []}), do: nil
  def value({_, [cur | _]}), do: cur

  @doc """
  Remove the value at the current cursor
  """
  @spec remove(t()) :: t()
  def remove({[], []}), do: {[], []}
  def remove({pre, [_]}), do: {[], Enum.reverse(pre)}
  def remove({pre, [_ | post]}), do: {pre, post}

  @doc """
  Insert a value before the current cursor and set the cursor to the new value
  """
  @spec insert(t(), any()) :: t()
  def insert({pre, post}, val), do: {pre, [val | post]}

  @doc """
  Get the length of the entire list
  """
  @spec len(t) :: non_neg_integer()
  def len({pre, post}), do: length(pre) + length(post)

  @doc """
  Replace the value at the current cursor
  """
  @spec replace(t(), any) :: t()
  def replace({[], []}, val), do: insert({[], []}, val)
  def replace({pre, [_ | post]}, val), do: {pre, [val | post]}
end
