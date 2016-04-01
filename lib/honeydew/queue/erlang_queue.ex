defmodule Honeydew.Queue.ErlangQueue do
  @behaviour Honeydew.Queue

  def init(_name, _args) do
    {:ok, :queue.new}
  end

  def push(queue, job) do
    {:ok, :queue.in(job, queue)}
  end

  def pop(queue) do
    case :queue.out(queue) do
      {{:value, job}, queue} -> {:ok, job, queue}
      {:empty, _} -> :empty
    end
  end

  def length(queue) do
    :queue.len(queue)
  end
end
