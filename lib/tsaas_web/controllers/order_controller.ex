defmodule TsaasWeb.OrderController do
  use TsaasWeb, :controller

  @valid_formats ["json", "bash"]

  def order(conn, %{"format" => format} = params) when format in @valid_formats do
    alias Tsaas.Graph

    with :ok <- validate_request_body(params),
         {:ok, graph} <- Graph.new(params["tasks"]),
         {:ok, ordered} <- Graph.order(graph) do
      send_response(conn, ordered, format)
    else
      {:validation_error, reason} ->
        send_error(conn, format, :bad_request, reason)

      {:repeated_names_error, repeated} ->
        send_error(conn, format, :bad_request, format_repeated_names_error(repeated))

      {:invalid_edge_error, invalid_list} ->
        send_error(conn, format, :bad_request, format_invalid_edges(invalid_list))

      :cyclic_dependency_error ->
        send_error(conn, format, :bad_request, "There is cyclic dependency between the tasks.")
    end
  end

  def order(conn, %{"format" => format}) do
    send_error(conn, "json", :not_found, "Format '#{format}' is not supported!")
  end

  defp send_response(conn, ordered, "json") do
    json(conn, ordered)
  end

  defp send_response(conn, ordered, "bash") do
    text(conn, bash_response(ordered))
  end

  @request_schema %{
    "type" => "object",
    "properties" => %{
      "tasks" => %{
        "type" => "array",
        "items" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "command" => %{"type" => "string"},
            "requires" => %{
              "type" => "array",
              "items" => %{"type" => "string"}
            }
          },
          "required" => ["name", "command"]
        }
      }
    },
    "required" => ["tasks"]
  }

  defp validate_request_body(body) do
    case ExJsonSchema.Validator.validate(@request_schema, body) do
      :ok ->
        :ok

      {:error, reasons} ->
        {:validation_error, Enum.map(reasons, &foramt_validation_error/1)}
    end
  end

  defp foramt_validation_error({text, path}) do
    %{reason: text, path: path}
  end

  defp format_repeated_names_error(names) do
    %{reason: "There is more then one task with the same name.", names: names}
  end

  defp format_invalid_edges(names) do
    %{reason: "There are tasks that require nonexistent tasks.", nonexistent: names}
  end

  defp send_error(conn, format, error, message) do
    error_message = %{error: %{details: message}}

    conn
    |> put_status(error)
    |> (case format do
          "json" ->
            &json(&1, error_message)

          "bash" ->
            &text(&1, bash_error(error_message))
        end).()
  end

  @bash_header """
  #!/usr/bin/env bash

  """

  defp bash_error(error_message) do
    [@bash_header, ">&2 echo ", Jason.encode!(error_message), "\nexit 1"]
  end

  defp bash_response(tasks) do
    [
      @bash_header,
      tasks
      |> Enum.map(fn task -> task[:command] end)
      |> Enum.join("\n"),
      "\n"
    ]
  end
end
