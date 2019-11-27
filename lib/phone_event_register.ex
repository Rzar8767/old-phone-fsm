defmodule PhoneEventRegister do

def connected_in(my_number, other_number) do
  send_event(my_number, other_number, :connected_in)
end

def connected_out(my_number, other_number) do
  send_event(my_number, other_number, :connected_out)
end

def dialing(my_number, other_number) do
  send_event(my_number, other_number, :dialing)
end

def disconnected(my_number, other_number) do
  send_event(my_number, other_number, :disconnected)
end

defp send_event(my_number, other_number, event) do
  {:ok, datetime} = DateTime.now("Etc/UTC")
  send :event_register, {:cast, self(), {:new_event, {my_number, other_number}, event, datetime}}
  :ok
end

def get_billing(my_number) do
  send :event_register, {:call, self(), {:billing, my_number}}
  receive do
    {:response, response} ->
      {:ok, response}
    after
      1000 ->
        {:error, :timeout}
  end
end

def get_history(my_number) do
  send :event_register, {:call, self(), {:history, my_number}}
  receive do
    {:response, response} ->
      {:ok, response}
    after
      1000 ->
        {:error, :timeout}
  end
end

def start() do
  Process.register(spawn(fn -> loop(%{}) end), :event_register)
end

def handle_call({:history, phone_number}, _sender_pid, number_map) do
  history = Map.get(number_map, phone_number, []) |> Enum.reverse
  {:reply, history, number_map}
end
def handle_call({:billing, phone_number}, _sender_pid, number_map) do
  billing = List.foldl(Map.get(number_map, phone_number, []), [], &billing/2)
  {:reply, billing, number_map}
end

# Tell apart outgoing and incoming calls
defp billing({:disconnected, _other_number, timestamp}, calls) do
  [timestamp | calls]
end

defp billing({:connected_out, other_number, timestamp}, [disconnect_timestamp | calls]) do
  [{:out, DateTime.diff(disconnect_timestamp, timestamp), :other_number, other_number} | calls]
end

defp billing({:connected_in, other_number, timestamp}, [disconnect_timestamp | calls]) do
  [{:in, DateTime.diff(disconnect_timestamp, timestamp), :other_number, other_number} | calls]
end

defp billing({_event, _other_number, _timestamp}, calls) do
  calls
end

def handle_cast({:new_event, {my_number, other_number}, event_name, timestamp}, _sender_pid, state) do
  events = Map.get(state, my_number, [])
  new_state = Map.put(state, my_number, [{event_name, other_number, timestamp}| events])
  {:noreply, new_state}
end

# Generic loop, based on GenServer implementation, here only for usage with Phone
def loop(state) do
  receive do
    {:call, sender_pid, request} ->
      {:reply, response, new_state} = handle_call(request, sender_pid, state)
      send(sender_pid, {:response, response})
      loop(new_state)
    {:cast, sender_pid, request} ->
      {:noreply, new_state} = handle_cast(request, sender_pid, state)
      loop(new_state)
    {:stop, reason} ->
      exit(reason)
    _ ->
      loop(state)
    end
  end
end
