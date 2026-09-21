'''
Starts from the child raw-data files exactly as they came off the recording
computers, with their original filenames (`{dow}{subj}_{day}{Month}{year}.bdf`
and `{dow}{subj}_{day}{Month}{year}_{mm}_{dd}_{yyyy}_{hh}_{mi}_{ss}_results.json`),
and ends with them renamed to the scheme already used in `raw-data/main`
(`{dow}{subj}_{mm}_{dd}_{yyyy}_{hh}_{mi}_{ss}`, same basename, `.bdf`/`.json`
only, no `_results`).

Meant to be run interactively, one section at a time, from inside the
directory holding those original files, not as a single unattended script.
Three of the checks below (`bad_bdfs`, `bad_bdf_matches`, `bad_json_matches`)
are expected to fail on the very first run, on files whose problems are only
resolved further down, once the growing `files_to_skip` list reaches them.
That's by design, not a bug: step past each one and carry on.

What it does, in order:

1. Parses every bdf and json filename and checks each is individually valid:
   a real day-of-week code, a subject letter, a day/month/year that forms a
   real calendar date, and, for jsons, that the date typed into the front of
   the filename agrees with the date in the json's own generated timestamp.
2. Checks that, within each calendar date, the subject letters (A, B, C, ...)
   were handed out in the actual order sessions were run, taken from the
   json timestamps, since a bdf filename carries no time of day.
3. Records, by filename, every anomaly found by hand while working through
   the above: sessions with more than one candidate json for a single bdf
   that couldn't be disambiguated (SuA on 1 June 2025, FA on 29 August
   2025), one json that was truncated mid-write (MC on 16 February 2026,
   the 15:13:09 attempt), and files with no counterpart at all on the other
   side (`FB_29August2025.bdf`, `SuB_1June2025.bdf`, the json for
   `SA_12July2025`). These are hard-coded by filename because working out
   which files these were was the point of the first run; started again
   from the same original files, they're the same files every time.
4. Once those are excluded, checks that every remaining bdf has exactly one
   matching json and vice versa, and builds `sessions`, a dict from a
   session's (dow, subj, day, month, year) to its (bdf, json) filename pair.
5. Renames every pair to the standard scheme, checksumming every file
   before renaming and re-checksumming after, to confirm the rename itself
   didn't change anything.
6. Deletes the files in `files_to_skip`, and one further stray file,
   `MA_11August2025cleaned.fif`, a processed file with no place in raw data
   at all, that had ended up in this directory for no known reason.

Run again against the untouched originals, this reproduces exactly the same
renamed files, skipped files, and deleted files as the one real run already
done, so anyone starting from the originals, a backup, or a fresh copy from
wherever this data eventually lives, ends up with the same result.
'''
import calendar
import difflib
import hashlib
import os
import re
import string
from datetime import date

CHILD_DIR = "raw-data/child"

# Day-of-week code for each `date.weekday()` value (0 = Monday ... 6 = Sunday).
DOW_CODES = ["M", "T", "W", "Th", "F", "S", "Su"]

MONTH_NAMES = list(calendar.month_name)[1:]  # ['January', ..., 'December']

BDF_RE = re.compile(
    r"^(?P<dow>Th|Su|M|T|W|F|S)(?P<subj>[A-Z])_"
    r"(?P<day>\d{1,2})(?P<month>[A-Za-z]+?)(?P<year>\d{4})(?P<trailing>.*)$"
)

JSON_RE = re.compile(
    r"^(?P<dow>Th|Su|M|T|W|F|S)(?P<subj>[A-Z])_"
    r"(?P<day>\d{1,2})(?P<month>[A-Za-z]+?)(?P<year>\d{4})_"
    r"(?P<mm>\d{2})_(?P<dd>\d{2})_(?P<yyyy>\d{4})_"
    r"(?P<hh>\d{2})_(?P<mi>\d{2})_(?P<ss>\d{2})_results$"
)

def dir_ls(dir_name, ends_with=None):
    files = os.listdir(dir_name)
    if ends_with:
        return [f for f in files if f.lower().endswith(ends_with)]
    else:
        return files

def guess_month(text):
    """Match a (possibly misspelled) month name to its correct spelling.

    Returns None if nothing is close enough, rather than raising, so callers
    can treat "couldn't guess" the same as "not a month" and report it.
    """
    matches = difflib.get_close_matches(text, MONTH_NAMES, n=1, cutoff=0.5)
    return matches[0] if matches else None


