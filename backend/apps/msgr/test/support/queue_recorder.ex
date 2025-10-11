# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Support.QueueRecorder do
  @moduledoc """
  Simple in-memory queue adapter for exercising connector flows in tests.
  """

  use Agent

  @behaviour Msgr.Connectors.Queue

  @type state :: %{published: list(), requests: list()}

  def start_link(opts) do
    Agent.start_link(fn -> %{published: [], requests: []} end, opts)
  end

  @impl Msgr.Connectors.Queue
  def publish(topic, payload, opts) do
    agent = Keyword.fetch!(opts, :agent)

    Agent.update(agent, fn state ->
      update_in(state, [:published], &[%{topic: topic, payload: payload, opts: opts} | &1])
    end)

    :ok
  end

  @impl Msgr.Connectors.Queue
  def request(topic, payload, opts) do
    agent = Keyword.fetch!(opts, :agent)

    Agent.update(agent, fn state ->
      update_in(state, [:requests], &[%{topic: topic, payload: payload, opts: opts} | &1])
    end)

    responder = Keyword.get(opts, :responder, fn -> {:ok, %{status: :accepted}} end)
    responder.()
  end

  def published(agent) do
    Agent.get(agent, fn %{published: published} -> Enum.reverse(published) end)
  end

  def requests(agent) do
    Agent.get(agent, fn %{requests: requests} -> Enum.reverse(requests) end)
  end
end
