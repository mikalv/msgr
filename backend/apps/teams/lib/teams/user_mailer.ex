defmodule Teams.UserMailer do
  import Swoosh.Email

  @spec login_code(String.t(), %{required(:name) => String.t(), required(:email) => String.t()}) :: Swoosh.Email.t()
  def login_code(tenantName, user) do
    new()
    |> to({user.name, user.email})
    |> from({"Teams-Msgr", "teams+#{tenantName}@msgr.no"})
    |> subject("Login code")
    |> html_body("<h1>Login code for #{user.name}</h1>")
    |> text_body("Hello #{user.name}\n")
  end

  def deliver(email) do
    email
    |> Teams.Mailer.deliver()
  end
end
