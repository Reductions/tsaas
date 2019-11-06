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
                 "details" => %{
                   "nonexistent" => ["not-a-task"],
                   "reason" => "There are tasks that require nonexistent tasks."
                 }
               }
             } = json_response(conn, 400)
    end

    @tag request: %{
           "tasks" => [
             %{"command" => "echo 1", "name" => "task1", "requires" => ["task2"]},
             %{"command" => "echo 2", "name" => "task2", "requires" => ["task1"]}
           ]
         }
    test "response with 400 when tasks with cyclic dependency", %{conn: conn} do
      assert %{"error" => %{"details" => "There is cyclic dependency between the tasks."}} =
               json_response(conn, 400)
    end

    @tag request: %{"tasks" => []}
    test "response with 200 and orders properly 0 tasks", %{conn: conn} do
      assert [] = json_response(conn, 200)
    end

    @tag request: %{"tasks" => [%{"name" => "task", "command" => "echo 1"}]}
    test "response with 200 and orders properly 1 tasks", %{conn: conn} do
      assert [%{"name" => "task", "command" => "echo 1"}] == json_response(conn, 200)
    end

    @tag request: %{
           "tasks" => [
             %{"name" => "task1", "command" => "echo 1"},
             %{"name" => "task2", "command" => "echo 2", "requires" => ["task1"]}
           ]
         }
    test "response with 200 and orders properly 2 tasks", %{conn: conn} do
      assert [
               %{"name" => "task1", "command" => "echo 1"},
               %{"name" => "task2", "command" => "echo 2"}
             ] == json_response(conn, 200)
    end

    @tag request: %{
           "tasks" => [
             %{"name" => "task1", "command" => "touch /tmp/file1"},
             %{"name" => "task2", "command" => "cat /tmp/file1", "requires" => ["task3"]},
             %{
               "name" => "task3",
               "command" => "echo 'Hello World!' >> /tmp/file1",
               "requires" => ["task1"]
             },
             %{"name" => "task4", "command" => "rm /tmp/file1", "requires" => ["task2", "task3"]}
           ]
         }
    test "response with 200 and orders properly more then 2 tasks", %{conn: conn} do
      assert [
               %{"name" => "task1", "command" => "touch /tmp/file1"},
               %{"name" => "task3", "command" => "echo 'Hello World!' >> /tmp/file1"},
               %{"name" => "task2", "command" => "cat /tmp/file1"},
               %{"name" => "task4", "command" => "rm /tmp/file1"}
             ] == json_response(conn, 200)
    end

    @tag request: %{
           "tasks" => [
             %{"name" => "task1", "command" => "echo 'Starting!'"},
             %{
               "name" => "task2.1",
               "command" => "echo 'Hello ' >> /tmp/file1",
               "requires" => ["task1"]
             },
             %{
               "name" => "task2.2",
               "command" => "echo 'World!' >> /tmp/file2",
               "requires" => ["task1"]
             },
             %{
               "name" => "task3",
               "command" => "cat /tmp/file1 /tmp/file2",
               "requires" => ["task2.1", "task2.2"]
             },
             %{
               "name" => "task4",
               "command" => "rm /tmp/file1 /tmp/file2",
               "requires" => ["task3"]
             }
           ]
         }
    test "response with 200 and orders properly more then 2 tasks with 2 independent tasks", %{
      conn: conn
    } do
      assert [
               %{"name" => "task1", "command" => "echo 'Starting!'"},
               _,
               _,
               %{"name" => "task3", "command" => "cat /tmp/file1 /tmp/file2"},
               %{"name" => "task4", "command" => "rm /tmp/file1 /tmp/file2"}
             ] = json_response(conn, 200)
    end
  end

  describe "post order/bash" do
    setup :send_request
    @bash_header """
    #!/usr/bin/env bash
    """
    @moduletag format: "bash"

    @tag request: %{}
    test "response with 400 when no 'tasks' property is given in the body", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#"|
    end

    @tag request: %{"tasks" => "task1"}
    test "response with 400 when 'tasks' is not array", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks"|
    end

    @tag request: %{"tasks" => [%{"command" => "whatever"}]}
    test "response with 400 when 'tasks' contains object without 'name'", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks/0"|
    end

    @tag request: %{"tasks" => [%{"command" => "echo test", "name" => 23}]}
    test "response with 400 when 'tasks' contains object with 'name' that is not string", %{
      conn: conn
    } do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks/0/name"|
    end

    @tag request: %{"tasks" => [%{"name" => "task1"}]}
    test "response with 400 when 'tasks' contains object without 'command'", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks/0"|
    end

    @tag request: %{"tasks" => [%{"command" => [], "name" => "task1"}]}
    test "response with 400 when 'tasks' contains object with 'command' that is not string", %{
      conn: conn
    } do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks/0/command"|
    end

    @tag request: %{
           "tasks" => [%{"command" => "echo test", "name" => "task1", "requires" => "something"}]
         }
    test "response with 400 when 'tasks' contains object with 'requires' that is not array", %{
      conn: conn
    } do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks/0/requires"|
    end

    @tag request: %{
           "tasks" => [%{"command" => "echo test", "name" => "task1", "requires" => [2.3]}]
         }
    test "response with 400 when 'tasks' contains object with 'requires' that has element different then string",
         %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"path":"#/tasks/0/requires/0"|
    end

    @tag request: %{
           "tasks" => [
             %{"command" => "echo test", "name" => "task1"},
             %{"command" => "echo again", "name" => "task1"}
           ]
         }
    test "response with 400 when 2 tasks with the same names are given", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"There is more then one task with the same name."|
      assert response =~ ~s|"task1"|
    end

    @tag request: %{"tasks" => [%{"command" => "echo test", "name" => "task1", "requires" => ["not-a-task"]}]}
    test "response with 400 when 'tasks' contains a task that requires a nonexistent task", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"There are tasks that require nonexistent tasks."|
      assert response =~ ~s|"not-a-task"|
    end

    @tag request: %{
           "tasks" => [
             %{"command" => "echo 1", "name" => "task1", "requires" => ["task2"]},
             %{"command" => "echo 2", "name" => "task2", "requires" => ["task1"]}
           ]
         }
    test "response with 400 when tasks with cyclic dependency", %{conn: conn} do
      response = text_response(conn, 400)
      assert response =~ ~s|"error"|
      assert response =~ ~s|"There is cyclic dependency between the tasks."|
    end

    @tag request: %{"tasks" => []}
    test "response with 200 and orders properly 0 tasks", %{conn: conn} do
      response = text_response(conn, 200)
      assert response == """
      #{@bash_header}

      """
    end

    @tag request: %{"tasks" => [%{"name" => "task", "command" => "echo 1"}]}
    test "response with 200 and orders properly 1 tasks", %{conn: conn} do
      response = text_response(conn, 200)
      assert response == """
      #{@bash_header}
      echo 1
      """
    end

    @tag request: %{
           "tasks" => [
             %{"name" => "task1", "command" => "echo 1"},
             %{"name" => "task2", "command" => "echo 2", "requires" => ["task1"]}
           ]
         }
    test "response with 200 and orders properly 2 tasks", %{conn: conn} do
      response = text_response(conn, 200)
      assert response == """
      #{@bash_header}
      echo 1
      echo 2
      """
    end

    @tag request: %{
           "tasks" => [
             %{"name" => "task1", "command" => "touch /tmp/file1"},
             %{"name" => "task2", "command" => "cat /tmp/file1", "requires" => ["task3"]},
             %{
               "name" => "task3",
               "command" => "echo 'Hello World!' >> /tmp/file1",
               "requires" => ["task1"]
             },
             %{"name" => "task4", "command" => "rm /tmp/file1", "requires" => ["task2", "task3"]}
           ]
         }
    test "response with 200 and orders properly more then 2 tasks", %{conn: conn} do
      response = text_response(conn, 200)
      assert response == """
      #{@bash_header}
      touch /tmp/file1
      echo 'Hello World!' >> /tmp/file1
      cat /tmp/file1
      rm /tmp/file1
      """
    end

    @tag request: %{
           "tasks" => [
             %{"name" => "task1", "command" => "echo 'Starting!'"},
             %{
               "name" => "task2.1",
               "command" => "echo 'Hello ' >> /tmp/file1",
               "requires" => ["task1"]
             },
             %{
               "name" => "task2.2",
               "command" => "echo 'World!' >> /tmp/file2",
               "requires" => ["task1"]
             },
             %{
               "name" => "task3",
               "command" => "cat /tmp/file1 /tmp/file2",
               "requires" => ["task2.1", "task2.2"]
             },
             %{
               "name" => "task4",
               "command" => "rm /tmp/file1 /tmp/file2",
               "requires" => ["task3"]
             }
           ]
         }
    test "response with 200 and orders properly more then 2 tasks with 2 independent tasks", %{conn: conn} do
      response = text_response(conn, 200)

      expected_begin = """
      #{@bash_header}
      echo 'Starting!'
      """
      assert String.starts_with?(response, expected_begin)

      expected_end = """
      cat /tmp/file1 /tmp/file2
      rm /tmp/file1 /tmp/file2
      """
      assert String.ends_with?(response, expected_end)

      assert response =~ "echo 'Hello ' >> /tmp/file1"
      assert response =~ "echo 'World!' >> /tmp/file2"
    end
  end

  defp send_request(%{conn: conn, request: req, format: format}) do
    {:ok, conn: post(conn, Routes.order_path(conn, :order, format), req)}
  end
end
