defmodule Honeydew.FailureMode do
  alias Honeydew.Job

  @doc "Initializes the failure mode, expects `{:ok, failure_state}` and passes the `failure_state` to subsequent failure functions."
  @callback init(name :: String.t, args :: List.t) :: {:ok, any}

  @doc "Handle a job failure, expects {:ok, failure_state}"
  @callback job_failed(failure_state :: any, job :: Job.t) :: {:ok, any}
end
