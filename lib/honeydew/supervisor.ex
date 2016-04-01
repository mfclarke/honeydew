defmodule Honeydew.Supervisor do

  def start_link(pool_name, worker_module, worker_args, pool_opts \\ []) do
    import Supervisor.Spec

    num_workers     = pool_opts[:workers] || 10
    init_retry_secs = pool_opts[:init_retry_secs] || 5

    queue_module = pool_opts[:queue] || Honeydew.Queue.ErlangQueue
    queue_args   = pool_opts[:queue_args] || []

    failure_module = pool_opts[:failure] || Honeydew.FailureMode.Abandon
    failure_args   = pool_opts[:failure_args] || []

    dispatcher = Honeydew.dispatcher_name(worker_module, pool_name)

    children = [
      worker(Honeydew.Dispatcher, [dispatcher, queue_module, queue_args, failure_module, failure_args], id: :dispatcher),
      supervisor(Honeydew.WorkerSupervisor, [pool_name, worker_module, worker_args, init_retry_secs, num_workers], id: :worker_supervisor)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