def parse_bdf_filename(fname):
    """Parse one child bdf filename into its dow/subj/date fields, or None."""
    m = BDF_RE.match(os.path.splitext(fname)[0])
    if not m:
        return None
    parsed = m.groupdict()
    # Only guess at the month if it isn't already a real month name, so a
    # correctly-spelled month is left alone and this only does anything on
    # the handful of typo'd cases.
    if parsed['month'] not in MONTH_NAMES:
        parsed['month'] = guess_month(parsed['month'])
    return parsed

def bdf_filename_problems(fname):
    """List everything wrong with a bdf filename. Empty list means it's fine.

    Checks, in order: does it match the pattern at all; are dow, day, month,
    subject each individually sane; is the year plausible for this study;
    and, only once all of that holds, does the day-of-week code actually
    match the calendar date it's paired with.
    """
    parsed = parse_bdf_filename(fname)
    if parsed is None:
        return ["doesn't match the expected bdf filename pattern at all"]

    dow, subj, month = parsed['dow'], parsed['subj'], parsed['month']
    day, year = int(parsed['day']), int(parsed['year'])

    problems = []
    if dow not in DOW_CODES:
        problems.append(f"day-of-week code {dow!r} is not one of {DOW_CODES}")
    if not (1 <= day <= 31):
        problems.append(f"day-of-month {day} is out of range 1-31")
    if month not in MONTH_NAMES:
        problems.append(f"month {parsed['month']!r} is not a recognised month name")
    if subj not in string.ascii_uppercase:
        problems.append(f"subject letter {subj!r} is not an uppercase letter")
    if not (2020 <= year <= 2029):
        problems.append(f"year {year} is outside the range this study could plausibly be run in")

    # The day-of-week check needs day/month/year to already be sane enough
    # to form a real calendar date, so it only runs once nothing above fired.
    if not problems:
        try:
            actual_weekday = date(year, MONTH_NAMES.index(month) + 1, day).weekday()
        except ValueError:
            problems.append(f"{day} {month} {year} is not a real calendar date")
        else:
            if DOW_CODES[actual_weekday] != dow:
                problems.append(
                    f"{day} {month} {year} is a {calendar.day_name[actual_weekday]}, not a {dow}"
                )

    return problems


def is_valid_bdf_filename(fname):
    return not bdf_filename_problems(fname)


def parse_json_filename(fname):
    """Parse one child json filename into its dow/subj/date/time fields, or None."""
    m = JSON_RE.match(os.path.splitext(fname)[0])
    if not m:
        return None
    parsed = m.groupdict()
    if parsed['month'] not in MONTH_NAMES:
        parsed['month'] = guess_month(parsed['month'])
    return parsed

def json_filename_problems(fname):
    """List everything wrong with a json filename. Empty list means it's fine.

    Same checks as bdf_filename_problems, plus one a bdf filename can't
    support: the json carries its date twice, once hand-typed at the front
    and once in its own generated mm_dd_yyyy timestamp, and those two should
    agree with each other.
    """
    parsed = parse_json_filename(fname)
    if parsed is None:
        return ["doesn't match the expected json filename pattern at all"]

    dow, subj, month = parsed['dow'], parsed['subj'], parsed['month']
    day, year = int(parsed['day']), int(parsed['year'])
    mm, dd, yyyy = int(parsed['mm']), int(parsed['dd']), int(parsed['yyyy'])

    problems = []
    if dow not in DOW_CODES:
        problems.append(f"day-of-week code {dow!r} is not one of {DOW_CODES}")
    if not (1 <= day <= 31):
        problems.append(f"day-of-month {day} is out of range 1-31")
    if month not in MONTH_NAMES:
        problems.append(f"month {parsed['month']!r} is not a recognised month name")
    if subj not in string.ascii_uppercase:
        problems.append(f"subject letter {subj!r} is not an uppercase letter")
    if not (2020 <= year <= 2029):
        problems.append(f"year {year} is outside the range this study could plausibly be run in")

    if month in MONTH_NAMES and MONTH_NAMES.index(month) + 1 != mm:
        problems.append(f"front-part month ({month}) doesn't match the timestamp's month ({mm:02d})")
    if day != dd:
        problems.append(f"front-part day ({day}) doesn't match the timestamp's day ({dd:02d})")
    if year != yyyy:
        problems.append(f"front-part year ({year}) doesn't match the timestamp's year ({yyyy})")

    if not problems:
        try:
            actual_weekday = date(year, MONTH_NAMES.index(month) + 1, day).weekday()
        except ValueError:
            problems.append(f"{day} {month} {year} is not a real calendar date")
        else:
            if DOW_CODES[actual_weekday] != dow:
                problems.append(
                    f"{day} {month} {year} is a {calendar.day_name[actual_weekday]}, not a {dow}"
                )

    return problems


