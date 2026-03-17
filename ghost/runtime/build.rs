use std::io::Result;

fn main() -> Result<()> {
    // Compile protobuf files if they exist
    let proto_file = "src/proto/ghost.proto";
    
    if std::path::Path::new(proto_file).exists() {
        tonic_build::configure()
            .build_server(true)
            .build_client(true)
            .out_dir("src/proto")
            .compile(&[proto_file], &["src/proto"])?;
    }

    // Emit build info
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/proto/ghost.proto");

    Ok(())
}
