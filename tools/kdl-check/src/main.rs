use std::env;
use std::fs;
use std::path::Path;
use std::process::ExitCode;

use kdl::KdlDocument;

fn check(path: &Path) -> Result<(), String> {
    let source =
        fs::read_to_string(path).map_err(|error| format!("{}: {error}", path.display()))?;
    source
        .parse::<KdlDocument>()
        .map(|_| ())
        .map_err(|error| format!("{}: {error}", path.display()))
}

fn main() -> ExitCode {
    let paths: Vec<_> = env::args_os().skip(1).collect();
    if paths.is_empty() {
        eprintln!("usage: evals-kdl-check <file.kdl>...");
        return ExitCode::from(2);
    }

    let mut failed = false;
    for raw in paths {
        let path = Path::new(&raw);
        match check(path) {
            Ok(()) => println!("PASS: {}", path.display()),
            Err(error) => {
                eprintln!("FAIL: {error}");
                failed = true;
            }
        }
    }

    if failed {
        ExitCode::FAILURE
    } else {
        ExitCode::SUCCESS
    }
}
