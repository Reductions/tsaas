defmodule Tsaas.Graph.Node do
  @moduledoc """
  Struct defining a graph node and function that work with it.
  """

  @enforce_keys [:name, :command, :edges_to]
  defstruct [:name, :command, :edges_to]

  @doc """
  Creates new node given a task.

  It adds empty edges list if it does not exist.
  """
  def new(%{"name" => name, "command" => command} = task) do
    %__MODULE__{
      name: name,
      command: command,
      edges_to: task |> Map.get("requires", []) |> Enum.uniq()
    }
  end

  @doc """
  Converts a node to a map that is suitable for the json response.
  """
  def to_result(%__MODULE__{name: name, command: command}) do
    %{name: name, command: command}
  end
end
