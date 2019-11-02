defmodule TsaasWeb.OrderingController do
  use TsaasWeb, :controller

  def as_json(conn, body) do
    json(conn, body)
  end

  def as_bash(conn, body) do
    text(conn, inspect(body))
  end
end
