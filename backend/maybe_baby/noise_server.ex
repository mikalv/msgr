defmodule Messngr.NoiseServer do
  require Logger
  use GenServer

  @port 7891
  @public <<112,91,141,253,183,66,217,102,211,40,13,249,238,51,77,114,163,159,32,1,162,219,76,106,89,164,34,71,149,2,103,59>>
  @private <<200,81,196,192,228,196,182,200,181,83,169,255,242,54,99,113,8,49,129,92,225,220,99,50,93,96,253,250,116,196,137,103>>

  def start do
    GenServer.start(__MODULE__, %{socket: nil, noise_opts: nil})
  end

  def init(state) do
    protocol = :enoise_protocol.from_name('Noise_NX_25519_ChaChaPoly_Blake2b')
    {:ok, socket} = :gen_tcp.listen(@port, [:binary, active: true, reuseaddr: true])
    {_,t,priv,pub} = :enoise_keypair.new(:dh25519)
    noise_opts = [
      noise: protocol,
      s: :enoise_keypair.new(:dh25519),
      prologue: <<1,9,8,4,4,2>>,
    ]
    send(self(), :accept)

    Logger.info "Accepting connection on port #{@port}... Opts: #{inspect noise_opts}"
    {:ok, %{state | socket: socket, noise_opts: noise_opts}}
  end

  def handle_info(:accept, %{socket: socket, noise_opts: noise_opts} = state) do
    Logger.info "Pending accpet"
    {:ok, tcpSock} = :gen_tcp.accept(socket)
    {:ok, nConn} = :enoise.accept(tcpSock, noise_opts)

    #{nConn, msg} = :enoise.recv(nConn)
    #nConn = :enoise.send(nConn, msg)

    Logger.info "Client connected"
    {:noreply, %{state | nConn: nConn }}
  end

  def handle_info({:tcp, socket, data}, {nConn} = state) do
    #Logger.info "Received #{data}"
    Logger.info "Sending it back"
    {nConn, msg} = :enoise.recv(nConn)
    nConn = :enoise.send(nConn, msg)

    #:ok = :gen_tcp.send(socket, data)

    {:noreply, %{state | nConn: nConn }}
  end

  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}
end
