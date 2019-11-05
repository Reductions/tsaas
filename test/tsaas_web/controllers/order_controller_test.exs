defmodule TsaasWeb.OrderControllerTest do
  use TsaasWeb.ConnCase

  test "responds with 404 when format is not 'json' or 'bash'", %{conn: conn} do
    response =
      conn
      |> post(Routes.order_path(conn, :order, "xml"))
      |> json_response(404)

    expected = %{"error" => %{"details" => "Format 'xml' is not supported!"}}

    assert response == expected
  end

  describe "post order/json" do
    setup :send_request

    @moduletag format: "json"

    @tag request: %{}
    test "response with 400 when no 'tasks' property is given in the body", %{conn: conn} do
      assert %{"error" => %{"details" => [%{"path" => "#"}]}} = json_response(conn, 400)
    end

    @tag request: %{"tasks" => "task1"}
    test "response with 400 when 'tasks' is not array", %{conn: conn} do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks"}]}} = json_response(conn, 400)
    end

    @tag request: %{"tasks" => [%{"command" => "whatever"}]}
    test "response with 400 when 'tasks' contains object without 'name'", %{conn: conn} do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks/0"}]}} = json_response(conn, 400)
    end

    @tag request: %{"tasks" => [%{"command" => "echo test", "name" => 23}]}
    test "response with 400 when 'tasks' contains object with 'name' that is not string", %{
      conn: conn
    } do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks/0/name"}]}} =
               json_response(conn, 400)
    end

    @tag request: %{"tasks" => [%{"name" => "task1"}]}
    test "response with 400 when 'tasks' contains object without 'command'", %{conn: conn} do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks/0"}]}} = json_response(conn, 400)
    end

    @tag request: %{"tasks" => [%{"command" => [], "name" => "task1"}]}
    test "response with 400 when 'tasks' contains object with 'command' that is not string", %{
      conn: conn
    } do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks/0/command"}]}} =
               json_response(conn, 400)
    end

    @tag request: %{
           "tasks" => [%{"command" => "echo test", "name" => "task1", "requires" => "something"}]
         }
    test "response with 400 when 'tasks' contains object with 'requires' that is not array", %{
      conn: conn
    } do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks/0/requires"}]}} =
               json_response(conn, 400)
    end

    @tag request: %{
           "tasks" => [%{"command" => "echo test", "name" => "task1", "requires" => [2.3]}]
         }
    test "response with 400 when 'tasks' contains object with 'requires' that has element different then string",
         %{
           conn: conn
         } do
      assert %{"error" => %{"details" => [%{"path" => "#/tasks/0/requires/0"}]}} =
               json_response(conn, 400)
    end

    @tag request: %{
           "tasks" => [
             %{"command" => "echo test", "name" => "task1"},
             %{"command" => "echo again", "name" => "task1"}
           ]
         }
    test "response with 400 when 2 tasks with the same names are given", %{
      conn: conn
    } do
      assert %{
               "error" => %{
                 "details" => %{
                   "names" => ["task1"],
                   "reason" => "There is more then one task with the same name."
                 }
               }
             } = json_response(conn, 400)
    end

    @tag request: %{
           "tasks" => [
             %{"command" => "echo test", "name" => "task1", "requires" => ["not-a-task"]}
           ]
         }
    test "response with 400 when 'tasks' contains a task that requires a nonexistent task",
         %{
           conn: conn
         } do
      assert %{
               "error" => %{
                 "details" =>
                   %{
                     "nonexistent" => ["not-a-task"],
                     "reason" => "There are tasks that require nonexistent tasks."
                   }
               }
             } = json_response(conn, 400)
    end
  end

  defp send_request(%{conn: conn, request: req, format: format}) do
    {:ok, conn: post(conn, Routes.order_path(conn, :order, format), req)}
  end
end
