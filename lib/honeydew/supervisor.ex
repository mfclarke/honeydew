defmodule Honeydew.Supervisor do

  def start_link(pool_name, worker_module, worker_init_args, pool_opts \\ []) do
    import Supervisor.Spec

    num_workers     = pool_opts[:workers] || 10
    init_retry_secs = pool_opts[:init_retry_secs] || 5

    dispatcher = Honeydew.dispatcher_name(worker_module, pool_name)

    children = [
      worker(Honeydew.Dispatcher, [dispatcher], id: :dispatcher),
      supervisor(Honeydew.WorkerSupervisor, [pool_name, worker_module, worker_init_args, init_retry_secs, num_workers], id: :worker_supervisor)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
