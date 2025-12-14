fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)
        .build_client(true)  // We need client to call Elixir backend
        .compile_protos(
            &["proto/noise/v1/gateway.proto"],
            &["proto"],
        )?;
    Ok(())
}
