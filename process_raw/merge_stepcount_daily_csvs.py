import os
import glob
import pandas as pd
import argparse
from tqdm import tqdm

def merge_daily_files(data_dir):
    # Collect all subdirectories that contain both files
    subdirs = []
    for root, dirs, files in os.walk(data_dir):
        daily_files = glob.glob(os.path.join(root, "*-Daily.csv.gz"))
        adjusted_files = glob.glob(os.path.join(root, "*-DailyAdjusted.csv.gz"))
        if daily_files and adjusted_files:
            subdirs.append((daily_files[0], adjusted_files[0]))

    # Iterate with progress bar
    for daily_path, adjusted_path in tqdm(subdirs, desc="Merging files", unit="folder"):
        try:
            # Read the two dataframes
            daily = pd.read_csv(daily_path, usecols=["Filename", "Date", "WearTime(hours)"])
            adjusted = pd.read_csv(adjusted_path)

            # Merge by Filename and Date
            merged = adjusted.merge(daily, on=["Filename", "Date"], how="left")

            # Construct new output path
            out_path = adjusted_path.replace("-DailyAdjusted.csv.gz", "-DailyAdjustedWithWearTime.csv.gz")

            # Save to new file
            merged.to_csv(out_path, index=False, compression="gzip")

        except Exception as e:
            print(f"Error processing {daily_path}: {e}")

if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", "-d", required=True, help="Top-level data directory containing subdirectories")
    args = parser.parse_args()

    merge_daily_files(args.data_dir)
