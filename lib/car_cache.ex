defmodule CarCache do
  alias CarCache.Clock
  alias CarCache.LRU

  defstruct c: 1_000,
            name: nil,
            p: 0,
            data: nil,
            t1: nil,
            t2: nil,
            b1: nil,
            b2: nil

  @type t :: %__MODULE__{
          c: non_neg_integer(),
          name: atom(),
          p: non_neg_integer(),
          data: :ets.tid(),
          t1: Clock.t(),
          t2: Clock.t(),
          b1: LRU.t(),
          b2: LRU.t()
        }

  @spec new(atom()) :: t()
  def new(name, opts \\ []) do
    data_name = :"#{name}_data"
    data = :ets.new(data_name, [:named_table, :set, :public, {:read_concurrency, true}])

    %__MODULE__{
      c: Keyword.get(opts, :max_size, 1_000),
      name: name,
      p: 0,
      data: data,
      t1: Clock.new(:"#{name}_t1", data),
      t2: Clock.new(:"#{name}_t2", data),
      b1: LRU.new(),
      b2: LRU.new()
    }
  end

  @spec get(t(), any()) :: any()
  def get(car, key) do
    t1_name = car.t1.name
    t2_name = car.t2.name

    case :ets.lookup(car.data, key) do
      [{^key, value, ^t1_name, 0}] ->
        :ets.update_element(car.data, key, {4, 1})
        value

      [{^key, value, ^t1_name, 1}] ->
        value

      [{^key, value, ^t2_name, 0}] ->
        :ets.update_element(car.data, key, {4, 1})
        value

      [{^key, value, ^t2_name, 1}] ->
        value

      _ ->
        nil
    end
  end

  @spec insert(t(), any(), any()) :: t()
  def insert(car, key, value) do
    case :ets.lookup(car.data, key) do
      [{^key, ^value, _, _}] ->
        car

      [{^key, _value, _, _}] ->
        :ets.update_element(car.data, key, {2, value})
        car

      [] ->
        car =
          if car.t1.size + car.t2.size == car.c do
            # cache full, replace a page from cache
            car = replace(car)
            # cache directory replacement

            cond do
              (!LRU.member?(car.b1, key) || !LRU.member?(car.b2, key)) && car.t1.size + car.b1.size == car.c ->
                # Discard the LRU page in B1.
                b1 = LRU.drop(car.b1)
                %__MODULE__{car | b1: b1}

              car.t1.size + car.t2.size + car.b1.size + car.b2.size == 2 * car.c &&
                  (!LRU.member?(car.b1, key) || !LRU.member?(car.b2, key)) ->
                # Discard the LRU page in B2.
                b2 = LRU.drop(car.b2)
                %__MODULE__{car | b2: b2}

              true ->
                car
            end
          else
            car
          end

        cond do
          # cache directory miss
          !LRU.member?(car.b1, key) && !LRU.member?(car.b2, key) ->
            # Insert x at the tail of T1. Set the page reference bit of x to 0.
            t1 = Clock.insert(car.t1, key, value)
            %__MODULE__{car | t1: t1}

          # cache directory hit
          LRU.member?(car.b1, key) ->
            # Adapt:Increase the target size for the list T1 as:p=min{p+max{1,|B2|/|B1|},c}
            p = min(car.p + max(1, car.b2.size / car.b1.size), car.c)

            car = %__MODULE__{car | p: p}

            # Move x at the tail of T2. Set the page reference bit of x to 0.
            t2 = Clock.insert(car.t2, key, value)
            %__MODULE__{car | t2: t2}

          # cache directory hit
          # x must be in B2
          true ->
            # Adapt:Decrease the target size for the list T1 as:p=max{p−max{1,|B1|/|B2|},0}
            p = max(car.p - max(1, car.b1.size / car.b2.size), 0)

            car = %__MODULE__{car | p: p}

            # Move x at the tail of T2. Set the page reference bit of x to 0.
            t2 = Clock.insert(car.t2, key, value)
            %__MODULE__{car | t2: t2}
        end
    end
  end

  @spec replace(t()) :: t()
  def replace(car) do
    if car.t1.size >= max(1, car.p) do
      case Clock.pop(car.t1) do
        {key, _value, 0, t1} ->
          # Demote the head page in T1 and make it the MRU page in B1.
          b1 = LRU.insert(car.b1, key)
          %__MODULE__{car | b1: b1, t1: t1}

        {key, value, 1, t1} ->
          # Set the page reference bit of head page in T1 to 0, and make it the tail page in T2.
          t2 = Clock.insert(car.t2, key, value)
          replace(%__MODULE__{car | t1: t1, t2: t2})
      end
    else
      case Clock.pop(car.t2) do
        {key, _value, 0, t2} ->
          # Demote the head page in T2 and make it the MRU page in B2.
          LRU.insert(car.b2, key)
          %__MODULE__{car | t2: t2}

        {key, value, 1, t2} ->
          # Set the page reference bit of head page in T2 to 0, and make it the tail page in T2.
          t2 = Clock.insert(t2, key, value)
          replace(%__MODULE__{car | t2: t2})
      end
    end
  end
end