def is_valid_json_filename(fname):
    return not json_filename_problems(fname)


def subject_order_problems(json_files):
    """Check that, for each calendar date, subject letters A, B, C, ... were
    handed out in actual run order (earliest json timestamp first).

    This is a different kind of check from the two functions above: it can
    only be answered from the jsons, since a bdf filename carries no time of
    day, and it needs every session on one date together to say anything, so
    it doesn't fit the one-filename-at-a-time shape of *_filename_problems.
    Returns a dict of {filename: problem} for the ones out of order.
    """
    sessions_by_date = {}
    for fname in json_files:
        parsed = parse_json_filename(fname)
        if parsed is None:
            continue  # already reported by json_filename_problems
        day_key = (int(parsed['yyyy']), int(parsed['mm']), int(parsed['dd']))
        time_of_day = (int(parsed['hh']), int(parsed['mi']), int(parsed['ss']))
        sessions_by_date.setdefault(day_key, []).append((time_of_day, parsed['subj'], fname))

    problems = {}
    for day_key, sessions in sessions_by_date.items():
        sessions.sort()  # by time_of_day, since it's first in each tuple
        for i, (time_of_day, subj, fname) in enumerate(sessions):
            expected_subj = string.ascii_uppercase[i]
            if subj != expected_subj:
                problems[fname] = (
                    f"{i + 1}{'st' if i == 0 else 'nd' if i == 1 else 'rd' if i == 2 else 'th'} "
                    f"session on {day_key}, so subject letter should be {expected_subj}, not {subj}"
                )
    return problems


def session_key(fname, parse):
    """The (dow, subj, day, month, year) a bdf or json filename starts with.

    `parse` is `parse_bdf_filename` or `parse_json_filename`, whichever
    matches `fname`. Both return the same field names for this front part,
    so one function covers matching either direction.
    """
    parsed = parse(fname)
    return (parsed['dow'], parsed['subj'], int(parsed['day']), parsed['month'], int(parsed['year']))


def new_basename(json_fname):
    """The standard raw-data/main-style basename for a session's pair:
    {dow}{subj}_{mm}_{dd}_{yyyy}_{hh}_{mi}_{ss}, no "_results" suffix.

    Parsing the json alone is enough: mm/dd/yyyy/hh/mi/ss come straight from
    its own timestamp, already 2/4-digit padded, and dow/subj are shared
    with its matched bdf by construction of `sessions` above.
    """
    p = parse_json_filename(json_fname)
    return f"{p['dow']}{p['subj']}_{p['mm']}_{p['dd']}_{p['yyyy']}_{p['hh']}_{p['mi']}_{p['ss']}"


def md5sum(path, chunk_size=2**20):
    """MD5 of a file's contents, read in chunks so a several-hundred-MB bdf
    doesn't need to be loaded into memory all at once."""
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


# =============================================================================
# Interactive section below this line: run by hand, read what comes back.
# =============================================================================

bdf_files = dir_ls(CHILD_DIR, ".bdf")
json_files = dir_ls(CHILD_DIR, ".json")

# Every bdf filename should be individually valid. Report every one that
# isn't, with the reason, before stopping, rather than stopping at the first.
bad_bdfs = {f: bdf_filename_problems(f) for f in bdf_files}
bad_bdfs = {f: problems for f, problems in bad_bdfs.items() if problems}
for f, problems in bad_bdfs.items():
    print(f"{f}: {'; '.join(problems)}")
assert not bad_bdfs, f"{len(bad_bdfs)} invalid bdf filename(s), see above"

# This has identified one problem bdf file:
# MA_28March2026.bdf: 28 March 2026 is a Saturday, not a M
# This file also has no possible json matches
# There are no other files whose dates were in March (of any year)
# This file is therefore an anomaly, and must be skipped.
# If we can't match to json file, we lack essential information about 
# the stimuli.
files_to_skip = ['MA_28March2026.bdf']



