defmodule TsaasWeb.OrderController do
  use TsaasWeb, :controller

  @valid_formats ["json", "bash"]

  def order(conn, %{"format" => format} = params) when format in @valid_formats do
    with :ok <- validate_request_body(params) do
      send_response(conn, params)
    else
      {:validation_error, reason} ->
        send_error(conn, :bad_request, reason)
    end
  end

  def order(conn, %{"format" => format}) do
    send_error(conn, :not_found, "Format '#{format}' is not supported!")
  end

  defp send_response(conn, %{"format" => "json"} = body) do
    json(conn, body["tasks"])
  end

  defp send_response(conn, %{"format" => "bash"} = body) do
    text(conn, inspect(body["tasks"]))
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
      :ok -> :ok
      {:error, reasons} ->
        {:validation_error, Enum.map(reasons, &foramt_validation_error/1)}
    end
  end

  defp foramt_validation_error({text, path}) do
    %{reason: text, path: path}
  end

  defp send_error(conn, error, message) do
    conn
    |> put_status(error)
    |> json(%{error: %{details: message}})
  end
end
