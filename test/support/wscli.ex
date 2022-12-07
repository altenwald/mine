defmodule Mine.WSCLI do
  @moduledoc false
  use WebSockex
  import ExUnit.Assertions

  @doc false
  def send_ws_json(pid, data) do
    WebSockex.cast(pid, {:text, Jason.encode!(data)})
  end

  def send_ping(pid) do
    WebSockex.cast(pid, :ping)
  end

  @doc false
  def connect_ws(url) do
    WebSockex.start_link(url, __MODULE__, self())
  end

  @doc false
  def disconnect_ws(pid) do
    WebSockex.cast(pid, :stop)
  end

  @doc false
  def handle_frame(frame, pid) do
    send(pid, frame)
    {:ok, pid}
  end

  @doc false
  def handle_cast(:stop, pid) do
    {:close, pid}
  end

  def handle_cast(frame, pid) do
    {:reply, frame, pid}
  end

  @doc false
  defmacro assert_ws_json_receive(expression, timeout \\ 100) do
    quote do
      assert_receive {:text, msg},
                     unquote(timeout),
                     "Not matching expression\ninbox: #{inspect(recv_all([]))}"

      assert unquote(expression) = Jason.decode!(msg)
    end
  end

  @doc false
  def recv_all(msgs) do
    receive do
      msg -> recv_all([msg | msgs])
    after
      0 -> msgs
    end
  end

  @doc false
  defmacro assert_ws_text_receive(expression, timeout \\ 100) do
    quote do
      assert_receive {:text, unquote(expression)},
                     unquote(timeout),
                     "Not matching expression\ninbox: #{inspect(recv_all([]))}"
    end
  end
end