# Same for json filenames.
bad_jsons = {f: json_filename_problems(f) for f in json_files}
bad_jsons = {f: problems for f, problems in bad_jsons.items() if problems}
for f, problems in bad_jsons.items():
    print(f"{f}: {'; '.join(problems)}")
assert not bad_jsons, f"{len(bad_jsons)} invalid json filename(s), see above"

# Subject-letter run order, from the jsons. Reported, not asserted on here:
# an out-of-order letter can genuinely be caused by a missing file elsewhere
# on the same date rather than by this file being wrong, so it's worth
# looking at rather than treating as an automatic showstopper.
for f, problem in subject_order_problems(json_files).items():
    print(f"{f}: {problem}")

# SuA on 1 June 2025 has one bdf but three json files (three attempts?).
# The bdf's own header start time rules out the last json (12:55:20, a bdf
# can't start before its own json was written) but doesn't cleanly pick
# between the other two, so which json it actually belongs to isn't known
# with confidence. Skipping all four for now; worth another look later only
# if the trial-by-trial detail in the jsons can be matched against the
# bdf's own trigger structure.
files_to_skip += [
    'SuA_1June2025.bdf',
    'SuA_1June2025_06_01_2025_12_16_51_results.json',
    'SuA_1June2025_06_01_2025_12_43_02_results.json',
    'SuA_1June2025_06_01_2025_12_55_20_results.json',
]

# FA on 29 August 2025 has one bdf but two json files. The bdf's own header
# start time (16:13:42) is about 80 minutes after one json (14:54:04) and
# over an hour before the other (17:20:12). Neither gap looks like an
# ordinary session (instructions and practice normally run more like 5-10
# minutes before recording starts), and a bdf starting before a json isn't
# actually impossible, as first thought: if the EEG kept recording across
# more than one behavioural attempt, its start time can legitimately sit
# before a later attempt's json. So which, if either, json this bdf belongs
# to isn't known. Skipping all three for now, same reason as SuA.
files_to_skip += [
    'FA_29August2025.bdf',
    'FA_29August2025_08_29_2025_14_54_04_results.json',
    'FA_29August2025_08_29_2025_17_20_12_results.json',
]

# MC on 16 February 2026 has one bdf but two json files, 5 minutes apart
# (15:13:09, 15:18:23). Every json in this directory is 1669 lines except
# this one: MC_..._15_13_09_results.json is only 565, so that attempt was
# cut short and never completed, unlike SuA/FA_29 above where both files are
# full-length and genuinely ambiguous. Skip the short one; the 15:18:23 file
# is MC's real json. Doing so also clears the subject-order problems this
# was causing for MD and ME later that same day, both were only ever "out
# of order" because this incomplete extra attempt was being counted as a
# session in its own right.
files_to_skip += [
    'MC_16February2026_02_16_2026_15_13_09_results.json',
]

# ---------------------------------------------------------------------------
# One-to-one matching, on the remaining files (files_to_skip excluded).
# Two directional checks, as planned at the top of this file: for each bdf,
# exactly one json should start the same way (same dow, subj, day, month,
# year), and for each json, exactly one bdf should. Grouping each side by
# that key first means both checks are then just a dict lookup.
# ---------------------------------------------------------------------------

remaining_bdfs = [f for f in bdf_files if f not in files_to_skip]
remaining_jsons = [f for f in json_files if f not in files_to_skip]

bdfs_by_key = {}
for f in remaining_bdfs:
    bdfs_by_key.setdefault(session_key(f, parse_bdf_filename), []).append(f)

jsons_by_key = {}
for f in remaining_jsons:
    jsons_by_key.setdefault(session_key(f, parse_json_filename), []).append(f)

# For each bdf, is there one and only one json starting the same way?
bad_bdf_matches = {}
for f in remaining_bdfs:
    matches = jsons_by_key.get(session_key(f, parse_bdf_filename), [])
    if len(matches) != 1:
        bad_bdf_matches[f] = matches
for f, matches in bad_bdf_matches.items():
    print(f"{f}: {len(matches)} matching json file(s): {matches}")

# And the same check in reverse: for each json, one and only one bdf?
bad_json_matches = {}
for f in remaining_jsons:
    matches = bdfs_by_key.get(session_key(f, parse_json_filename), [])
    if len(matches) != 1:
        bad_json_matches[f] = matches
