defmodule Teams.Upload do
  require Logger

  def request_presigned_url(filename, filetype, region \\ "us-east-1", expires_in \\ 300, service \\ "s3") do
    Logger.info "Requesting presigned url for #{filename} of type #{filetype}"
    #
    # When creating pre-signed URL for AWS S3, make sure to pass in body: :unsigned option.
    # It is also very importnt to merge the signature data with other query parameters before sending
    # the request (Sigaws.Util.add_params_to_url). The request will fail if these are not taken care of.
    s3host = System.get_env("AWS_S3_ENDPOINT")
    bucket = System.get_env("AWS_S3_BUCKET")
    url = "#{s3host}/#{bucket}/#{filename}"
    {:ok, %{} = sig_data, _} =
      Sigaws.sign_req(url, region: region, service: service, expires_in: expires_in, body: :unsigned,
        access_key: System.get_env("AWS_ACCESS_KEY_ID"), secret: System.get_env("AWS_SECRET_ACCESS_KEY"))

    presigned_url = Sigaws.Util.add_params_to_url(url, sig_data)
    {:ok, presigned_url}
  end
end
