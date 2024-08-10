# ---
# jupyter:
#   jupytext:
#     formats: py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.16.4
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

import calendar
import os

# %%
import re

DATA_DIR = "raw-data/aug_sept_2023"


def dir_ls(dirname, ext=None):
    if ext is None:
        return os.listdir(dirname)
    else:
        return [f for f in os.listdir(dirname) if os.path.splitext(f)[1] == ext]


def parse_bdf_filename(fname):
    pattern = re.compile(r"(M|T|W|Th|F)([A-Z])(_)([0-9][0-9])([A-Za-z]{3})([0-9]{4})")
    basename, ext = os.path.splitext(fname)
    dow, subj, _, day, mon, year = re.split(pattern, basename)[1:-1]
    return dict(dow=dow, subj=subj, day=day, mon_abbr=mon, year=year)


def parse_json_filename(fname):
    pattern = re.compile(
        r"(M|T|W|Th|F)([A-Z])(_{1,2})([0-9][0-9])(_)([0-9][0-9])(_)([0-9]{4})_([0-9]{2}_[0-9]{2}_[0-9]{2})_results"
    )

    basename, ext = os.path.splitext(fname)
    dow, subj, _, mon, _, day, _, year, tstamp = re.split(pattern, basename)[1:-1]

    return dict(
        dow=dow,
        subj=subj,
        day=day,
        mon=mon,
        # convert e.g. '08' to 'Aug' and so on
        # to help match with the bdf file names
        mon_abbr=calendar.month_abbr[int(mon)],
        year=year,
        tstamp=tstamp,
    )


def xy_cmp(x, y):
    "Does y have the same keys and values as x?"
    return all([y[key] == value for key, value in x.items()])


def find_match_and_rename(bdf_filename):
    bdf_filename_parsed = parse_bdf_filename(bdf_filename)
    matches = [
        (key, value)
        for key, value in behavioural_filenames.items()
        if xy_cmp(bdf_filename_parsed, value)
    ]
    assert len(matches) == 1  # one match; no more, no less

    newfile_basename = "{dow}{subj}_{mon}_{day}_{year}_{tstamp}".format(**matches[0][1])

    bdf_filename_old = bdf_filename
    bdf_filename_new = newfile_basename + ".bdf"

    json_filename_old = matches[0][0]
    json_filename_new = newfile_basename + ".json"

    # use this to keep code minimal below
    o = lambda f: os.path.join(DATA_DIR, f)

    os.rename(o(bdf_filename_old), o(bdf_filename_new))
    os.rename(o(json_filename_old), o(json_filename_new))


# %%
# should be just the new EEG files
# these do not contain `results` in the fname
bdf_file_list = [f for f in dir_ls(DATA_DIR, ".bdf") if not "results" in f]

json_file_list = dir_ls(DATA_DIR, ".json")

behavioural_filenames = {fname: parse_json_filename(fname) for fname in json_file_list}

# %%
# this is destructive, so be careful
for fname in bdf_file_list:
    find_match_and_rename(fname)

# %%
