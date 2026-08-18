import os
import glob
import argparse
import json
from collections import OrderedDict
import pandas as pd
from tqdm import tqdm


def collate_files(path_participants_root, package):
    # Create list with all participant subdirectories
    subdir_glob = os.path.join(path_participants_root, "*")
    subdir_list = glob.glob(subdir_glob, recursive=True)

    # Retain only subirectories that contain relevant files
    subdir_list = [
        p
        for p in subdir_list
        if os.path.isdir(p)
        and any(fname.endswith((".csv.gz", ".json")) for fname in os.listdir(p))
    ]

    # Initialize lists to hold data
    daily_dfs = []
    epoch_dfs = []
    weekly_dicts = []
    failed_to_process = []

    for current_path in tqdm(subdir_list):
        norm_path = os.path.normpath(current_path)
        subject_id = norm_path.split(os.sep)[-1]

        # Initialize file paths based on package
        if package == "actinet":
            daily_file_path = os.path.join(norm_path, f"{subject_id}-Daily.csv.gz")
            weekly_file_path = os.path.join(
                norm_path, f"{subject_id}-outputSummary.json"
            )
            epoch_file_path = os.path.join(norm_path, f"{subject_id}-timeSeries.csv.gz")
        elif package == "stepcount":
            daily_file_path = os.path.join(
                norm_path,
                f"{subject_id}-DailyAdjustedWithWearTime.csv.gz",  ## TO-DO change back when fixed
            )
            weekly_file_path = os.path.join(norm_path, f"{subject_id}-Info.json")
            epoch_file_path = os.path.join(
                norm_path, f"{subject_id}-MinutelyAdjusted.csv.gz"
            )
        elif package == "actipy":
            daily_file_path = os.path.join(norm_path, f"{subject_id}_daily.csv")
            weekly_file_path = os.path.join(norm_path, f"{subject_id}_info.json")
            epoch_file_path = os.path.join(norm_path, f"{subject_id}_minutely.csv.gz")

        # Collate daily files
        if os.path.exists(daily_file_path):
            daily_dfs.append(pd.read_csv(daily_file_path))
        else:
            failed_to_process.append(subject_id)

        # Collate weekly files
        if os.path.exists(weekly_file_path):
            with open(weekly_file_path, "r") as f:
                weekly_dicts.append(json.load(f, object_pairs_hook=OrderedDict))
        else:
            failed_to_process.append(subject_id)

        # Collate 60-sec epoch files
        if os.path.exists(epoch_file_path):
            epoch_df_tmp = pd.read_csv(epoch_file_path)
            epoch_df_tmp["participant"] = subject_id
            epoch_dfs.append(epoch_df_tmp)
        else:
            failed_to_process.append(subject_id)

    # Convert dictionaries to DataFrames
    collated_df_daily = pd.concat(daily_dfs, ignore_index=True)
    collated_df_weekly = pd.DataFrame.from_dict(weekly_dicts)
    collated_df_epoch = pd.concat(epoch_dfs, ignore_index=True)

    return collated_df_daily, collated_df_weekly, collated_df_epoch, failed_to_process


def main():
    parser = argparse.ArgumentParser(
        description="Tool to collate produced package summary files."
    )

    # Required arguments
    parser.add_argument(
        "--data_dir",
        "-d",
        required=True,
        help="Directory where processed repeat accelerometer data are stored.",
    )

    parser.add_argument(
        "--package",
        "-p",
        choices=["actinet", "stepcount", "actipy"],
        required=True,
        help="Which package outputs to collate: actinet's, stepcount's or actipy's.",
    )

    args = parser.parse_args()

    # Create a directory to store CSVs
    output_dir = os.path.join(args.data_dir, "collated")
    os.makedirs(output_dir, exist_ok=True)

    # Delete previous file with failed IDs (if it exists)
    failed_ids_filepath = os.path.join(output_dir, "failed_ids.txt")
    if os.path.exists(failed_ids_filepath):
        os.remove(failed_ids_filepath)

    # Collate participant summary files
    print("==========================================================")
    print(f"Collating files for package: {args.package}")
    print("==========================================================")

    collated_df_daily, collated_df_weekly, collated_df_epoch, failed_ids = (
        collate_files(args.data_dir, args.package)
    )

    # Also record files that failed to be processed
    if failed_ids:
        with open(failed_ids_filepath, "a") as f:
            f.write(f"Package: {args.package}\n")
            for pid in failed_ids:
                f.write(f"{pid}\n")
    else:
        print("All participant files processed successfully.")

    # Write collated DataFrames to files
    daily_filepath = os.path.join(output_dir, f"daily_collated_{args.package}.csv")
    weekly_filepath = os.path.join(output_dir, f"weekly_collated_{args.package}.csv")
    epoch_filepath = os.path.join(output_dir, f"epoch_collated_{args.package}.csv")
    collated_df_daily.to_csv(daily_filepath, index=False)
    collated_df_weekly.to_csv(weekly_filepath, index=False)
    collated_df_epoch.to_csv(epoch_filepath, index=False)
    print("Daily summaries written to", daily_filepath)
    print("Weekly summaries written to", weekly_filepath)
    print("Epoch-level summaries written to", epoch_filepath)


if __name__ == "__main__":
    main()
