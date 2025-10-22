defmodule MessngrWeb.AIController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def chat(conn, %{"messages" => messages} = params) when is_list(messages) and messages != [] do
    opts = extract_common_opts(params)

    case Messngr.ai_chat(team_id(conn), messages, opts) do
      {:ok, result} -> render(conn, :chat, result: result)
      {:error, reason} -> handle_ai_error(conn, reason)
    end
  end

  def chat(_conn, _params), do: {:error, :bad_request}

  def summarize(conn, %{"text" => text} = params) when is_binary(text) do
    opts = extract_summary_opts(params) ++ extract_common_opts(params)

    case Messngr.ai_summarize(team_id(conn), text, opts) do
      {:ok, result} -> render(conn, :summarize, result: result)
      {:error, reason} -> handle_ai_error(conn, reason)
    end
  end

  def summarize(_conn, _params), do: {:error, :bad_request}

  def run(conn, %{"prompt" => prompt} = params) when is_binary(prompt) do
    opts = extract_common_opts(params) ++ prompt_opts(params)

    case Messngr.ai_run_prompt(team_id(conn), prompt, opts) do
      {:ok, result} -> render(conn, :run, result: result)
      {:error, reason} -> handle_ai_error(conn, reason)
    end
  end

  def run(_conn, _params), do: {:error, :bad_request}

  def conversation_reply(conn, %{"id" => conversation_id} = params) do
    current_profile = conn.assigns.current_profile
    opts = extract_common_opts(params) ++ conversation_opts(params)

    with _participant <- Messngr.ensure_membership(conversation_id, current_profile.id),
         {:ok, result} <-
           Messngr.ai_conversation_reply(team_id(conn), conversation_id, current_profile, opts) do
      render(conn, :conversation_reply, result: result)
    else
      {:error, reason} -> handle_ai_error(conn, reason)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def conversation_reply(_conn, _params), do: {:error, :bad_request}

  defp extract_common_opts(params) do
    []
    |> maybe_put(:provider, params["provider"])
    |> maybe_put(:temperature, params["temperature"])
    |> maybe_put(:max_tokens, params["max_tokens"])
    |> maybe_put(:model, params["model"])
    |> maybe_put(:response_format, params["response_format"])
    |> maybe_put(:credentials, params["credentials"])
    |> maybe_put(:config, params["config"])
  end

  defp extract_summary_opts(params) do
    []
    |> maybe_put(:language, params["language"])
    |> maybe_put(:style, params["style"])
    |> maybe_put(:instructions, params["instructions"])
    |> maybe_put(:context, params["context"])
    |> maybe_put(:system_prompt, params["system_prompt"])
  end

  defp prompt_opts(params) do
    []
    |> maybe_put(:system_prompt, params["system_prompt"])
  end

  defp conversation_opts(params) do
    []
    |> maybe_put(:history_limit, parse_positive_integer(params["history_limit"]))
    |> maybe_put(:tone, params["tone"])
    |> maybe_put(:assistant_name, params["assistant_name"])
    |> maybe_put(:system_prompt, params["system_prompt"])
    |> maybe_put(:extra_context, params["extra_context"])
  end

  defp parse_positive_integer(nil), do: nil

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> nil
    end
  end

  defp parse_positive_integer(_), do: nil

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp team_id(conn), do: conn.assigns.current_account.id

  defp handle_ai_error(conn, {:invalid_message, details}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_message", details: details})
    |> halt()
  end

  defp handle_ai_error(conn, {:invalid_option, option}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_option", option: option})
    |> halt()
  end

  defp handle_ai_error(conn, :messages_required) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "messages_required"})
    |> halt()
  end

  defp handle_ai_error(conn, :text_required) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "text_required"})
    |> halt()
  end

  defp handle_ai_error(conn, :prompt_required) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "prompt_required"})
    |> halt()
  end

  defp handle_ai_error(conn, {:llm_failure, reason}) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "llm_failure", reason: safe_reason(reason)})
    |> halt()
  end

  defp handle_ai_error(_conn, other) when is_atom(other) do
    {:error, other}
  end

  defp handle_ai_error(conn, other) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "unexpected_llm_error", reason: safe_reason(other)})
    |> halt()
  end

  defp safe_reason({:http_error, status, _body}) do
    %{type: "http_error", status: status}
  end

  defp safe_reason(reason) when is_atom(reason), do: %{type: Atom.to_string(reason)}
  defp safe_reason(reason) when is_binary(reason), do: %{message: reason}
  defp safe_reason(reason), do: %{type: "unknown", detail: inspect(reason)}
end
