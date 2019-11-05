defmodule Tsaas.Graph do
  defmodule Node do
    @enforce_keys [:name, :command, :edges_to]
    defstruct [:name, :command, :edges_to]

    def new(%{"name" => name, "command" => command} = task) do
      %__MODULE__{
        name: name,
        command: command,
        edges_to: task |> Map.get("requires", []) |> Enum.uniq()
      }
    end

    def to_result(%Node{name: name, command: command}) do
      %{name: name, command: command}
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

  defp add_task(task, {graph, repeated}) do
    if Map.has_key?(graph, task["name"]) do
      {graph, [task["name"] | repeated]}
    else
      task
      |> Node.new()
      |> (&Map.put_new(graph, &1.name, &1)).()
      |> (&{&1, repeated}).()
    end
  end

  def validate_edges(graph) when is_map(graph) do
    edges_ends =
      graph
      |> Map.values()
      |> Enum.flat_map(& &1.edges_to)
      |> Enum.into(MapSet.new())

    all_nodes =
      graph
      |> all_node_names()
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

  defp all_node_names(graph) do
    Map.keys(graph)
  end

  def order(graph) when is_map(graph) do
    do_order(graph, []) |> IO.inspect()
  end

  defguardp is_empty(graph) when map_size(graph) == 0

  defp do_order(graph, ordered) when is_empty(graph) do
    {:ok, Enum.reverse(ordered)}
  end

  defp do_order(graph, ordered) do
    [{_, current_node}] = Enum.take(graph, 1)

    case travers(graph, current_node, MapSet.new(), ordered) do
      {graph, ordered} ->
        do_order(graph, ordered)

      :error ->
        :cyclic_dependency_error
    end
  end

  defp travers(graph, current_node, marked, ordered) do
    cond do
      MapSet.member?(marked, current_node.name) ->
        :error

      true ->
        travers_children(
          graph,
          current_node.edges_to,
          MapSet.put(marked, current_node.name),
          ordered
        )
        |> case do
          :error ->
            :error

          {graph, ordered} ->
            {Map.delete(graph, current_node.name), [Node.to_result(current_node) | ordered]}
        end
    end
  end

  defp travers_children(graph, [], _marked, ordered), do: {graph, ordered}

  defp travers_children(graph, [next_node_name | rest], marked, ordered) do
    cond do
      not Map.has_key?(graph, next_node_name) ->
        travers_children(graph, rest, marked, ordered)

      true ->
        current_node = Map.get(graph, next_node_name)

        travers(graph, current_node, marked, ordered)
        |> case do
          :error ->
            :error

          {graph, ordered} ->
            travers_children(graph, rest, marked, ordered)
        end
    end
  end
end
