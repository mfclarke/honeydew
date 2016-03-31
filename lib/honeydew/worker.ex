defmodule Honeydew.Worker do
  use GenServer
  require Logger

  def start_link(pool_name, worker_module, worker_init_args, retry_secs) do
    GenServer.start_link(__MODULE__, [pool_name, worker_module, worker_init_args, retry_secs])
  end

  def start(pool_name, worker_module, worker_init_args, retry_secs) do
    GenServer.start(__MODULE__, [pool_name, worker_module, worker_init_args, retry_secs])
  end

  def init([pool_name, worker_module, worker_init_args, retry_secs]) do
    Process.flag(:trap_exit, true)
    init_result = try do
                    apply(worker_module, :init, [worker_init_args])
                  rescue e ->
                    {:error, e}
                  end

    # the worker module's init/1 could link a process that dies right away, watch for that and consider it an init/1 error
    init_result = receive do
                    msg = {:EXIT, _linked_pid, _reason} -> {:error, msg}
                  after
                    100 -> init_result
                  end
    Process.flag(:trap_exit, false)

    case init_result do
      {:ok, state} ->
        dispatcher = Honeydew.dispatcher_name(worker_module, pool_name)
        GenServer.call(dispatcher, :monitor_me)
        GenServer.cast(self, :ask_for_job)
        {:ok, {dispatcher, worker_module, state}}
      error ->
        worker_supervisor = Honeydew.worker_supervisor_name(worker_module, pool_name)
        :timer.apply_after(retry_secs * 1000, Supervisor, :start_child, [worker_supervisor, []])
        Logger.warn("#{worker_module}.init/1 must return {:ok, state}, got: #{inspect(error)}, retrying in #{retry_secs}s")
        :ignore
    end
  end


  def handle_cast(:ask_for_job, {dispatcher, worker_module, worker_state} = state) do
    job = GenServer.call(dispatcher, :job_please, :infinity)
    result = case job.task do
               f when is_function(f) -> f.(worker_state)
               f when is_atom(f)     -> apply(worker_module, f, [worker_state])
               {f, a}                -> apply(worker_module, f, a ++ [worker_state])
             end

    if job.from do
      GenServer.reply(job.from, result)
    end

    GenServer.cast(self, :ask_for_job)
    {:noreply, state}
  end

end
