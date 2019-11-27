defmodule PhoneFSMBilling do
  @moduledoc """
  Based on the Plain Old Telephony System finite state machine.

  The machine has the corresponding state transitions:
  (schema: State1 -> transition details -> State2)

  idle -> incoming -> ringing
  idle -> off_hook -> dial
  ringing -> other_on_hook -> idle
  ringing -> off_hook -> connected
  connected -> on_hook -> idle
  dial -> <choose number> -> dialing
  dialing -> other_off_hook -> connected
  """

  # Utility

  @my_number 502023

  def start() do
    PhoneEventRegister.start()
    start_phone()
    start_ringer()
  end

  def start_phone() do
    Process.register(spawn(&idle/0), :toy_phone)
  end

  def start_ringer() do
    Process.register(spawn(&ringer/0), :ringer)
  end

  def log_message(message) do
    pid = inspect(self())
    IO.puts("#{pid}: #{message}")
  end

  # Phone client
  def incoming_call(number),
  do:
    (
      send(:toy_phone, {:incoming, number})
      :ok
    )

  def call_number(number),
  do:
    (
      send(:toy_phone, {:call, number})
      :ok
    )

  def off_hook() do
      send(:toy_phone, :off_hook)
      :ok
  end

  def on_hook(),
  do:
    (
      send(:toy_phone, :on_hook)
      :ok
    )

  def other_on_hook(number),
  do:
    (
      send(:toy_phone, {:other_on_hook, number})
      :ok
    )

  def other_off_hook(number),
  do:
    (
      send(:toy_phone, {:other_off_hook, number})
      :ok
    )

  def get_billing(), do: PhoneEventRegister.get_billing(@my_number)
  def get_history(), do: PhoneEventRegister.get_history(@my_number)

  # States
  def idle() do
    receive do
      {:incoming, number} ->
        start_ringing()
        ringing(number)

      :off_hook ->
        start_tone()
        dial()

      {:stop, pid} ->
        send(pid, :ok)

      _ ->
        idle()
    end
  end

  def ringing(number) do
    receive do
      # Phone answered
      :off_hook ->
        log_message("You are connected to recipent with number #{number}")
        stop_ringing()
        PhoneEventRegister.connected_in(@my_number, number)
        connected(number)

      # The other phone stopped calling
      {:other_on_hook, ^number} ->
        log_message("Recipent gave up calling")
        stop_ringing()
        idle()
    after
      # Phone picked up in time
      30000 ->
        log_message("You didn't answer the phone in time, automatic call rejection")
        stop_ringing()
        idle()
    end
  end

  def connected(number) do
    receive do
      # You disconnected the call
      :on_hook ->
        log_message("You disconnected the call with #{number} by putting down the receiver")
        PhoneEventRegister.disconnected(@my_number, number)
        idle()

      # The other phone disconnected the call
      {:other_on_hook, ^number} ->
        log_message("Partner (#{number}) disconnected the call by putting down the receiver")
        PhoneEventRegister.disconnected(@my_number, number)
        idle()

      # Just a joke, should just be part of other clause
      {:other_on_hook, other_number} ->
        log_message("Some (#{other_number}) put their receiver down, but why would we care?")
        connected(number)

      other ->
        log_message("Unexpected message #{inspect(other)}")
        connected(number)
    end
  end

  def dial() do
    receive do
      # Put down the receiver
      :on_hook ->
        log_message("You put down the receiver")
        stop_tone()
        idle()

      # Try to dial another person
      {:call, number} ->
        log_message("You tried dialing #{number}")
        PhoneEventRegister.dialing(@my_number, number)
        dialing(number)
    after
      # Timeout in case receiver is picked up and nothing happens for a long time
      30000 ->
        log_message("You didn't call anyone for a long time")
        stop_tone()
        idle()
    end
  end

  def dialing(number) do
    receive do
      # Put down the receiver despite trying to call someone
      :on_hook ->
        log_message(" put down the receiver while dialing #{number}")
        stop_tone()
        idle()

      {:other_off_hook, ^number} ->
        log_message("#{number} answered the phone, connecting")
        stop_tone()
        PhoneEventRegister.connected_out(@my_number, number)
        connected(number)
    after
      # Timeout in case receiver is picked up and nothing happens for a long time
      30000 ->
        log_message("#{number} didn't pick up his phone for a long time")
        stop_tone()
        idle()
    end
  end

   # Ringer
   def start_ringing() do
    send(:ringer, :ring)
  end

  def stop_ringing() do
    send(:ringer, :stop_ringing)
  end

  def start_tone() do
    send(:ringer, :tone)
  end

  def stop_tone() do
    send(:ringer, :stop_tone)
  end

  def ringer() do
    receive do
      :ring ->
        IO.puts("Beginning of ringing")
        ringer_ring()

      :tone ->
        IO.puts("Beginning of tone sounds")
        ringer_tone()

      {:stop, pid} ->
        send(pid, :ok)
    end
  end

  def ringer_ring() do
    receive do
      :stop_ringing ->
        IO.puts("End of ringing")
        ringer()
    after
      1000 ->
        # IO.puts "Ring Ring!"
        ringer_ring()
    end
  end

  def ringer_tone() do
    receive do
      :stop_tone ->
        IO.puts("End of tone sounds")
        ringer()
    after
      1000 ->
        # IO.puts "Tone sound!"
        ringer_tone()
    end
  end
end
