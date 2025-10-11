defmodule AuthProvider.UserMailer do
  import Swoosh.Email

  @spec login_code(%{required(:name) => String.t(), required(:email) => String.t()}) :: Swoosh.Email.t()
  def login_code(user) do
    new()
    |> to({user.name, user.email})
    |> from({"Auth-Msgr", "auth@msgr.no"})
    |> subject("Hello, Avengers!")
    |> html_body("<h1>Hello #{user.name}</h1>")
    |> text_body("Hello #{user.name}\n")
  end

  def deliver(email) do
    email
    |> AuthProvider.Mailer.deliver()
  end
end
