defmodule CarCache.CLL do
  @type t :: {list(), list()}

  def new do
    {[], []}
  end

  def next({[], []}), do: {[], []}

  def next({visited, []}) do
    [a | remain] = Enum.reverse(visited)
    {[a], remain}
  end

  def next({visited, [a | remain]}) do
    {[a] ++ visited, remain}
  end

  def prev({[], []}), do: {[], []}
  def prev({[], remain}), do: {Enum.reverse(remain), []} |> prev()
  def prev({[a | visited], remain}), do: {visited, [a] ++ remain}

  def value(state, offset \\ 0)

  def value({[], []}, _), do: nil

  def value({_, remain} = state, offset) when offset >= length(remain),
    do: value(state, offset - len(state))

  def value({visited, _} = state, offset) when offset < -length(visited),
    do: value(state, offset + len(state))

  def value({visited, _}, offset) when offset < 0, do: Enum.at(visited, -offset - 1)
  def value({_, remain}, offset), do: Enum.at(remain, offset)

  def remove({[], []}), do: {[], []}
  def remove({visited, []}), do: {Enum.drop(visited, -1), []}
  def remove({visited, [_ | remain]}), do: {visited, remain}

  def insert({visited, remain}, value), do: {[value | visited], remain}

  def len({visited, remain}), do: length(visited) + length(remain)

  def replace({[], []}, _), do: {[], []}
  def replace({visited, []}, value), do: {Enum.drop(visited, -1) ++ [value], []}
  def replace({visited, [_ | remain]}, value), do: {visited, [value | remain]}
end
