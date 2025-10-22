defmodule Teams.SecureID do
  @quick_opts Hashids.new([min_len: 8, salt: "fef04203-dead-b00b-b00b-1727306184"])
  @epoch 1727306184

  def id!(intID, prefix \\ "M") do
    time = (System.os_time(:millisecond) - (@epoch*1000))
    tid = Integer.to_string(time, 16)
    encID = Hashids.encode(@quick_opts, intID)
    "#{prefix}:#{tid}:#{encID}"
  end

  def revert_id!(encID) do
    [_prefix, _tid, hashid] = String.split(encID, ":")
    Hashids.decode!(@quick_opts, hashid) |> List.first
  end

  def revert_id(encID) do
    [prefix, tid, hashid] = String.split(encID, ":")
    value = Hashids.decode!(@quick_opts, hashid) |> List.first
    tiden = elem(Integer.parse(tid, 16), 0)
    %{prefix: prefix, tid: tiden, real_time: @epoch + tiden, id: value}
  end
end
