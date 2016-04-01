defmodule Honeydew.Dispatcher do
  use GenServer
  alias Honeydew.Job

  defmodule State do
    defstruct queue: nil,
              queue_module: nil,
              failure: nil,
              failure_module: nil,
              waiting: :queue.new, # workers that are waiting for a job
              working: Map.new, # workers that are currently working mapped to their current jobs
              suspended: false
  end


  def start_link(name, queue_module, queue_args, failure_module, failure_args) do
    state = %State{queue_module: queue_module,
                   failure_module: failure_module}

    {:ok, queue} = state.queue_module.init(name, queue_args)
    {:ok, failure} = state.failure_module.init(name, failure_args)

    GenServer.start_link(__MODULE__, %{state | queue: queue, failure: failure}, name: name)
  end

  #
  # Messaging
  #

  def handle_cast({:add_task, task}, state) do
    job = %Job{task: task}
    {:noreply, queue_job(job, state)}
  end

  def handle_cast({:add_job, job}, state) do
    {:noreply, queue_job(job, state)}
  end

  def handle_cast(_msg, state), do: {:noreply, state}


  def handle_call({:add_task, task}, from, state) do
    job = %Job{task: task, from: from}
    handle_cast({:add_job, job}, state)
  end

  def handle_call(:job_please, from, %State{suspended: true} = state) do
    {:noreply, queue_worker(from, state)}
  end

  def handle_call(:job_please, {worker, _msg_ref} = from, state) do
    case state.queue_module.pop(state.queue) do
      # there's a job in the queue, honey do it, please!
      {:ok, job, queue} ->
        {:reply, job, %{state | queue: queue, working: Map.put(state.working, worker, job)}}
      # nothing for the worker to do right now, we'll get back to them later when something arrives
      :empty ->
        {:noreply, queue_worker(from, state)}
    end
  end

  def handle_call(:monitor_me, {worker, _msg_ref}, state) do
    Process.monitor(worker)
    {:reply, :ok, state}
  end

  def handle_call(:suspend, _from, state) do
    {:reply, :ok, %{state | suspended: true}}
  end

  def handle_call(:resume, _from, state) do
    state.queue
    |> :queue.to_list
    |> Enum.each(&GenServer.cast(self, {:add_job, &1}))

    {:reply, :ok, %{state | queue: :queue.new, suspended: false}}
  end

  def handle_call(:status, _from, state) do
    %State{queue: queue, queue_module: queue_module, working: working, waiting: waiting, suspended: suspended} = state

    status = %{
      queue: queue_module.length(queue),
      working: Map.size(working),
      waiting: :queue.len(waiting),
      suspended: suspended
    }

    {:reply, status, state}
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}


  # A worker died
  def handle_info({:DOWN, _ref, _type, worker_pid, _reason}, state) do
    case Map.pop(state.working, worker_pid) do
      # worker wasn't working on anything
      {nil, _working} -> nil
      {job, working} ->
        {:ok, failure} = state.failure_module.job_failed(state.failure, job)
        state = %{state | working: working, failure: failure}
    end
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}


  defp queue_job(job, %{suspended: true} = state) do
    {:ok, queue} = state.queue_module.push(state.queue, job)
    %{state | queue: queue}
  end

  defp queue_job(job, state) do
    case next_alive_worker(state.waiting) do
      # no workers are waiting, add the job to the queue
      {nil, waiting} ->
        {:ok, queue} = state.queue_module.push(state.queue, job)
        %{state | queue: queue, waiting: waiting}
      # there's a worker waiting, give them the job
      {from_worker, waiting} ->
        {worker, _msg_ref} = from_worker
        GenServer.reply(from_worker, job)
        %{state | waiting: waiting, working: Map.put(state.working, worker, job)}
    end
  end

  defp queue_worker({worker, _msg_ref} = from, state) do
    %{state | waiting: :queue.in(from, state.waiting), working: Map.delete(state.working, worker)}
  end

  defp next_alive_worker(waiting) do
    case :queue.out(waiting) do
      {{:value, from_worker}, waiting} ->
        {worker, _msg_ref} = from_worker
        if Process.alive? worker do
          {from_worker, waiting}
        else
          next_alive_worker(waiting)
        end
      {:empty, _} ->
        {nil, waiting}
    end
  end

end
