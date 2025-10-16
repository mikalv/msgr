defmodule Messngr.Metrics.Reporter.Log do
  @moduledoc """
  Reporter that logs metrics for local inspection.
  """

  @behaviour Messngr.Metrics.Reporter

  require Logger

  @impl true
  def handle_metric(metric, measurement, metadata) do
    Logger.debug(fn ->
      [
        "metric=", Atom.to_string(metric),
        " measurement=", inspect(measurement),
        " metadata=", inspect(metadata)
      ]
      |> IO.iodata_to_binary()
    end)

    :ok
  end
end
