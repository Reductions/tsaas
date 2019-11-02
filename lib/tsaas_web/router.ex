defmodule TsaasWeb.Router do
  use TsaasWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/topsort", TsaasWeb do
    pipe_through :api

    post "/as-json", OrderingController, :as_json
    post "/as-bash", OrderingController, :as_bash
  end
end
