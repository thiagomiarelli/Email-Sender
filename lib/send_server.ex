defmodule SendServer do
  use GenServer

  def init(args) do
    max_retries = Keyword.get(args, :max_retries, 3)
    state = %{emails: [], max_retries: max_retries}
    {:ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:send, email}, state) do
    status =
      case Sender.send_email(email) do
        {:ok, _msg} -> "sent"
        :error -> "not sent"
      end

    emails = [%{email: email, status: status, retries: 0}] ++ state.emails


    Process.send_after(self(), :retry, 1000)

    {:noreply, %{state | emails: emails}}
  end

  def handle_info(:retry, state) do
    {failed_emails, sent_emails} =
      Enum.split_with(
        state.emails,
        fn email ->
           email.status == "not sent" && email.retries < state.max_retries end
      )

    retried =
      Enum.map(
        failed_emails,
        fn email ->
          IO.puts("Resending email #{email.email}")

          status =
            case Sender.send_email(email.email) do
              {:ok, _msg} -> "sent"
              :error -> "not sent"
            end

          %{email | status: status, retries: email.retries + 1}
        end
      )

      Process.send_after(self(), :retry, 1000)

      {:noreply, %{state | emails: retried ++ sent_emails}}
  end

  def terminate(reason, _state) do
    IO.puts("Server terminated: #{inspect(reason)}")
  end
end
