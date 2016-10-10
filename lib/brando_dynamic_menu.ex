defmodule Brando.DynamicMenu do
  use GenServer

  @registry_filename "token.ets"

  defmodule State do
    defstruct menus: %{}
  end

  defmodule MenuItem do
    defstruct name: nil,
              url: nil,
              parent: nil,
              children: []
  end

  # Public
  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    require Logger
    Logger.info("==> Brando.DynamicMenu initialized")
    {:ok, %State{}}
  end

  def state do
    GenServer.call(__MODULE__, :state)
  end

  def register_menu(language, items \\ []) do
    GenServer.call(__MODULE__, {:register_menu, language, items})
  end

  def register_item(language, %MenuItem{} = item) do
    GenServer.call(__MODULE__, {:register_item, language, item})
  end

  def register_child(language, menu_item_name, %MenuItem{} = item) do
    GenServer.call(__MODULE__, {:register_child, language, menu_item_name, item})
  end

  def set_state(new_state) do
    GenServer.call(__MODULE__, {:set_state, new_state})
  end

  def wipe do
    GenServer.call(__MODULE__, :wipe)
  end

  def save do
    File.mkdir_p!(registry_path)
    current_state = state()
    binary_state = :erlang.term_to_binary(current_state)
    :ok = File.write(registry_file(), binary_state)
  end

  def load do
    case File.read(registry_file()) do
      {:ok, saved_state} ->
        new_state = :erlang.binary_to_term(saved_state)
        set_state(new_state)
      {:error, _} ->
        nil
    end
  end

  def get_menu(language) do
    Map.get(state().menus, language, nil)
  end

  def try_it do
    start_link
    register_menu(:en)
    register_item(:en, %MenuItem{name: "Pages"})
    register_item(:en, %MenuItem{name: "About"})
    register_child(:en, "About", %MenuItem{name: "About CHILD"})
    register_child(:en, "About", %MenuItem{name: "About CHILD 2"})
  end

  # Private
  @doc false
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @doc false
  def handle_call(:wipe, _, _) do
    {:reply, %State{}, %State{}}
  end

  @doc false
  def handle_call({:set_state, new_state}, _from, state) do
    {:reply, new_state, new_state}
  end

  @doc false
  def handle_call({:register_menu, language, items}, _from, state) do
    state = put_in(state.menus, Map.put(state.menus, language, items))
    {:reply, state, state}
  end

  @doc false
  def handle_call({:register_item, language, item}, _from, state) do
    current_menus = Map.get(state.menus, language)
    state = put_in(state.menus[language], current_menus ++ [item])
    {:reply, state, state}
  end

  @doc false
  def handle_call({:register_child, language, menu_item_name, item}, _from, state) do
    menus      = Map.get(state.menus, language)
    menu_index = Enum.find_index(menus, &(&1.name == menu_item_name))
    menu       = Enum.at(menus, menu_index)
    new_menu   = Map.put(menu, :children, menu.children ++ [item])
    new_menus  = List.replace_at(menus, menu_index, new_menu)
    state      = put_in(state.menus[language], new_menus)

    {:reply, state, state}
  end

  @doc """
  Grab `key` from config
  """
  def config(key) do
    Application.get_env(:brando_dynamic_menu, key)
  end

  defp registry_path, do:
    Application.app_dir(config(:otp_app), config(:registry_path))

  defp registry_file, do:
    Path.join([registry_path(), @registry_filename])
end
