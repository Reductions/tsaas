defmodule TsaasWeb.Router do
  use TsaasWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/order", TsaasWeb do
    pipe_through :api

    post "/:format", OrderController, :order
  end
end
