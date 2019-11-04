defmodule TsaasWeb.OrderController do
  use TsaasWeb, :controller

  def order(conn, %{"format" => "json"} = body) do
    json(conn, body["tasks"])
  end

  def order(conn, %{"format" => "bash"} = body) do
    text(conn, inspect(body["tasks"]))
  end

  def order(conn, %{"format" => x}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{details: "Format '#{x}' is not supported!"}})
  end
end
