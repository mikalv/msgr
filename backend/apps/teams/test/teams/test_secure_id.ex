defmodule Teams.SecureIDTest do
  use ExUnit.Case
  alias Teams.SecureID

  @test_id 12345

  test "id!/1 generates a secure ID" do
    secure_id = SecureID.id!(@test_id)
    assert String.starts_with?(secure_id, "M:")
    assert length(String.split(secure_id, ":")) == 3
  end

  test "revert_id!/1 decodes the secure ID" do
    secure_id = SecureID.id!(@test_id)
    decoded_id = SecureID.revert_id!(secure_id)
    assert decoded_id == @test_id
  end

  test "revert_id/1 returns detailed information" do
    secure_id = SecureID.id!(@test_id)
    %{prefix: prefix, tid: tid, real_time: real_time, id: id} = SecureID.revert_id(secure_id)

    assert prefix == "M"
    assert is_integer(tid)
    assert is_integer(real_time)
    assert id == @test_id
  end
end
