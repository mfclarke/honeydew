defmodule Honeydew.Queue do
  alias Honeydew.Job

  @doc "Initializes the job queue, expects `{:ok, queue}` and passes the `queue` to subsequent queue functions."
  @callback init(name :: String.t) :: {:ok, any}

  @doc "Pushes a job onto the queue, expects `{:ok, queue}`"
  @callback push(queue :: any, job :: Job.t) :: {:ok, any}

  @doc "Dequeues the next job to be processed, expects {:ok, queue, job} or :empty"
  @callback pop(queue :: any) :: {:ok, any, Job.t} | :empty
end
