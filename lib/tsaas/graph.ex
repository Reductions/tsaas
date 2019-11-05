defmodule Tsaas.Graph do
  defmodule Node do
    @enforce_keys [:id, :command, :edges_to]
    defstruct [:id, :command, :edges_to]

    def new(%{"name" => id, "command" => command} = task) do
      %__MODULE__{
        id: id,
        command: command,
        edges_to: task |> Map.get("requires", []) |> Enum.into(MapSet.new())
      }
    end
  end

  def new(tasks) when is_list(tasks) do
    tasks
    |> Enum.reduce({%{}, []}, &add_task/2)
    |> case do
      {graph, []} ->
        {:ok, graph}

      {_, repeated} ->
        {:repeated_names_error, Enum.uniq(repeated)}
    end
  end

  def validate_edges(graph) do
    edges_ends =
      graph
      |> Map.values()
      |> Enum.flat_map(& &1.edges_to)
      |> Enum.into(MapSet.new())

    all_nodes =
      graph
      |> Map.keys()
      |> Enum.into(MapSet.new())

    edges_ends
    |> MapSet.difference(all_nodes)
    |> MapSet.to_list()
    |> case do
         [] ->
           :ok
         invalid_list ->
           {:invalid_edge_error, invalid_list}
       end

  end

  defp add_task(task, {graph, repeated}) do
    if Map.has_key?(graph, task["name"]) do
      {graph, [task["name"] | repeated]}
    else
      task
      |> Node.new()
      |> (&Map.put_new(graph, &1.id, &1)).()
      |> (&{&1, repeated}).()
    end
  end
end
