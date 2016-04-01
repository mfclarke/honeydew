defmodule Honeydew.Queue do
  alias Honeydew.Job

  @doc "Initializes the job queue, expects `{:ok, queue_state}` and passes the `queue_state` to subsequent queue functions."
  @callback init(name :: String.t, args :: List.t) :: {:ok, any}

  @doc "Pushes a job onto the queue, expects `{:ok, queue_state}`"
  @callback push(queue_state :: any, job :: Job.t) :: {:ok, any}

  @doc "Dequeues the next job to be processed, expects {:ok, queue_state, job} or :empty"
  @callback pop(queue_state :: any) :: {:ok, any, Job.t} | :empty

  @doc "Returns the length of the queue"
  @callback length(queue_state :: any) :: integer
end
