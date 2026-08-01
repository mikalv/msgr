defmodule Messngr.Media.VirusScan.Scanner do
  @moduledoc """
  Behaviour for virus scanners used by `Messngr.Media.VirusScan`.
  """

  @type scan_result :: :clean | {:infected, String.t()} | {:error, term()}

  @callback scan_bytes(binary(), keyword()) :: scan_result()
end
