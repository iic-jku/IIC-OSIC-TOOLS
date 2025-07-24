# For HTTP stuff
import urllib3

# import Pyyaml, either C-backed classes or python only.
from yaml import load, dump
try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

import yaml

def metadata_read(path):
    with open(path, mode="r") as f:
        return f.read()
    return None

def metadata_load(tag, url_fstr):
    dl_url=url_fstr.format(tag)
    http = urllib3.PoolManager()
    res = http.request("GET", dl_url)
    if res.status!=200:
        print(f"Loading file failed with HTTP status {res.status}!")
        return None
    return res.data

def metadata_parse(raw_data):
    data = yaml.load(raw_data, Loader=Loader)
    normalized_set = set()
    for x in data:
        norm_str = x['name'].replace('-','_')
        if norm_str in normalized_set:
            print("WARNING: there are similar entries in the input yaml file ('-' and '_' are interpreted as the same symbol)")
            break
        normalized_set.add(norm_str)
    return data

def get_revision(data, tool_name):
    result = [x for x in data if x['name'].replace('-', '_') == tool_name.replace('-', '_')]
    if len(result) < 1:
        return None
    if len(result) > 1:
        print(f"WARNING: Multiple entries for tool{tool_name} found!")
    result = result[0]
    commit = result.get("commit")
    return commit

def metadata_write(raw_data, path):
    with open(path, mode="wb") as f:
        f.write(raw_data)