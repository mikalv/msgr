defmodule Messngr.Media.VirusScan.Passthrough do
  @moduledoc """
  Test/dev scanner that always returns `:clean`.
  """

  @behaviour Messngr.Media.VirusScan.Scanner

  @impl true
  def scan_bytes(_data, _opts \\ []), do: :clean
end
