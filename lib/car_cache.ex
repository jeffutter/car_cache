defmodule CarCache do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  use GenServer

  alias CarCache.Cache

  @options_schema [
    name: [
      type: :atom,
      required: true
    ],
    max_size: [
      type: :non_neg_integer,
      required: true
    ]
  ]

  # Public Functions

  @doc """
  Starts a new cache.

  Options:
  #{NimbleOptions.docs(@options_schema)}
  """
  def start_link(opts) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    cache = Cache.new(opts[:name], opts)

    {:ok, %{cache: cache}}
  end

  @doc """
  Insert a value into the cache under a given key


  ## Example

  ```
  CarCache.put(:my_cache, user_id, profile)
  ```
  """
  @spec put(atom(), any(), any()) :: :ok
  def put(name, key, value) do
    GenServer.call(name, {:put, key, value})
  end

  @doc """
  Get a value from the cache, if it exists in the cache

  ## Example

  ```
  CarCache.get(:my_cache, user_id)
  ```
  """
  @spec get(atom(), any()) :: any()
  def get(name, key) do
    Cache.get(name, key)
  end

  @doc """
  Fetches the value from the cache if it exists, otherwise executes `fallback`.

  The fallback function can return either `{:commit, any()}` or
  `{:ignore, any()}`. If `{:commit, any()}` is returned, the value will be
  stored in the cache

  ## Example

  ```
  CarCache.get(:my_cache, user_id, fn ->
    case Profile.get(user_id) do
      {:ok, profile} -> {:commit, profile}
      {:error, _reason} = error -> {:ignore, error}
    end
  end)
  ```
  """
  @spec fetch(atom(), any(), (() -> {:commit, any()} | {:ignore, any()})) :: any()
  def fetch(name, key, fallback) do
    with nil <- get(name, key) do
      case fallback.() do
        {:commit, value} ->
          put(name, key, value)
          value

        {:ignore, value} ->
          value
      end
    end
  end

  # Callbacks

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    cache = Cache.put(state.cache, key, value)
    {:reply, :ok, %{state | cache: cache}}
  end
end
