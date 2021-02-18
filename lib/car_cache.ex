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

  def start_link(opts) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    cache = Cache.new(opts[:name], opts)

    {:ok, %{cache: cache}}
  end

  def insert(name, key, value) do
    GenServer.call(name, {:insert, key, value})
  end

  def get(name, key) do
    data_name = :"#{name}_data"
    t1_name = :"#{name}_t1"
    t2_name = :"#{name}_t2"

    case :ets.lookup(data_name, key) do
      [{^key, value, ^t1_name, 0}] ->
        :ets.update_element(data_name, key, {4, 1})
        value

      [{^key, value, ^t1_name, 1}] ->
        value

      [{^key, value, ^t2_name, 0}] ->
        :ets.update_element(data_name, key, {4, 1})
        value

      [{^key, value, ^t2_name, 1}] ->
        value

      _ ->
        nil
    end
  end

  # Callbacks

  @impl true
  def handle_call({:insert, key, value}, _from, state) do
    cache = Cache.insert(state.cache, key, value)
    {:reply, :ok, %{state | cache: cache}}
  end
end
