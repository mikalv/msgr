defmodule Messngr.Metrics.Reporter do
  @moduledoc """
  Behaviour used by the metrics pipeline when reporting derived measurements.
  """

  @callback handle_metric(metric :: atom(), measurement :: map(), metadata :: map()) :: :ok | {:error, term()}
end
