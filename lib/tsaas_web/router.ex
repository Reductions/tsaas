defmodule TsaasWeb.Router do
  use TsaasWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TsaasWeb do
    pipe_through :api
  end
end
