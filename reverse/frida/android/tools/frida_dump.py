#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
import time


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run a Frida script and persist send() payloads to JSONL.",
    )
    parser.add_argument(
        "--package",
        required=True,
        help="Android package name to attach to (e.g. com.snapchat.android)",
    )
    parser.add_argument(
        "--script",
        required=True,
        help="Path to the Frida JS script.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output JSONL path.",
    )
    parser.add_argument(
        "--device",
        default="usb",
        help="Frida device identifier (default: usb). Use 'local' for emulator.",
    )
    parser.add_argument(
        "--spawn",
        action="store_true",
        help="Spawn the app (cold start). Default attaches to existing process.",
    )
    parser.add_argument(
        "--frida-cmd",
        default="frida",
        help="Frida CLI executable (default: frida).",
    )
    return parser.parse_args()


def run_frida(args):
    command = [
        args.frida_cmd,
        "-U" if args.device == "usb" else "-D",
    ]

    if args.spawn:
        command += ["-f", args.package, "-l", args.script, "--no-pause"]
    else:
        command += ["-n", args.package, "-l", args.script]

    with open(args.output, "w", encoding="utf-8") as output_file:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        output_file.write(
            json.dumps(
                {"event": "frida-start", "timestamp": time.time(), "command": command},
            )
            + "\n",
        )
        try:
            for line in process.stdout:
                output_file.write(line)
                output_file.flush()
                sys.stdout.write(line)
                sys.stdout.flush()
        except KeyboardInterrupt:
            process.terminate()

        process.wait()
        output_file.write(
            json.dumps(
                {
                    "event": "frida-exit",
                    "timestamp": time.time(),
                    "returncode": process.returncode,
                },
            )
            + "\n",
        )

    return process.returncode


def main():
    args = parse_args()
    try:
        returncode = run_frida(args)
    except FileNotFoundError:
        print("Frida CLI not found. Install via `pip install frida-tools`.", file=sys.stderr)
        returncode = 1
    sys.exit(returncode)


if __name__ == "__main__":
    main()
