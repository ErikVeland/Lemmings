"""Build tiny ZIP fixtures for exact archive-member selection."""
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile, ZipInfo
import warnings

root = Path(__file__).resolve().parent
names = ["level[1].ini", "level1.ini", "star*.ini", "starX.ini",
         "q?.ini", "qa.ini", r"back\slash.ini", "nested[1]/level.ini",
         "nested1/level.ini", "-x.ini"]

def write(z, name, title):
    info = ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
    info.compress_type = ZIP_STORED
    z.writestr(info, f"name = {title}\nreleaseRate = 1\nnumLemmings = 1\n"
                     "numToRescue = 1\ntimeLimit = 1\nobject_0 = 1, 100, 20\n")

with ZipFile(root / "literal-members.zip", "w") as z:
    for index, name in enumerate(names):
        write(z, name, f"Literal {index}")
with warnings.catch_warnings():
    warnings.simplefilter("ignore", UserWarning)
    with ZipFile(root / "duplicate-members.zip", "w") as z:
        write(z, "same.ini", "First")
        write(z, "same.ini", "Second")
        write(z, "unique.ini", "Unique")
