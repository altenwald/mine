defmodule Mine.WSCLI do
  @moduledoc false
  use WebSockex

  @doc false
  defdelegate cast(pid, frame), to: WebSockex

  @doc false
  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, self())
  end

  @doc false
  def handle_frame(frame, pid) do
    send(pid, frame)
    {:ok, pid}
  end

  @doc false
  def handle_cast(frame, pid) do
    {:reply, frame, pid}
  end
end
