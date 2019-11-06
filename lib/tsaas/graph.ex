defmodule Tsaas.Graph do
  @moduledoc """
  Functions for working a graph.

  The graph structure is kept in a simple map.
  """
  alias Tsaas.Graph.Node

  @doc """
  Creates new graph given a list of tasks.

  It also validates if we have a proper graph:
    * it has no more then one node with the same name
    * it has no edge that ends in a nonexistent node
  """
  def new(tasks) when is_list(tasks) do
    tasks
    |> Enum.reduce({%{}, []}, &add_task/2)
    |> case do
      {graph, []} ->
        validate_edges(graph)

      {_, repeated} ->
        {:repeated_names_error, Enum.uniq(repeated)}
    end
  end

  @doc """
  Validates that the graph is a DAG (Directed Acyclic Graph) and Topologically sorts the graph given.
  """
  def order(graph) when is_map(graph) do
    do_order(graph, [])
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

  defp validate_edges(graph) when is_map(graph) do
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
           {:ok, graph}

         invalid_list ->
           {:invalid_edge_error, invalid_list}
       end
  end

  defguardp is_empty(graph) when map_size(graph) == 0

  defp all_node_names(graph) do
    Map.keys(graph)
  end

  defp do_order(graph, ordered) when is_empty(graph) do
    {:ok, Enum.reverse(ordered)}
  end

  defp do_order(graph, ordered) do
    [{_, current_node}] = Enum.take(graph, 1)

    case traverse(graph, current_node, MapSet.new(), ordered) do
      {graph, ordered} ->
        do_order(graph, ordered)

      :error ->
        :cyclic_dependency_error
    end
  end

  defp traverse(graph, current_node, marked, ordered) do
      if MapSet.member?(marked, current_node.name) do
        # If the current node we traverse is marked we have a cycle in the graph.
        :error
      else
        # Else traverse all children marking the current node.
        traverse_children(
          graph,
          current_node.edges_to,
          MapSet.put(marked, current_node.name),
          ordered
        )
        |> case do
          :error ->
            :error
          # When a node is finished we delete it from the graph as we will never traverse it again
          {graph, ordered} ->
            {Map.delete(graph, current_node.name), [Node.to_result(current_node) | ordered]}
        end
    end
  end

  defp traverse_children(graph, [], _marked, ordered), do: {graph, ordered}

  defp traverse_children(graph, [next_node_name | rest], marked, ordered) do
    if Map.has_key?(graph, next_node_name) do
      current_node = Map.get(graph, next_node_name)

      traverse(graph, current_node, marked, ordered)
      |> case do
           :error ->
             :error

           {graph, ordered} ->
             traverse_children(graph, rest, marked, ordered)
         end
    else
      # Next child has already been finished we continue.
      traverse_children(graph, rest, marked, ordered)
    end
  end
end
