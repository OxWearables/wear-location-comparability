import os
import glob
import argparse
import time
import subprocess
from pathlib import Path

project_dir = str(Path(__file__).absolute().parents[1])


def generate_deployment_txts(input_path, output_path, script_path, package):
    # Get list of all accelerometer files
    all_files = glob.glob(os.path.join(input_path, "*"))
    acc_file_list = [
        f for f in all_files if f.endswith((".cwa.gz", ".gt3x", ".csv.gz", ".csv"))
    ]

    # Loop through accelerometer files and prepare commands to be written to file
    master_cmd = []
    for participant_acc_path in acc_file_list:

        # Write processing command depending on the package used
        if package == "actinet":
            cmd = (
                "actinet "
                + participant_acc_path
                + " -o "
                + output_path
                + " -p --require-sleep-above 1H --calibration-stdtol-min 0"
                + "\n"
            )
        elif package == "stepcount":
            cmd = (
                "stepcount "
                + participant_acc_path
                + " -o "
                + output_path
                + " --calibration-stdtol-min 0"
                + "\n"
            )
        elif package == "actipy":
            cmd = (
                "python process_raw/actipy_enmo.py "
                + " -f "
                + participant_acc_path
                + " -o "
                + output_path
                + "\n"
            )
        master_cmd.append(cmd)

    # Write commands to text file
    with open(script_path, "w") as f:
        for cmd in master_cmd:
            f.write(cmd)


def main():
    parser = argparse.ArgumentParser(
        description="Process wrist-worn accelerometer measurements using the OxWearables packages.",
        add_help=True,
    )

    # Required arguments
    parser.add_argument(
        "--data_dir", "-d", required=True, help="Directory where data are stored."
    )

    parser.add_argument(
        "--package",
        "-p",
        choices=["actinet", "stepcount", "actipy"],
        required=True,
        help="Which package to run: stepcount, actinet, or actipy",
    )

    # Optional arguments
    parser.add_argument(
        "--output_dir",
        "-o",
        default="outputs/",
        help="Directory where output files will be saved.",
    )

    args = parser.parse_args()
    before = time.time()

    # Initialize paths
    log_dir = os.path.join(args.output_dir, "logs")
    config_dir = os.path.join(project_dir, "process_raw", "config")
    data_folder_name = os.path.basename(os.path.normpath(args.data_dir))
    script_filepath = os.path.join(
        config_dir, f"run_{args.package}_{data_folder_name}.txt"
    )

    # Create directories if they do not exist
    os.makedirs(config_dir, exist_ok=True)
    os.makedirs(log_dir, exist_ok=True)
    os.makedirs(args.output_dir, exist_ok=True)

    # Create deployment text files
    print("==========================================================")
    print(f"Preparing and submitting BMRC jobs for package: {args.package}")
    print("==========================================================")

    generate_deployment_txts(
        args.data_dir, args.output_dir, script_filepath, args.package
    )

    # Create BMRC bash scripts
    conda_env = "actinet" if args.package == "actipy" else args.package
    subprocess.call(
        [
            "python",
            os.path.join(project_dir, "process_raw", "write_BMRC_script.py"),
            script_filepath,
            "--logdir",
            log_dir,
            "--conda",
            conda_env,
            "-b 2",
        ]
    )

    # Submit BMRC jobs
    subprocess.call(
        [
            "sbatch",
            os.path.join(config_dir, f"run_{args.package}_{data_folder_name}.sh"),
        ]
    )

    # Print processing time
    after = time.time()
    print(f"Done! ({round(after - before, 2)}s)")


if __name__ == "__main__":
    main()
