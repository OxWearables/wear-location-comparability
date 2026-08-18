import argparse
import json
from pathlib import Path
from actipy import read_device, process
from actipy.processing import flag_nonwear
import pandas as pd
import numpy as np

RESAMPLE_RATES = {
    "60S": "minutely",
    "H": "hourly",
    "D": "daily",
}


def read(
    filepath,
    usecols="time,x,y,z",
    skipRows=0,
    dateFormat=None,
    calibrate_gravity=True,
    calibration_stdtol_min=None,
    detect_nonwear=True,
    resample_hz="uniform",
    sample_rate=None,
    lowpass_hz=None,
    verbose=True,
):
    p = Path(filepath)
    fsize = round(p.stat().st_size / (1024 * 1024), 1)

    ftype = p.suffix.lower()
    if ftype in (
        ".gz",
        ".xz",
        ".lzma",
        ".bz2",
        ".zip",
    ):  # if file is compressed, check the next extension
        ftype = Path(p.stem).suffix.lower()

    if ftype in (".csv", ".pkl"):
        if ftype == ".csv":
            tcol, xcol, ycol, zcol = usecols.split(",")

            data = pd.read_csv(
                filepath,
                usecols=[tcol, xcol, ycol, zcol],
                parse_dates=[tcol],
                date_format=dateFormat,
                index_col=tcol,
                dtype={xcol: "f4", ycol: "f4", zcol: "f4"},
                skiprows=skipRows,
            )

            # rename to standard names
            data = data.rename(columns={xcol: "x", ycol: "y", zcol: "z"})
            data.index.name = "time"

        elif ftype == ".pkl":
            data = pd.read_pickle(filepath)

        if sample_rate in (None, False):
            freq = infer_freq(data.index)
            sample_rate = int(np.round(pd.Timedelta("1s") / freq))

        # Quick fix: Drop duplicate indices. TODO: Maybe should be handled by actipy.
        data = data[~data.index.duplicated(keep="first")]

        data, info = process(
            data,
            sample_rate,
            lowpass_hz=lowpass_hz,
            calibrate_gravity=calibrate_gravity,
            calibrate_gravity_kwargs={"stdtol_min": calibration_stdtol_min},
            detect_nonwear=detect_nonwear,
            resample_hz=resample_hz,
            verbose=verbose,
        )

        info = {
            **{
                "Filename": filepath,
                "Device": ftype,
                "Filesize(MB)": fsize,
                "SampleRate": sample_rate,
                "ReadOK": 1,
            },
            **info,
        }

    elif ftype in (".cwa", ".gt3x", ".bin"):

        data, info = read_device(
            filepath,
            lowpass_hz=lowpass_hz,
            calibrate_gravity=calibrate_gravity,
            calibrate_gravity_kwargs={"stdtol_min": calibration_stdtol_min},
            detect_nonwear=detect_nonwear,
            resample_hz=resample_hz,
            verbose=verbose,
        )

    else:
        raise ValueError(f"Unknown file format: {ftype}")

    if "ResampleRate" not in info:
        info["ResampleRate"] = info["SampleRate"]

    return data, info


def infer_freq(t):
    """Like pd.infer_freq but more forgiving"""
    tdiff = t.to_series().diff()
    q1, q3 = tdiff.quantile([0.25, 0.75])
    tdiff = tdiff[(q1 <= tdiff) & (tdiff <= q3)]
    freq = tdiff.mean()
    freq = pd.Timedelta(freq)
    return freq


def convert(o):
    if isinstance(o, np.generic):
        return o.item()
    if isinstance(o, np.ndarray):
        return o.tolist()
    if isinstance(o, dict):
        return {k: convert(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [convert(i) for i in o]
    return o


def calc_enmo_sig(data):
    enmo_sig = 1000 * (np.linalg.norm(data[["x", "y", "z"]], axis=1) - 1)
    enmo_sig[enmo_sig < 0] = 0

    return enmo_sig


def resample_enmo(data_enmo, data_without_nonwear, outPath, filename, rate):
    resampled_enmo = (
        data_enmo["enmo"].resample(rate, origin="start_day").mean().to_frame()
    )
    resampled_enmo_remove_nonwear = (
        data_without_nonwear["enmo_without_nonwear"]
        .resample(rate, origin="start_day")
        .mean()
        .to_frame()
    )
    resampled_enmo = resampled_enmo.merge(
        resampled_enmo_remove_nonwear["enmo_without_nonwear"],
        left_index=True,
        right_index=True,
        how="outer",
    )

    if rate == "D":
        resampled_enmo.index = resampled_enmo.index.date
        resampled_enmo.index.name = "date"
    resampled_enmo["participant"] = filename

    output_path = Path(outPath)
    ftype = "csv.gz" if rate in ("30S", "60S") else "csv"
    resampled_enmo.to_csv(output_path / f"{filename}_{RESAMPLE_RATES[rate]}.{ftype}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract ENMO from acc file.")
    parser.add_argument("--filepath", "-f", help="Input file name")
    parser.add_argument("--outpath", "-o")

    args = parser.parse_args()

    filename = Path(args.filepath).stem
    ftype = Path(args.filepath).suffix.lower()
    if ftype in (
        ".gz",
        ".xz",
        ".lzma",
        ".bz2",
        ".zip",
    ):  # if file is compressed, check the next extension
        filename = Path(filename).stem

    data, info = read(
        args.filepath,
        lowpass_hz=None,
        calibrate_gravity=True,
        detect_nonwear=False,
        resample_hz="uniform",
        verbose=True,
    )

    data_without_nonwear, info_nonwear = flag_nonwear(
        data, patience="60m", window="10s", stdtol=13 / 1000
    )

    info.update(info_nonwear)

    enmo_sig = calc_enmo_sig(data)
    enmo_sig_remove_nonwear = calc_enmo_sig(data_without_nonwear)

    info["ENMO_all(mg)"] = np.mean(enmo_sig)
    info["ENMO_all_remove_nonwear(mg)"] = np.nanmean(enmo_sig_remove_nonwear)

    data["enmo"] = enmo_sig
    data_without_nonwear["enmo_without_nonwear"] = enmo_sig_remove_nonwear

    output_path = Path(args.outpath) / filename
    output_path.mkdir(parents=True, exist_ok=True)

    for rate in RESAMPLE_RATES.keys():
        resample_enmo(data, data_without_nonwear, output_path, filename, rate)

    output_file = output_path / f"{filename}_info.json"
    with open(output_file, "w") as f:
        json.dump(convert(info), f, indent=4)
