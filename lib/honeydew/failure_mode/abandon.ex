defmodule Honeydew.FailureMode.Abandon do
  require Logger

  def init(queue_name, _args) do
    {:ok, queue_name}
  end

  def job_failed(queue_name, job) do
    Logger.debug "[Honeydew] #{queue_name} Job failed: #{inspect job}"
    {:ok, nil}
  end
end
