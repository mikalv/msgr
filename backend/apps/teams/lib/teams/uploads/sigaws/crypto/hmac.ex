defmodule Sigaws.Crypto.HMAC do
  @moduledoc false
  def init(type, key), do: :crypto.mac_init(:hmac, type, key)
  def update(hmac_ctxt, data), do: :crypto.mac_update(hmac_ctxt, data)
  def compute(hmac_ctxt), do: :crypto.mac_final(hmac_ctxt)
end