for f, matches in bad_json_matches.items():
    print(f"{f}: {len(matches)} matching bdf file(s): {matches}")

assert not bad_bdf_matches, f"{len(bad_bdf_matches)} bdf file(s) without exactly one matching json, see above"
assert not bad_json_matches, f"{len(bad_json_matches)} json file(s) without exactly one matching bdf, see above"

# Two bdf files have no json at all, and one json has no bdf at all. Unlike
# the cases above, there's nothing here to disambiguate, the other half of
# the pair is simply missing, so there's no choice but to drop them: no json
# means no record of what the stimuli were, and no bdf means no EEG was
# ever recorded for that json.
files_to_skip += [
    'FB_29August2025.bdf',
    'SuB_1June2025.bdf',
    'SA_12July2025_07_12_2025_11_55_39_results.json',
]

# ---------------------------------------------------------------------------
# Final one-to-one mapping, now that files_to_skip is complete. Rerunning
# the same two list comprehensions as line 323/324 and the same two by-key
# dicts as line 326/332, since files_to_skip has grown since they last ran.
# ---------------------------------------------------------------------------

remaining_bdfs = [f for f in bdf_files if f not in files_to_skip]
remaining_jsons = [f for f in json_files if f not in files_to_skip]

bdfs_by_key = {}
for f in remaining_bdfs:
    bdfs_by_key.setdefault(session_key(f, parse_bdf_filename), []).append(f)

jsons_by_key = {}
for f in remaining_jsons:
    jsons_by_key.setdefault(session_key(f, parse_json_filename), []).append(f)

# Both sides should now cover exactly the same set of keys.
assert set(bdfs_by_key) == set(jsons_by_key), "bdf and json keys don't match, see above checks"

# One key per session, one bdf and one json each.
sessions = {key: (bdfs_by_key[key][0], jsons_by_key[key][0]) for key in bdfs_by_key}

# Extra check: every remaining bdf and json actually shows up in sessions'
# values, not just every key being present. This also catches a key having
# more than one bdf or json, since only the first of each was kept above,
# any other would be missing here and break the equality.
matched_bdfs = {bdf for bdf, json in sessions.values()}
matched_jsons = {json for bdf, json in sessions.values()}
assert matched_bdfs == set(remaining_bdfs), "some remaining bdf isn't in the final mapping"
assert matched_jsons == set(remaining_jsons), "some remaining json isn't in the final mapping"

# ---------------------------------------------------------------------------
# Renaming, to the raw-data/main scheme. New basename comes from the json
# alone (new_basename above); both files in a session get the same one.
# Checksummed before renaming and re-checked after, since these files are
# only backed up elsewhere, not duplicated anywhere in this repo.
# ---------------------------------------------------------------------------

renames = []  # (old_path, new_path), two entries (bdf, json) per session
for bdf_fname, json_fname in sessions.values():
    basename = new_basename(json_fname)
    renames.append((os.path.join(CHILD_DIR, bdf_fname), os.path.join(CHILD_DIR, basename + ".bdf")))
    renames.append((os.path.join(CHILD_DIR, json_fname), os.path.join(CHILD_DIR, basename + ".json")))

# Every new name should be unique, and none should already exist.
new_paths = [new for _, new in renames]
assert len(new_paths) == len(set(new_paths)), "two sessions produced the same new basename"
assert not any(os.path.exists(new) for new in new_paths), "a target filename already exists"

checksums_before = {old: md5sum(old) for old, new in renames}

for old_path, new_path in renames:
    os.rename(old_path, new_path)

for old_path, new_path in renames:
    assert md5sum(new_path) == checksums_before[old_path], f"checksum changed for {new_path}"

# files_to_skip are backed up elsewhere already; remove the local copies.
for fname in files_to_skip:
    os.remove(os.path.join(CHILD_DIR, fname))

# One more stray file, MA_11August2025cleaned.fif: a .fif, not a .bdf, so it
# never appeared in bdf_files or any of the checks above. Not raw data at
# all, fif is an MNE output format, so this looks like a processed file that
# ended up in raw-data/child by mistake. No idea how, and it doesn't
# correspond to anything else here regardless. Delete it too.
os.remove(os.path.join(CHILD_DIR, "MA_11August2025cleaned.fif"))
