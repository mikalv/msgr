defmodule Messngr.Media.VirusScan.InfectedStub do
  @moduledoc false
  @behaviour Messngr.Media.VirusScan.Scanner

  @impl true
  def scan_bytes(_data, _opts \\ []), do: {:infected, "Eicar-Test-Signature"}
end

defmodule Messngr.Media.VirusScan.ErrorStub do
  @moduledoc false
  @behaviour Messngr.Media.VirusScan.Scanner

  @impl true
  def scan_bytes(_data, _opts \\ []), do: {:error, :boom}
end
